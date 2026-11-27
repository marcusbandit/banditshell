const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const { ROOT, cleanup, directory, stubs, cli } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

const Helper = new Function(fs.readFileSync(path.join(ROOT, "services/dies-with-shell.js"), "utf8") + "\nreturn { command };")();
const hasSetpriv = spawnSync("sh", ["-c", "command -v setpriv"]).status === 0;

function alive(pid) {
    try {
        const stat = fs.readFileSync(`/proc/${pid}/stat`, "utf8");
        return stat.slice(stat.lastIndexOf(")") + 2)[0] !== "Z";
    } catch {
        return false;
    }
}

async function until(check, ms = 3000) {
    const end = Date.now() + ms;
    while (Date.now() < end) {
        if (check())
            return true;
        await new Promise(resolve => setTimeout(resolve, 25));
    }
    return check();
}

function firstLine(child) {
    return new Promise(resolve => {
        let seen = "";
        child.stdout.on("data", chunk => {
            seen += chunk;
            if (seen.includes("\n"))
                resolve(seen.split("\n")[0].trim());
        });
    });
}

test("a wrapped helper runs its command with the helper mark", () => {
    const [program, ...args] = Helper.command(["sh", "-c", 'printf "%s|%s" "$BANDITSHELL_HELPER" "$1"', "sh", "two words"]);
    const run = spawnSync(program, args, { encoding: "utf8" });
    assert.strictEqual(run.stdout, "1|two words");
});

test("a wrapped helper still runs where setpriv is missing", () => {
    const bin = directory("nosetpriv");
    fs.symlinkSync(spawnSync("sh", ["-c", "command -v sh"], { encoding: "utf8" }).stdout.trim(), path.join(bin, "sh"));
    fs.writeFileSync(path.join(bin, "say"), "#!/bin/sh\nprintf ran\n", { mode: 0o755 });
    const argv = Helper.command(["say"]);
    const run = spawnSync(path.join(bin, "sh"), argv.slice(1), { encoding: "utf8", env: { PATH: bin } });
    assert.strictEqual(run.stdout, "ran");
});

test("a wrapped helper dies when the process that started it dies", { skip: !hasSetpriv && "setpriv is not installed" }, async () => {
    const parent = spawn("bash", ["-c", '"$@" & echo $!; wait', "bash", ...Helper.command(["sleep", "300"])], { stdio: ["ignore", "pipe", "ignore"] });
    const pid = Number(await firstLine(parent));
    assert.ok(await until(() => {
        try {
            return fs.readFileSync(`/proc/${pid}/cmdline`, "utf8").startsWith("sleep");
        } catch {
            return false;
        }
    }), "the helper never started");
    parent.kill("SIGKILL");
    const gone = await until(() => !alive(pid));
    if (!gone)
        process.kill(pid, "SIGKILL");
    assert.ok(gone, "the helper outlived its parent");
});

test("stop ends the shell's marked helpers and leaves its other children running", async () => {
    const shell = spawn("sh", ["-c", 'BANDITSHELL_HELPER=1 sleep 300 & helper=$!; sleep 300 & echo "$helper $!"; wait'], { detached: true, stdio: ["ignore", "pipe", "ignore"] });
    const [helper, other] = (await firstLine(shell)).split(" ").map(Number);
    try {
        const stub = stubs();
        fs.writeFileSync(path.join(stub.dir, "qs"), `#!/bin/sh
echo "qs $*" >>"$STUB_LOG"
[ "$1" = list ] && printf 'Instance abc:\\n  Process ID: %s\\n  Config path: %s/shell.qml\\n' "${shell.pid}" "${ROOT}"
exit 0
`, { mode: 0o755 });
        const run = cli(["stop"], { stub });
        assert.match(run.out, /stopped/);
        assert.ok(await until(() => !alive(shell.pid)), "the shell is still running");
        assert.ok(await until(() => !alive(helper)), "the marked helper outlived the shell");
        assert.ok(alive(other), "an unmarked child was stopped too");
    } finally {
        for (const pid of [shell.pid, helper, other])
            try {
                process.kill(pid, "SIGKILL");
            } catch {}
    }
});
