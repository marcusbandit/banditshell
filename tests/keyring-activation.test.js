const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const WAITER = path.join(ROOT, "scripts/keyring-waiter.sh");
const PROMPTER = path.join(ROOT, "scripts/keyring-prompter.py");
const NAME = "org.gnome.keyring.SystemPrompter";

function scratch() {
    return fs.mkdtempSync(path.join(os.tmpdir(), "keyring-activation-"));
}

function stubs(dir, tools) {
    const bin = path.join(dir, "bin");
    fs.mkdirSync(bin, { recursive: true });
    for (const [name, body] of Object.entries(tools)) {
        fs.writeFileSync(path.join(bin, name), `#!/bin/sh\n${body}\n`);
        fs.chmodSync(path.join(bin, name), 0o755);
    }
    return bin;
}

function wait(dir, { owner, shell }) {
    const shellRoot = path.join(dir, "shell");
    fs.mkdirSync(path.join(shellRoot, "scripts"), { recursive: true });
    fs.writeFileSync(path.join(shellRoot, "scripts/keyring-prompter.py"), "");
    const bin = stubs(dir, {
        gdbus: owner ? `[ -f "${dir}/owned" ] && echo "(true,)" || echo "(false,)"` : `echo "(false,)"`,
        qs: shell ? `echo "  Config path: ${shellRoot}/shell.qml"` : "exit 0",
        fallback: `echo "$@" >"${dir}/fell-back"`
    });
    if (owner === "now")
        fs.writeFileSync(path.join(dir, "owned"), "");
    const started = Date.now();
    const run = spawnSync("bash", [WAITER, NAME, path.join(bin, "fallback"), "--from-test"], {
        encoding: "utf8",
        env: { PATH: `${bin}:/usr/bin:/bin`, KEYRING_WAITER_PATIENCE: "3", KEYRING_WAITER_GRACE: "1" },
        timeout: 10000
    });
    return {
        status: run.status,
        seconds: (Date.now() - started) / 1000,
        fellBack: fs.existsSync(path.join(dir, "fell-back")) ? fs.readFileSync(path.join(dir, "fell-back"), "utf8").trim() : null
    };
}

test.describe("keyring-waiter.sh", () => {
    test("leaves at once when the shell already owns the name", () => {
        const result = wait(scratch(), { owner: "now", shell: true });
        assert.strictEqual(result.status, 0);
        assert.strictEqual(result.fellBack, null);
        assert.ok(result.seconds < 1, `took ${result.seconds}s`);
    });

    test("hands over to gcr's prompter after the grace when no shell is running", () => {
        const result = wait(scratch(), { owner: null, shell: false });
        assert.strictEqual(result.fellBack, "--from-test");
        assert.ok(result.seconds >= 1 && result.seconds < 3, `took ${result.seconds}s`);
    });

    test("keeps waiting while a banditshell is running, then gives up at the deadline", () => {
        const result = wait(scratch(), { owner: null, shell: true });
        assert.strictEqual(result.fellBack, "--from-test");
        assert.ok(result.seconds >= 3, `took ${result.seconds}s`);
    });
});

const hasGi = spawnSync("python3", ["-c", "import gi, cryptography"]).status === 0;

test.describe("keyring-prompter.py redirect_activation", { skip: !hasGi && "python3 gi or cryptography missing" }, () => {
    function redirect(dir, script = "") {
        const run = spawnSync("python3", ["-I", "-c", `
import importlib.util
spec = importlib.util.spec_from_file_location("prompter", ${JSON.stringify(PROMPTER)})
prompter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prompter)
class Bus:
    reloads = 0
    def call(self, *args):
        Bus.reloads += 1
${script}
prompter.redirect_activation(Bus())
print(Bus.reloads)
`], {
            encoding: "utf8",
            env: { PATH: process.env.PATH, HOME: dir, XDG_DATA_HOME: path.join(dir, "home"), XDG_DATA_DIRS: path.join(dir, "system") }
        });
        assert.strictEqual(run.status, 0, run.stderr);
        return Number(run.stdout.trim());
    }

    function system(dir) {
        const services = path.join(dir, "system/dbus-1/services");
        fs.mkdirSync(services, { recursive: true });
        for (const name of [NAME, "org.gnome.keyring.PrivatePrompter"])
            fs.writeFileSync(path.join(services, `${name}.service`), `[D-BUS Service]\nName=${name}\nExec=/usr/lib/gcr-prompter\n`);
    }

    function ours(dir, name = NAME) {
        return fs.readFileSync(path.join(dir, "home/dbus-1/services", `${name}.service`), "utf8");
    }

    test("points both prompter names at the waiter, with gcr's prompter as the way out", () => {
        const dir = scratch();
        system(dir);
        assert.strictEqual(redirect(dir), 1);
        for (const name of [NAME, "org.gnome.keyring.PrivatePrompter"]) {
            const file = ours(dir, name);
            assert.match(file, new RegExp(`^Name=${name.replace(/\./g, "\\.")}$`, "m"));
            assert.ok(file.includes(`${WAITER} ${name} /usr/lib/gcr-prompter`), file);
        }
    });

    test("leaves the bus alone when the files already say the same", () => {
        const dir = scratch();
        system(dir);
        redirect(dir);
        assert.strictEqual(redirect(dir), 0);
    });

    test("never overwrites a service file someone else put there", () => {
        const dir = scratch();
        system(dir);
        const services = path.join(dir, "home/dbus-1/services");
        fs.mkdirSync(services, { recursive: true });
        fs.writeFileSync(path.join(services, `${NAME}.service`), `[D-BUS Service]\nName=${NAME}\nExec=/usr/bin/my-prompter\n`);
        redirect(dir);
        assert.match(ours(dir), /Exec=\/usr\/bin\/my-prompter/);
    });
});
