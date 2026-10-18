const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const { ROOT, cleanup, directory, stubs, cli } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

function fakeQuickshell(stub, { list = "", reply = "", code = 0 } = {}) {
    fs.writeFileSync(path.join(stub.dir, "qs"), `#!/bin/sh
echo "qs $*" >>"$STUB_LOG"
case "$1" in
list) printf '%s' "$QS_LIST" ;;
ipc) [ -z "$QS_REPLY" ] || printf '%s\\n' "$QS_REPLY"; exit "\${QS_CODE:-0}" ;;
esac
`, { mode: 0o755 });
    return { QS_LIST: list, QS_REPLY: reply, QS_CODE: String(code) };
}

function instance(pid) {
    return `Instance abc:\n  Process ID: ${pid}\n  Config path: ${ROOT}/shell.qml\n`;
}

test("the shell not running is exit 3 and says so", () => {
    const stub = stubs();
    const env = fakeQuickshell(stub, { code: 1 });
    const run = cli(["focus", "quiet", "off"], { stub, env });
    assert.strictEqual(run.code, 3);
    assert.match(run.err, /not running \(try: banditshell start\)/);
});

test("a running shell that does not take the call is exit 4 with a different message", () => {
    const stub = stubs();
    const env = fakeQuickshell(stub, { list: instance(process.pid), code: 1 });
    const run = cli(["focus", "quiet", "off"], { stub, env });
    assert.strictEqual(run.code, 4);
    assert.match(run.err, /the shell is running but did not take `quiet off`/);
    assert.doesNotMatch(run.err, /not running/);
});

test("a handler that refuses is exit 4, its words go to stderr and stdout stays empty", () => {
    for (const reply of ["refused: ends how? (hour, evening, tomorrow or never)", "no shell window", "no such screen: DP-9"]) {
        const stub = stubs();
        const env = fakeQuickshell(stub, { list: instance(process.pid), reply });
        const run = cli(["focus", "quiet", "on"], { stub, env });
        assert.strictEqual(run.code, 4, reply);
        assert.strictEqual(run.out, "", reply);
        assert.strictEqual(run.err.trim(), `banditshell: ${reply.replace(/^refused: /, "")}`);
        assert.ok(!run.calls.some(c => c.startsWith("hyprctl")), reply);
    }
});

test("an answer is printed and is exit 0", () => {
    const stub = stubs();
    const env = fakeQuickshell(stub, { list: instance(process.pid), reply: "open=false" });
    const run = cli(["panel", "launcher", "status"], { stub, env });
    assert.strictEqual(run.code, 0);
    assert.strictEqual(run.out, "open=false\n");
    const none = cli(["focus", "quiet", "off"], { stub, env: { ...env, QS_REPLY: "" } });
    assert.strictEqual(none.code, 0);
    assert.strictEqual(none.out, "");
});

test("a refusal that used to be sniffed by three verbs now comes out of one place", () => {
    for (const args of [["focus", "mode", "work"], ["focus", "quiet", "on"], ["screen", "stream", "on", "DP-1"]]) {
        const stub = stubs();
        const env = fakeQuickshell(stub, { list: instance(process.pid), reply: "refused: nope" });
        const run = cli(args, { stub, env });
        assert.strictEqual(run.code, 4, args.join(" "));
        assert.strictEqual(run.err.trim(), "banditshell: nope", args.join(" "));
    }
});

test("the pid is cached, validated with kill -0, and rescanned when it goes stale", async () => {
    const stub = stubs();
    const fake = directory("instance");
    fs.symlinkSync("/usr/bin/sleep", path.join(fake, "qs"));
    const child = spawn(path.join(fake, "qs"), ["60"], { stdio: "ignore" });
    try {
        await new Promise(resolve => setTimeout(resolve, 100));
        const home = directory("home");
        const env = fakeQuickshell(stub, { list: instance(child.pid), reply: "ok" });
        const lists = () => fs.readFileSync(stub.log, "utf8").split("\n").filter(l => l.startsWith("qs list")).length;
        assert.strictEqual(cli(["panel", "launcher", "status"], { stub, env, home }).code, 0);
        assert.strictEqual(lists(), 1);
        const pidFile = path.join(home, "run/banditshell/pid");
        assert.strictEqual(fs.readFileSync(pidFile, "utf8"), `${child.pid}\t${ROOT}\n`);
        const second = cli(["panel", "launcher", "status"], { stub, env, home });
        assert.strictEqual(second.code, 0);
        assert.strictEqual(lists(), 1);
        assert.ok(second.calls.some(c => c.startsWith(`qs ipc --pid ${child.pid} call launcher status`)));
        child.kill();
        await new Promise(resolve => child.once("exit", resolve));
        const third = cli(["panel", "launcher", "status"], { stub, env: { ...env, QS_LIST: "" }, home });
        assert.strictEqual(lists(), 2);
        assert.strictEqual(third.code, 0);
        assert.strictEqual(third.calls.filter(c => c.startsWith("qs ipc -p ")).length, 1);
    } finally {
        child.kill();
    }
});

test("a cached pid that belongs to some other program is not trusted", () => {
    const stub = stubs();
    const home = directory("home");
    fs.mkdirSync(path.join(home, "run/banditshell"), { recursive: true });
    fs.writeFileSync(path.join(home, "run/banditshell/pid"), `${process.pid}\t${ROOT}\n`);
    const env = fakeQuickshell(stub, { list: "", code: 1 });
    const run = cli(["focus", "quiet", "off"], { stub, env, home });
    assert.strictEqual(run.code, 3);
    assert.ok(run.calls.some(c => c.startsWith("qs list")));
});

function hyprland(files = {}) {
    const hypr = directory("hypr");
    for (const [name, text] of Object.entries(files)) {
        fs.mkdirSync(path.dirname(path.join(hypr, name)), { recursive: true });
        fs.writeFileSync(path.join(hypr, name), text);
    }
    return hypr;
}

function listing(dir) {
    const out = [];
    const walk = d => {
        for (const entry of fs.readdirSync(d, { withFileTypes: true })) {
            const full = path.join(d, entry.name);
            if (entry.isDirectory())
                walk(full);
            else
                out.push(path.relative(dir, full));
        }
    };
    walk(dir);
    return out.sort();
}

function doctorApi(hypr, extra = {}) {
    const home = extra.home ?? directory("home");
    const state = path.join(home, "state");
    const run = cli(["doctor", "api"], {
        home,
        stub: extra.stub,
        env: { HYPR_DIR: hypr, XDG_STATE_HOME: state, ...(extra.env ?? {}) }
    });
    return { ...run, state };
}

test("doctor api puts the pointer and the shim in place and touches no other file", () => {
    const hypr = hyprland({ "hyprland.lua": "-- mine\n", "lua/binds.lua": "-- binds\n" });
    const run = doctorApi(hypr);
    assert.strictEqual(run.code, 0, run.out + run.err);
    assert.strictEqual(fs.readFileSync(path.join(run.state, "banditshell/root"), "utf8"), `${ROOT}\n`);
    assert.strictEqual(fs.readFileSync(path.join(hypr, "banditshell.lua"), "utf8"), fs.readFileSync(path.join(ROOT, "api/shim.lua"), "utf8"));
    assert.deepStrictEqual(listing(hypr), ["banditshell.lua", "hyprland.lua", "lua/binds.lua"]);
    assert.strictEqual(fs.readFileSync(path.join(hypr, "hyprland.lua"), "utf8"), "-- mine\n");
    assert.match(run.out, /^ok\s+fixed\s+shim written to /m);
    assert.match(run.out, /^ok\s+shim\s/m);
    assert.match(run.out, /^ok\s+pointer\s/m);
    assert.match(run.out, /^ok\s+actions\s/m);
    assert.deepStrictEqual(listing(path.dirname(run.state)).filter(f => !f.startsWith("state/") && !f.startsWith("run/")), []);
});

test("doctor api a second time changes nothing and reports nothing fixed", () => {
    const hypr = hyprland({ "hyprland.lua": "x" });
    const home = directory("home");
    doctorApi(hypr, { home });
    const before = fs.statSync(path.join(hypr, "banditshell.lua")).mtimeMs;
    const run = doctorApi(hypr, { home });
    assert.strictEqual(run.code, 0, run.out);
    assert.doesNotMatch(run.out, /\sfixed\s/);
    assert.strictEqual(fs.statSync(path.join(hypr, "banditshell.lua")).mtimeMs, before);
});

test("a file called banditshell.lua that is not banditshell's is left alone and reported", () => {
    const hypr = hyprland({ "banditshell.lua": "return { mine = true }\n" });
    const run = doctorApi(hypr);
    assert.strictEqual(run.code, 1);
    assert.match(run.out, /^fail\s+shim\s+.*is not banditshell's/m);
    assert.strictEqual(fs.readFileSync(path.join(hypr, "banditshell.lua"), "utf8"), "return { mine = true }\n");
});

test("a link called banditshell.lua is the user's too", () => {
    const hypr = hyprland({});
    const elsewhere = path.join(directory("elsewhere"), "mine.lua");
    fs.writeFileSync(elsewhere, "return 1\n");
    fs.symlinkSync(elsewhere, path.join(hypr, "banditshell.lua"));
    const run = doctorApi(hypr);
    assert.strictEqual(run.code, 1);
    assert.strictEqual(fs.readFileSync(elsewhere, "utf8"), "return 1\n");
    assert.ok(fs.lstatSync(path.join(hypr, "banditshell.lua")).isSymbolicLink());
});

test("an older shim of ours is replaced, a newer one is kept", () => {
    const source = fs.readFileSync(path.join(ROOT, "api/shim.lua"), "utf8");
    const format = Number(/format (\d+)\./.exec(source)[1]);
    const older = source.replace(`format ${format}.`, `format ${format - 1}.`).replace("api", "api old");
    const hypr = hyprland({ "banditshell.lua": older });
    assert.strictEqual(doctorApi(hypr).code, 0);
    assert.strictEqual(fs.readFileSync(path.join(hypr, "banditshell.lua"), "utf8"), source);
    const newer = source.replace(`format ${format}.`, `format ${format + 1}.`);
    const kept = hyprland({ "banditshell.lua": newer });
    const run = doctorApi(kept);
    assert.strictEqual(run.code, 0, run.out);
    assert.strictEqual(fs.readFileSync(path.join(kept, "banditshell.lua"), "utf8"), newer);
});

test("with no Hyprland config the pointer is still written and no directory is made", () => {
    const missing = path.join(directory("none"), "hypr");
    const run = doctorApi(missing);
    assert.strictEqual(run.code, 0, run.out);
    assert.ok(!fs.existsSync(missing));
    assert.match(run.out, /^warn\s+shim\s+no Hyprland config/m);
    assert.strictEqual(fs.readFileSync(path.join(run.state, "banditshell/root"), "utf8"), `${ROOT}\n`);
});

test("doctor api reads the binds: old command lines, unknown ids, a missing require", () => {
    const hypr = hyprland({
        "hyprland.lua": 'require("lua.binds")\n',
        "lua/binds.lua": [
            'local bs = require("banditshell")',
            'hl.bind("A", bs.launcher.toggle)',
            'hl.bind("B", bs.volume.up)',
            'hl.bind("C", bs.panel.clipboard.toggle)',
            'hl.bind("D", hl.dsp.exec_cmd("banditshell panel files toggle"))',
            '-- hl.bind("E", hl.dsp.exec_cmd("banditshell panel media toggle"))',
            'bs.bind("F", "launcher.toggle")'
        ].join("\n") + "\n",
        "lua/other.lua": 'hl.bind("G", bs.launcher.toggle)\n'
    });
    const run = doctorApi(hypr);
    assert.strictEqual(run.code, 0, run.out);
    assert.match(run.out, /^warn\s+binds\s+1 bind\(s\) still call banditshell by its command line/m);
    assert.match(run.out, /^warn\s+binds\s+not in the action table: bs\.volume\.up$/m);
    assert.match(run.out, /^warn\s+binds\s+uses bs\. without require\("banditshell"\): .*other\.lua$/m);
});

test("doctor api tells whether banditshell on the PATH is this checkout", () => {
    const stub = stubs();
    const hypr = hyprland({});
    const none = doctorApi(hypr, { stub });
    assert.match(none.out, /^warn\s+path\s+banditshell is not on your PATH; run: ln -s /m);
    fs.symlinkSync(path.join(ROOT, "cli/banditshell"), path.join(stub.dir, "banditshell"));
    const here = doctorApi(hypr, { stub });
    assert.match(here.out, /^ok\s+path\s/m);
    fs.rmSync(path.join(stub.dir, "banditshell"));
    fs.writeFileSync(path.join(stub.dir, "banditshell"), "#!/bin/sh\n", { mode: 0o755 });
    const other = doctorApi(hypr, { stub });
    assert.match(other.out, /^warn\s+path\s+banditshell on your PATH is .*, not this checkout/m);
});

test("doctor api --json turns the report into an object", () => {
    const hypr = hyprland({});
    const home = directory("home");
    const run = cli(["doctor", "api", "--json"], { home, env: { HYPR_DIR: hypr, XDG_STATE_HOME: path.join(home, "state") } });
    assert.strictEqual(run.code, 0, run.err);
    const parsed = JSON.parse(run.out);
    assert.ok(parsed.checks.length > 3);
    assert.ok(parsed.checks.every(c => ["ok", "warn", "fail"].includes(c.status) && c.name && c.detail));
    assert.ok(parsed.checks.some(c => c.name === "actions" && c.status === "ok"));
});

test("the pointer is never written while running from the last good copy", () => {
    const home = directory("home");
    const state = path.join(home, "state");
    const cache = directory("cache");
    const copy = path.join(cache, "banditshell/lastgood");
    fs.mkdirSync(path.join(copy, "cli"), { recursive: true });
    fs.copyFileSync(path.join(ROOT, "cli/banditshell"), path.join(copy, "cli/banditshell"));
    fs.mkdirSync(path.join(copy, "api"));
    fs.copyFileSync(path.join(ROOT, "api/shim.lua"), path.join(copy, "api/shim.lua"));
    const stub = stubs();
    const result = spawnSync("bash", [path.join(copy, "cli/banditshell"), "doctor", "api"], {
        encoding: "utf8",
        env: { PATH: `${stub.dir}:/usr/bin:/bin`, HOME: home, XDG_STATE_HOME: state, XDG_CACHE_HOME: cache, HYPR_DIR: path.join(home, "none"), STUB_LOG: stub.log }
    });
    assert.ok(!fs.existsSync(path.join(state, "banditshell/root")), result.stdout);
});

function installer(snippet, home) {
    return spawnSync("bash", ["-c", `source "${path.join(ROOT, "install.sh")}"; ${snippet}`], {
        encoding: "utf8",
        env: { PATH: "/usr/bin:/bin", HOME: home, LANG: "C.UTF-8", XDG_RUNTIME_DIR: path.join(home, "run") }
    });
}

test("install.sh lists the path and lua-api steps", () => {
    const home = directory("home");
    const run = spawnSync("bash", [path.join(ROOT, "install.sh"), "--list"], { encoding: "utf8", env: { PATH: "/usr/bin:/bin", HOME: home } });
    assert.strictEqual(run.status, 0, run.stderr);
    assert.match(run.stdout, /^path\s+2\s+banditshell on your PATH/m);
    assert.match(run.stdout, /^lua-api\s+2\s+the Lua module for binds/m);
});

test("the path step links ~/.local/bin/banditshell to this checkout's CLI and nothing else", () => {
    const home = directory("home");
    const before = installer("path_present && echo yes || echo no", home);
    assert.strictEqual(before.stdout.trim(), "no", before.stderr);
    const made = installer("install_path && path_present && echo yes", home);
    assert.strictEqual(made.stdout.trim(), "yes", made.stderr);
    const link = path.join(home, ".local/bin/banditshell");
    assert.strictEqual(fs.realpathSync(link), fs.realpathSync(path.join(ROOT, "cli/banditshell")));
    assert.deepStrictEqual(listing(home).filter(f => !f.startsWith(".local/bin/")), []);
});

test("something else on the PATH already provides banditshell, so the step is satisfied", () => {
    const home = directory("home");
    const bin = directory("bin");
    fs.writeFileSync(path.join(bin, "banditshell"), "#!/bin/sh\n", { mode: 0o755 });
    const run = spawnSync("bash", ["-c", `source "${path.join(ROOT, "install.sh")}"; path_present && echo yes || echo no`], {
        encoding: "utf8",
        env: { PATH: `${bin}:/usr/bin:/bin`, HOME: home }
    });
    assert.strictEqual(run.stdout.trim(), "yes");
    assert.ok(!fs.existsSync(path.join(home, ".local")));
});

test("the lua-api step writes the pointer and the shim through the CLI, into a temp config only", () => {
    const home = directory("home");
    const hypr = hyprland({ "hyprland.lua": "x" });
    const env = { XDG_STATE_HOME: path.join(home, "state"), HYPR_DIR: hypr };
    const run = spawnSync("bash", ["-c", `source "${path.join(ROOT, "install.sh")}"; lua_api_present && echo before-yes || echo before-no; install_lua_api; echo "$STEP_OUTPUT" | head -3; lua_api_present && echo after-yes || echo after-no`], {
        encoding: "utf8",
        env: { PATH: "/usr/bin:/bin", HOME: home, ...env }
    });
    assert.match(run.stdout, /before-no/, run.stderr);
    assert.match(run.stdout, /after-yes/, run.stdout + run.stderr);
    assert.deepStrictEqual(listing(hypr), ["banditshell.lua", "hyprland.lua"]);
});

test("help names the new verbs and writes the exit codes down", () => {
    const run = cli(["help"]);
    assert.strictEqual(run.code, 0, run.err);
    for (const verb of ["action", "api", "version"])
        assert.match(run.out, new RegExp(`^  ${verb}\\s+\\S`, "m"));
    assert.match(run.out, /exit codes: 0 done, 1 failed, 2 usage, 3 the shell is not running, 4 the shell\nrefused\./);
    for (const word of ["action", "api", "version"])
        assert.strictEqual(cli([word, "help"]).code, 0, word);
    assert.match(cli(["api", "help"]).out, /banditshell api list \[<pattern>\] \[--json\]/);
});

function recordingQuickshell(stub, { failOn = "", reply = "", logLines = "" } = {}) {
    fs.writeFileSync(path.join(stub.dir, "qs"), `#!/bin/sh
echo "qs $*" >>"$STUB_LOG"
case "$*" in *" log") printf '%s' "$QS_LOG_LINES"; exit 0 ;; esac
case "$1" in
list) printf '%s' "$QS_LIST" ;;
ipc)
    case "$*" in *"$QS_FAIL_ON"*) [ -z "$QS_FAIL_ON" ] || exit 1 ;; esac
    [ -z "$QS_REPLY" ] || printf '%s\\n' "$QS_REPLY"
    ;;
esac
`, { mode: 0o755 });
    return { QS_LIST: instance(process.pid), QS_REPLY: reply, QS_FAIL_ON: failOn, QS_LOG_LINES: logLines };
}

test("panel close is one closeAll call and the two things no window owns", () => {
    const stub = stubs();
    const env = recordingQuickshell(stub);
    const run = cli(["panel", "close"], { stub, env });
    assert.strictEqual(run.code, 0, run.err);
    assert.strictEqual(run.out, "closed everything\n");
    const calls = run.calls.filter(c => c.startsWith("qs ipc"));
    assert.deepStrictEqual(calls.map(c => c.replace(/^qs ipc (--pid \d+|-p \S+) call /, "")), ["panels closeAll", "files close", "penmap cancel"]);
});

test("panel close falls back on the old loop when the shell does not know closeAll", () => {
    const stub = stubs();
    const env = recordingQuickshell(stub, { failOn: "closeAll" });
    const run = cli(["panel", "close"], { stub, env });
    assert.strictEqual(run.code, 0, run.err);
    assert.strictEqual(run.out, "closed everything\n");
    const calls = run.calls.filter(c => c.startsWith("qs ipc")).map(c => c.replace(/^qs ipc (--pid \d+|-p \S+) call /, ""));
    assert.strictEqual(calls[0], "panels closeAll");
    for (const wanted of ["menu close", "picker close", "penmap cancel", "launcher close", "wallpapers close", "files close"])
        assert.ok(calls.includes(wanted), wanted);
    assert.ok(calls.length >= 15);
});

test("panel close with no shell is exit 3", () => {
    const stub = stubs();
    const env = { ...fakeQuickshell(stub, { code: 1 }) };
    const run = cli(["panel", "close"], { stub, env });
    assert.strictEqual(run.code, 3);
    assert.match(run.err, /not running/);
});

test("events refuses a stray word and a bad filter, and wants a running shell", () => {
    const stub = stubs();
    const env = recordingQuickshell(stub);
    assert.strictEqual(cli(["events", "now"], { stub, env }).code, 2);
    assert.strictEqual(cli(["events", "--filter"], { stub, env }).code, 2);
    const bad = cli(["events", "--filter", "panel,Not Valid"], { stub, env });
    assert.strictEqual(bad.code, 2);
    assert.match(bad.err, /names like panel or media\.track/);
    const none = cli(["events"], { stub: stubs(), env: { QS_LIST: "" } });
    assert.strictEqual(none.code, 3);
});

function follow(args, lines, { count = 1, wait = 8000 } = {}) {
    const stub = stubs();
    const home = directory("home");
    const env = { PATH: `${stub.dir}:/usr/bin:/bin`, HOME: home, XDG_RUNTIME_DIR: path.join(home, "run"), STUB_LOG: stub.log, NO_COLOR: "1", ...recordingQuickshell(stub) };
    const file = path.join(home, "run/banditshell/events.jsonl");
    const child = spawn("bash", [path.join(ROOT, "cli/banditshell"), ...args], { cwd: ROOT, env, stdio: ["ignore", "pipe", "pipe"] });
    let out = "";
    child.stdout.on("data", chunk => { out += chunk; });
    return new Promise(resolve => {
        const finish = () => {
            clearInterval(pump);
            clearTimeout(giveUp);
            child.kill();
            resolve(out.split("\n").filter(Boolean));
        };
        const giveUp = setTimeout(finish, wait);
        const pump = setInterval(() => {
            if (fs.existsSync(file))
                fs.appendFileSync(file, lines.join("\n") + "\n");
            if (out.split("\n").filter(Boolean).length >= count)
                setTimeout(finish, 300);
        }, 100);
    });
}

test("events follows the stream: one JSON line per event, from now on", async () => {
    const got = await follow(["events"], ['{"event":"panel.opened","time":1,"panel":"launcher","screen":"DP-1"}']);
    assert.ok(got.length >= 1);
    assert.deepStrictEqual(JSON.parse(got[0]), { event: "panel.opened", time: 1, panel: "launcher", screen: "DP-1" });
});

test("events --filter keeps the named events and their groups only", async () => {
    const lines = [
        '{"event":"workspace.changed","time":1,"workspace":2,"previous":1}',
        '{"event":"panel.opened","time":2,"panel":"launcher","screen":"DP-1"}',
        '{"event":"media.state","time":3,"playing":true,"app":"x"}',
        '{"event":"media.track","time":4,"title":"a"}'
    ];
    const got = await follow(["events", "--filter", "panel,media.track"], lines, { count: 2 });
    assert.ok(got.length >= 2);
    const names = new Set(got.map(l => JSON.parse(l).event));
    assert.deepStrictEqual([...names].sort(), ["media.track", "panel.opened"]);
});

test("doctor --report prints versions, a config without secrets, the last 40 log lines and the checks", () => {
    const stub = stubs();
    const home = directory("home");
    const config = path.join(home, "config/banditshell");
    fs.mkdirSync(config, { recursive: true });
    fs.writeFileSync(path.join(config, "config.json"), JSON.stringify({
        theme: "slate",
        keyboard: { height: 300 },
        github: { token: "ghp_SECRET", apiKey: "abc", nested: { password: "hunter2", cookie_jar: "x", name: "kept" } },
        hotkeys: ["a"]
    }));
    const log = Array.from({ length: 60 }, (_, i) => `line ${i}${i === 59 ? " token=SECRETVALUE" : ""}`).join("\n") + "\n";
    const env = { ...recordingQuickshell(stub, { logLines: log }), XDG_CONFIG_HOME: path.join(home, "config"), PATH: `${stub.dir}:${path.dirname(process.execPath)}:/usr/bin:/bin` };
    const run = cli(["doctor", "--report"], { stub, env, home });
    assert.strictEqual(run.code, 0, run.err);
    for (const head of ["## version", "## config", "## log (last 40 lines)", "## checks"])
        assert.ok(run.out.includes(head), head);
    assert.match(run.out, /^version\s+\S/m);
    const config_text = run.out.slice(run.out.indexOf("## config"), run.out.indexOf("## log"));
    const parsed = JSON.parse(config_text.slice(config_text.indexOf("{"), config_text.lastIndexOf("}") + 1));
    assert.deepStrictEqual(parsed, { theme: "slate", keyboard: { height: 300 }, github: { nested: { name: "kept" } }, hotkeys: ["a"] });
    assert.ok(!run.out.includes("ghp_SECRET") && !run.out.includes("hunter2") && !run.out.includes("SECRETVALUE"));
    const logged = run.out.slice(run.out.indexOf("## log"), run.out.indexOf("## checks")).split("\n").filter(l => l.startsWith("line "));
    assert.strictEqual(logged.length, 40);
    assert.strictEqual(logged[0], "line 20");
    assert.match(run.out, /^modules: .*/m);
    assert.match(run.out, /^rules: .*/m);
});

test("doctor --report without a working node leaves the config out instead of filtering it by hand", () => {
    const stub = stubs();
    const home = directory("home");
    const config = path.join(home, "config/banditshell");
    fs.mkdirSync(config, { recursive: true });
    fs.writeFileSync(path.join(config, "config.json"), JSON.stringify({ keyboard: { height: 300 }, github: { token: "ghp_SECRET", nested: { password: "hunter2" } } }));
    fs.writeFileSync(path.join(stub.dir, "node"), "#!/bin/sh\nexit 127\n", { mode: 0o755 });
    const run = cli(["doctor", "--report"], { stub, env: { ...recordingQuickshell(stub), XDG_CONFIG_HOME: path.join(home, "config") }, home });
    assert.strictEqual(run.code, 0, run.err);
    assert.match(run.out, /the config is left out/);
    assert.ok(!run.out.includes("ghp_SECRET") && !run.out.includes("hunter2"));
});

test("doctor --report copes with no config file", () => {
    const stub = stubs();
    const home = directory("home");
    const run = cli(["doctor", "--report"], { stub, env: { ...recordingQuickshell(stub), XDG_CONFIG_HOME: path.join(home, "nowhere") }, home });
    assert.strictEqual(run.code, 0, run.err);
    assert.match(run.out, /no config file/);
});

test("redact-config drops secret-looking names and keeps look-alikes", () => {
    const { isSecret, redact } = require("../scripts/redact-config.js");
    for (const name of ["token", "apiKey", "api_key", "githubToken", "client-secret", "passwordHash", "cookies", "authToken", "sessionKey"])
        assert.ok(isSecret(name), name);
    for (const name of ["keyboard", "hotkeys", "theme", "monkey", "tokenizer", "turkey"])
        assert.ok(!isSecret(name), name);
    assert.deepStrictEqual(redact({ a: [{ key: 1, b: 2 }], password: "x" }), { a: [{ b: 2 }] });
});

const STATUS_REPLIES = [
    [["panel", "launcher", "status"], "open=false", { open: false }],
    [["panel", "island", "status"], 'pinned=false showing=rest activities=0 notifications=0 situation="nothing going on"', { pinned: false, showing: "rest", activities: 0, notifications: 0, situation: "nothing going on" }],
    [["panel", "wallpaper", "status"], "closed on=DP-1 scope=here showing=a.png set=a.png total=12", { state: "closed", on: "DP-1", scope: "here", showing: "a.png", set: "a.png", total: 12 }],
    [["panel", "settings", "status"], "open", { open: true }],
    [["wallpaper"], "on default image forest.jpg 12 in /home/x/Pictures", { text: ["on default image forest.jpg 12 in /home/x/Pictures"] }],
    [["clock", "timer"], "no timers (4 at a time)", { text: ["no timers (4 at a time)"] }],
    [["focus", "quiet"], "quiet        off\nevery night  off\nalarms       let through", { quiet: "off", every_night: "off", alarms: "let through" }],
    [["focus", "mode"], "work (focus on one thing)", { text: ["work (focus on one thing)"] }],
    [["status"], "compositor  hyprland\nfollowing   true", { compositor: "hyprland", following: true }],
    [["status"], "commit      0835201\ncount       12\nzero        0", { commit: "0835201", count: 12, zero: 0 }],
    [["screen", "brightness"], "brightness=80% displays=DP-1 warmth=off", { brightness: "80%", displays: "DP-1", warmth: "off" }]
];

test("every status verb comes out as one JSON object through the global --json", () => {
    for (const [args, reply, expected] of STATUS_REPLIES) {
        const stub = stubs();
        const env = fakeQuickshell(stub, { list: instance(process.pid), reply });
        const run = cli([...args, "--json"], { stub, env });
        assert.strictEqual(run.code, 0, `${args.join(" ")}: ${run.err}`);
        const parsed = JSON.parse(run.out);
        if (args.join(" ") === "panel settings status")
            assert.deepStrictEqual(parsed, { state: "open" });
        else
            assert.deepStrictEqual(parsed, expected, args.join(" "));
    }
});

test("a status verb under --json keeps its exit code and sends nothing to stdout when the shell is away", () => {
    const stub = stubs();
    const env = fakeQuickshell(stub, { code: 1 });
    const run = cli(["panel", "launcher", "status", "--json"], { stub, env });
    assert.strictEqual(run.code, 3);
    assert.strictEqual(run.out, "");
});

test("update status --json and version --json are objects", () => {
    const status = cli(["update", "status", "--json"]);
    assert.strictEqual(typeof JSON.parse(status.out).state, "string");
    const version = cli(["version", "--json"]);
    assert.strictEqual(version.code, 0, version.err);
    assert.ok(JSON.parse(version.out).version);
});
