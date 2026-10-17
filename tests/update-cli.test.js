const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync, execFileSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const CLI = path.join(ROOT, "cli/banditshell");
const FIXTURES = path.join(__dirname, "fixtures/update");
const worlds = [];

const IDENTITY = {
    GIT_AUTHOR_NAME: "fixture", GIT_AUTHOR_EMAIL: "fixture@localhost",
    GIT_COMMITTER_NAME: "fixture", GIT_COMMITTER_EMAIL: "fixture@localhost"
};

test.after(() => {
    for (const world of worlds) {
        const dir = path.join(world.fakeqs, "inst");
        for (const pid of fs.existsSync(dir) ? fs.readdirSync(dir) : []) {
            try {
                const cmdline = fs.readFileSync(`/proc/${pid}/cmdline`, "utf8");
                if (cmdline.startsWith("sleep"))
                    process.kill(Number(pid));
            } catch {
            }
        }
        fs.rmSync(world.root, { recursive: true, force: true });
    }
});

function git(dir, ...args) {
    return execFileSync("git", ["-C", dir, ...args], { encoding: "utf8", env: { ...process.env, ...IDENTITY, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" } }).trim();
}

function write(dir, file, text, mode) {
    const full = path.join(dir, file);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, text);
    if (mode)
        fs.chmodSync(full, mode);
}

function whatsNew(...ids) {
    return JSON.stringify({ entries: ids.map(id => typeof id === "string"
        ? { id, date: "2026-10-01", changes: [{ type: "ui", severity: "minor", text: `Change ${id}.` }] }
        : id) }, null, 2);
}

const COMPILE_STUB = `#!/usr/bin/env bash
if [ -e "$1/BROKEN" ]; then
    echo "FAIL shell.qml broken on purpose"
    exit 1
fi
echo "CHECKED 0 failures in 1 files"
`;

const INSTALL_V1 = `add_step() { :; }
main() {
    add_step jq "command -v jq" jq 2 "json"
}
`;

function makeWorld() {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-update-"));
    const world = {
        root,
        origin: path.join(root, "origin.git"),
        work: path.join(root, "work"),
        live: path.join(root, "live"),
        home: path.join(root, "home"),
        state: path.join(root, "state"),
        cache: path.join(root, "cache"),
        config: path.join(root, "config"),
        runtime: path.join(root, "runtime"),
        fakebin: path.join(root, "fakebin"),
        fakeqs: path.join(root, "fakeqs")
    };
    worlds.push(world);
    for (const dir of [world.home, world.state, world.cache, world.config, world.runtime, world.fakebin, world.fakeqs])
        fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(world.home, ".gitconfig"), "[user]\n\tuseConfigOnly = true\n");

    fs.copyFileSync(path.join(FIXTURES, "fake-qs"), path.join(world.fakebin, "qs"));
    fs.chmodSync(path.join(world.fakebin, "qs"), 0o755);
    for (const name of ["hyprctl", "notify-send"]) {
        fs.copyFileSync(path.join(FIXTURES, "fake-quiet"), path.join(world.fakebin, name));
        fs.chmodSync(path.join(world.fakebin, name), 0o755);
    }

    execFileSync("git", ["init", "--bare", "-q", "-b", "main", world.origin]);
    execFileSync("git", ["init", "-q", "-b", "main", world.work]);
    git(world.work, "remote", "add", "origin", world.origin);
    write(world.work, "shell.qml", "// v1\n");
    write(world.work, "services/Foo.qml", "// foo v1\n");
    write(world.work, "services/qmldir", "module qs.services\n");
    write(world.work, "services/update.js", fs.readFileSync(path.join(ROOT, "services/update.js"), "utf8"));
    write(world.work, "cli/banditshell", fs.readFileSync(CLI, "utf8"), 0o755);
    write(world.work, "scripts/qml-compile-check.sh", COMPILE_STUB, 0o755);
    write(world.work, "docs/whats-new.json", whatsNew("v1"));
    write(world.work, "install.sh", INSTALL_V1);
    write(world.work, ".gitignore", "bin/\n");
    git(world.work, "add", "-A");
    git(world.work, "commit", "-q", "-m", "v1");
    git(world.work, "push", "-q", "origin", "main");
    execFileSync("git", ["clone", "-q", world.origin, world.live]);
    for (const helper of ["bs-pty", "bs-ls", "bs-gamma"])
        write(world.live, `bin/${helper}`, "#!/bin/sh\n", 0o755);
    return world;
}

function advance(world, message, files, removed = []) {
    for (const [file, text] of Object.entries(files))
        write(world.work, file, text);
    for (const file of removed)
        fs.rmSync(path.join(world.work, file), { force: true });
    git(world.work, "add", "-A");
    git(world.work, "commit", "-q", "-m", message);
    git(world.work, "push", "-q", "origin", "main");
    return git(world.work, "rev-parse", "HEAD");
}

function applyTo(world, target, flags = [], extra = {}) {
    run(world, ["update", "check", "--json"]);
    return run(world, ["update", "apply", ...flags, "--to", target], extra);
}

function run(world, args, extra = {}) {
    const result = spawnSync("bash", [CLI, ...args], {
        encoding: "utf8",
        timeout: 90000,
        env: {
            PATH: `${world.fakebin}:${process.env.PATH}`,
            HOME: world.home,
            XDG_STATE_HOME: world.state,
            XDG_CACHE_HOME: world.cache,
            XDG_CONFIG_HOME: world.config,
            XDG_RUNTIME_DIR: world.runtime,
            BANDITSHELL_DIR: world.live,
            BANDITSHELL_HEALTH_WAIT: "1",
            BANDITSHELL_HEALTH_SCAN: "0",
            FAKE_QS_DIR: world.fakeqs,
            GIT_CONFIG_GLOBAL: path.join(world.home, ".gitconfig"),
            GIT_CONFIG_NOSYSTEM: "1",
            LANG: "C.UTF-8",
            TERM: "dumb",
            ...extra
        }
    });
    return { status: result.status, out: result.stdout, err: result.stderr };
}

function pids(world) {
    const dir = path.join(world.fakeqs, "inst");
    if (!fs.existsSync(dir))
        return [];
    return fs.readdirSync(dir).filter(pid => {
        try {
            process.kill(Number(pid), 0);
            return true;
        } catch {
            return false;
        }
    });
}

const stateFile = (world, name) => path.join(world.state, "banditshell/update", name);
const readState = (world, name) => fs.readFileSync(stateFile(world, name), "utf8").trim();
const liveHead = world => git(world.live, "rev-parse", "HEAD");
const backupFile = (world, file) => path.join(world.cache, "banditshell/lastgood", file);

function startShell(world) {
    const started = run(world, ["start"]);
    assert.strictEqual(started.status, 0, started.err + started.out);
    assert.strictEqual(pids(world).length, 1);
    return pids(world)[0];
}

test("check says current with exit 0 when nothing is new", () => {
    const world = makeWorld();
    const got = run(world, ["update", "check"]);
    assert.strictEqual(got.status, 0, got.err);
    assert.match(got.out, /^up to date at [0-9a-f]{7} on main\n$/);
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(json.state, "current");
    assert.strictEqual(json.behind, 0);
});

test("check classifies a reload and lists the incoming notes before anything is downloaded", () => {
    const world = makeWorld();
    const before = liveHead(world);
    advance(world, "v2", {
        "services/Foo.qml": "// foo version two\n",
        "docs/whats-new.json": whatsNew("v2", "v1")
    });
    const text = run(world, ["update", "check"]);
    assert.strictEqual(text.status, 10, text.err);
    assert.match(text.out, /^update waiting: 1 change, no restart needed\n {2}v2\n {4}- Change v2\.\nrun: banditshell update apply\n$/);
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(json.state, "available");
    assert.strictEqual(json.behind, 1);
    assert.strictEqual(json.class.kind, "reload");
    assert.strictEqual(json.button, "Update");
    assert.deepStrictEqual(json.entries.map(e => e.id), ["v2"]);
    assert.strictEqual(liveHead(world), before);
});

test("check classifies a qmldir change as a restart with the right button and summary", () => {
    const world = makeWorld();
    advance(world, "new singleton", {
        "services/qmldir": "module qs.services\nsingleton Thing 1.0 Thing.qml\n",
        "services/Thing.qml": "pragma Singleton\n",
        "cli/banditshell": fs.readFileSync(CLI, "utf8") + "\n"
    });
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(json.class.kind, "restart");
    assert.strictEqual(json.summary, "1 change, restart needed, commands changed");
    assert.strictEqual(json.button, "Update and restart");
});

test("check reads dependencies from install.sh and removed commands from api/actions.tsv", () => {
    const world = makeWorld();
    write(world.work, "api/actions.tsv", "# id\tstatus\tsince\targv\tdescription\nold.thing\tstable\t1\told\tx\n");
    git(world.work, "add", "-A");
    git(world.work, "commit", "-q", "-m", "api");
    git(world.work, "push", "-q", "origin", "main");
    git(world.live, "pull", "-q", "--ff-only");
    advance(world, "v2", {
        "api/actions.tsv": "# id\tstatus\tsince\targv\tdescription\nold.thing\tremoved\t1\told\tx\n",
        "install.sh": INSTALL_V1.replace(/\}\n$/, "    add_step fd \"command -v fd\" fd 2 \"find\"\n}\n")
    });
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.deepStrictEqual(json.class.apiRemoved, ["old.thing"]);
    assert.deepStrictEqual(json.class.deps, ["fd"]);
    assert.match(json.summary, /1 command removed, needs fd/);
});

test("check names edits here that the update touches, and leaves other edits out", () => {
    const world = makeWorld();
    write(world.live, "shell.qml", "// mine\n");
    write(world.live, "services/qmldir", "module qs.services\n// mine too\n");
    advance(world, "v2", { "shell.qml": "// v2\n" });
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.deepStrictEqual(json.class.dirty, ["shell.qml"]);
    assert.match(json.summary, /1 of your edits is in the way/);
});

test("check reports a copy on another branch and a diverged copy without offering a button", () => {
    const world = makeWorld();
    advance(world, "v2", { "shell.qml": "// v2\n" });
    write(world.live, "extra.txt", "mine\n");
    git(world.live, "add", "-A");
    git(world.live, "commit", "-q", "-m", "local");
    const diverged = run(world, ["update", "check", "--json"]);
    assert.strictEqual(diverged.status, 0);
    assert.strictEqual(JSON.parse(diverged.out).state, "diverged");
    git(world.live, "switch", "-q", "-c", "elsewhere");
    const paused = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(paused.state, "paused");
    assert.strictEqual(paused.behind, 0);
});

test("check fails with exit 1 and git's own words when the remote is unreachable", () => {
    const world = makeWorld();
    git(world.live, "remote", "set-url", "origin", path.join(world.root, "nowhere.git"));
    const got = run(world, ["update", "check", "--json"]);
    assert.strictEqual(got.status, 1);
    const json = JSON.parse(got.out);
    assert.strictEqual(json.state, "error");
    assert.ok(json.output.length > 0);
    const text = run(world, ["update", "check"]);
    assert.strictEqual(text.status, 1);
    assert.match(text.err, /GitHub turned the request down|fatal|does not appear/i);
});

test("the remote and branch come from config.json", () => {
    const world = makeWorld();
    git(world.live, "remote", "rename", "origin", "upstream");
    write(world.config, "banditshell/config.json", JSON.stringify({ theme: "x", updates: { remote: "upstream", branch: "main", seen: "" } }, null, 2));
    const got = run(world, ["update", "check", "--json"]);
    assert.strictEqual(got.status, 0, got.err);
    assert.strictEqual(JSON.parse(got.out).remote, "upstream");
    write(world.config, "banditshell/config.json", JSON.stringify({ updates: { remote: "-bad", branch: "main" } }));
    assert.strictEqual(run(world, ["update", "check"]).status, 1);
});

test("a reload applies in place: previous recorded, no restart, backup refreshed, result written", () => {
    const world = makeWorld();
    const before = liveHead(world);
    const pid = startShell(world);
    const target = advance(world, "v2", { "services/Foo.qml": "// foo version two\n", "docs/whats-new.json": whatsNew("v2", "v1") });
    const got = applyTo(world, target, ["--json"]);
    assert.strictEqual(got.status, 0, got.err + got.out);
    const phases = got.out.trim().split("\n").map(l => JSON.parse(l).phase);
    assert.deepStrictEqual(phases, ["stage", "verify", "apply", "health", "done"]);
    assert.strictEqual(liveHead(world), target);
    assert.strictEqual(readState(world, "previous"), before);
    assert.deepStrictEqual(pids(world), [pid]);
    const result = JSON.parse(readState(world, "result.json"));
    assert.strictEqual(result.ok, true);
    assert.strictEqual(result.toLabel, "v2");
    assert.strictEqual(result.fromLabel, "v1");
    assert.strictEqual(result.shown, false);
    assert.strictEqual(fs.existsSync(stateFile(world, "pending")), false);
    assert.strictEqual(fs.readFileSync(backupFile(world, "services/Foo.qml"), "utf8"), "// foo version two\n");
    assert.strictEqual(fs.existsSync(path.join(world.cache, "banditshell/staged")), false);
});

test("a restart class update restarts the shell into the new tree and refreshes the backup after it is healthy", () => {
    const world = makeWorld();
    const pid = startShell(world);
    const target = advance(world, "singleton", {
        "services/qmldir": "module qs.services\nsingleton Thing 1.0 Thing.qml\n",
        "services/Thing.qml": "pragma Singleton\n"
    });
    const got = applyTo(world, target);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.match(got.out, /Restarting/);
    assert.strictEqual(liveHead(world), target);
    const now = pids(world);
    assert.strictEqual(now.length, 1);
    assert.notStrictEqual(now[0], pid);
    assert.strictEqual(JSON.parse(readState(world, "result.json")).ok, true);
    assert.ok(fs.existsSync(backupFile(world, "services/Thing.qml")));
});

const progress = world => {
    try {
        return readState(world, "progress.log").split("\n").filter(Boolean).map(l => JSON.parse(l));
    } catch {
        return [];
    }
};

function waitForResult(world) {
    const deadline = Date.now() + 30000;
    const finished = () => ["done", "rolledback", "failed"].includes(progress(world).pop()?.phase);
    while (!finished() && Date.now() < deadline)
        spawnSync("sleep", ["0.2"]);
    return JSON.parse(readState(world, "result.json"));
}

test("apply with --detach runs the whole update in a session of its own and reports through progress.log", () => {
    const world = makeWorld();
    const pid = startShell(world);
    const target = advance(world, "singleton", {
        "services/qmldir": "module qs.services\nsingleton Thing 1.0 Thing.qml\n",
        "services/Thing.qml": "pragma Singleton\n"
    });
    const got = applyTo(world, target, ["--detach"]);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.strictEqual(got.out, "");
    assert.strictEqual(waitForResult(world).ok, true);
    const lines = progress(world);
    assert.deepStrictEqual(lines.map(l => l.phase), ["stage", "verify", "apply", "restart", "done"]);
    assert.ok(lines.every(l => l.at > 1700000000));
    assert.notStrictEqual(pids(world)[0], pid);
});

test("a reload with --detach reports a health phase and leaves the shell running", () => {
    const world = makeWorld();
    const pid = startShell(world);
    const target = advance(world, "foo", { "services/Foo.qml": "// foo version two\n" });
    assert.strictEqual(applyTo(world, target, ["--detach"]).status, 0);
    assert.strictEqual(waitForResult(world).ok, true);
    assert.deepStrictEqual(progress(world).map(l => l.phase), ["stage", "verify", "apply", "health", "done"]);
    assert.deepStrictEqual(pids(world), [pid]);
});

test("a detached update that goes back ends its progress with rolledback", () => {
    const world = makeWorld();
    startShell(world);
    const target = advance(world, "bad", { NOANSWER: "x\n", "services/Foo.qml": "// foo version two\n" });
    assert.strictEqual(applyTo(world, target, ["--detach"]).status, 0);
    assert.strictEqual(waitForResult(world).ok, false);
    const phases = progress(world).map(l => l.phase);
    assert.strictEqual(phases[phases.length - 1], "rolledback");
    assert.ok(!phases.includes("done"));
});

test("apply without --to fetches and takes what the check would have shown", () => {
    const world = makeWorld();
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    const got = run(world, ["update", "apply"]);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.strictEqual(liveHead(world), target);
    assert.match(got.out, /Updated to /);
    const again = run(world, ["update", "apply"]);
    assert.strictEqual(again.status, 0);
    assert.match(again.out, /Already up to date/);
});

test("edits the update touches are set aside with a fixed identity, others ride along", () => {
    const world = makeWorld();
    write(world.live, "shell.qml", "// mine\n");
    write(world.live, "services/qmldir", "module qs.services\n// mine\n");
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    const got = applyTo(world, target);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.strictEqual(fs.readFileSync(path.join(world.live, "shell.qml"), "utf8"), "// v2\n");
    assert.strictEqual(fs.readFileSync(path.join(world.live, "services/qmldir"), "utf8"), "module qs.services\n// mine\n");
    assert.match(git(world.live, "stash", "list"), /banditshell update to [0-9a-f]{7}: edits set aside/);
    assert.strictEqual(git(world.live, "log", "-1", "--format=%an <%ae>", "refs/stash"), "banditshell <banditshell@localhost>");
    assert.deepStrictEqual(JSON.parse(readState(world, "result.json")).aside, ["shell.qml"]);
});

test("an untracked file in the way stops the update before anything changes", () => {
    const world = makeWorld();
    write(world.live, "notes.txt", "mine\n");
    const before = liveHead(world);
    const target = advance(world, "adds notes", { "notes.txt": "theirs\n" });
    const got = applyTo(world, target);
    assert.strictEqual(got.status, 1);
    assert.match(got.err, /already exist here: notes\.txt/);
    assert.strictEqual(liveHead(world), before);
    assert.strictEqual(fs.existsSync(stateFile(world, "previous")), false);
    assert.strictEqual(git(world.live, "stash", "list"), "");
});

test("a tree that does not load is refused before the checkout moves", () => {
    const world = makeWorld();
    const before = liveHead(world);
    const target = advance(world, "broken", { BROKEN: "x\n" });
    const got = applyTo(world, target, ["--json"]);
    assert.strictEqual(got.status, 1);
    const last = JSON.parse(got.out.trim().split("\n").pop());
    assert.strictEqual(last.phase, "failed");
    assert.match(last.text, /does not load/);
    assert.strictEqual(liveHead(world), before);
    assert.strictEqual(fs.existsSync(stateFile(world, "previous")), false);
    assert.match(fs.readFileSync(stateFile(world, "verify.log"), "utf8"), /broken on purpose/);
});

test("a shell that never answers rolls back on its own, skips that version and starts the old tree", () => {
    const world = makeWorld();
    const before = liveHead(world);
    startShell(world);
    const target = advance(world, "bad", { NOANSWER: "x\n", "services/qmldir": "module qs.services\n// x\n" });
    const got = applyTo(world, target);
    assert.strictEqual(got.status, 1, got.err + got.out);
    assert.match(got.out, /Went back to/);
    assert.strictEqual(liveHead(world), before);
    assert.strictEqual(fs.existsSync(path.join(world.live, "NOANSWER")), false);
    const result = JSON.parse(readState(world, "result.json"));
    assert.strictEqual(result.ok, false);
    assert.match(result.why, /did not answer/);
    assert.strictEqual(result.to, target);
    assert.strictEqual(readState(world, "skip"), target);
    assert.strictEqual(pids(world).length, 1);
    assert.strictEqual(fs.existsSync(backupFile(world, "NOANSWER")), false);
    const check = run(world, ["update", "check", "--json"]);
    assert.strictEqual(check.status, 0);
    assert.strictEqual(JSON.parse(check.out).state, "skipped");
    const newer = advance(world, "fix", { "shell.qml": "// fixed\n" });
    const again = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(again.state, "available");
    assert.strictEqual(again.target, newer);
});

test("errors in the log after a restart roll back too", () => {
    const world = makeWorld();
    const before = liveHead(world);
    startShell(world);
    const target = advance(world, "throws", { REFERROR: "x\n", "shell.qml": "// v2\n", "services/qmldir": "module qs.services\n// x\n" });
    const got = applyTo(world, target);
    assert.strictEqual(got.status, 1, got.err + got.out);
    assert.strictEqual(liveHead(world), before);
    assert.match(JSON.parse(readState(world, "result.json")).why, /ReferenceError/);
});

test("a reload that breaks the running shell rolls back as well", () => {
    const world = makeWorld();
    const before = liveHead(world);
    startShell(world);
    const target = advance(world, "throws", { REFERROR: "x\n", "services/Foo.qml": "// foo version two\n" });
    const got = applyTo(world, target);
    assert.strictEqual(got.status, 1, got.err + got.out);
    assert.strictEqual(liveHead(world), before);
    assert.match(JSON.parse(readState(world, "result.json")).why, /ReferenceError/);
    assert.strictEqual(pids(world).length, 1);
});

test("errors that were already in the log before a reload are not the update's fault", () => {
    const world = makeWorld();
    startShell(world);
    write(world.live, "REFERROR", "x\n");
    const target = advance(world, "fine", { "services/Foo.qml": "// foo version two\n" });
    const got = applyTo(world, target);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.strictEqual(liveHead(world), target);
});

test("rollback by hand returns to the recorded version and skips the one it left", () => {
    const world = makeWorld();
    const before = liveHead(world);
    startShell(world);
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    assert.strictEqual(applyTo(world, target).status, 0);
    const got = run(world, ["update", "rollback"]);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.strictEqual(liveHead(world), before);
    assert.strictEqual(readState(world, "skip"), target);
    const result = JSON.parse(readState(world, "result.json"));
    assert.strictEqual(result.ok, false);
    assert.strictEqual(result.why, "rolled back by hand");
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json"]).out).state, "skipped");
    const again = run(world, ["update", "rollback"]);
    assert.strictEqual(again.status, 1);
    assert.match(again.err, /no earlier version/);
});

test("status is one line, update alone is the same line, and --json carries the last outcome", () => {
    const world = makeWorld();
    const alone = run(world, ["update"]);
    assert.strictEqual(alone.status, 0, alone.err);
    assert.match(alone.out, /^[0-9a-f]{7} on main, up to date at [0-9a-f]{7} on main\n$/);
    const target = advance(world, "singleton", { "services/qmldir": "module qs.services\n// x\n" });
    run(world, ["update", "check"]);
    const waiting = run(world, ["update"]);
    assert.match(waiting.out, /^[0-9a-f]{7} on main, update waiting: 1 change, restart needed\n$/);
    assert.strictEqual(applyTo(world, target).status, 0);
    const full = run(world, ["update", "status"]);
    assert.match(full.out, /last update: reached /);
    assert.match(full.out, /before the last update: [0-9a-f]{7}/);
    const json = JSON.parse(run(world, ["update", "status", "--json"]).out);
    assert.strictEqual(json.result.ok, true);
    assert.strictEqual(json.state, "current");
    assert.ok(json.previous);
});

test("a missing rsync falls back to cp -a and never fails the launch", () => {
    const world = makeWorld();
    const bin = path.join(world.root, "no-rsync");
    fs.mkdirSync(bin);
    for (const dir of process.env.PATH.split(":")) {
        if (!fs.existsSync(dir))
            continue;
        for (const name of fs.readdirSync(dir)) {
            const link = path.join(bin, name);
            if (name !== "rsync" && !fs.existsSync(link))
                try {
                    fs.symlinkSync(path.join(dir, name), link);
                } catch {
                }
        }
    }
    const env = { PATH: `${world.fakebin}:${bin}` };
    const started = run(world, ["start"], env);
    assert.strictEqual(started.status, 0, started.err + started.out);
    assert.strictEqual(fs.readFileSync(backupFile(world, "shell.qml"), "utf8"), "// v1\n");
    assert.strictEqual(fs.existsSync(backupFile(world, ".git")), false);
    write(world.live, "shell.qml", "// edited\n");
    assert.strictEqual(run(world, ["restart"], env).status, 0);
    assert.strictEqual(fs.readFileSync(backupFile(world, "shell.qml"), "utf8"), "// edited\n");
});

test("launch refreshes the backup only after the health check passes", () => {
    const world = makeWorld();
    assert.strictEqual(run(world, ["start"]).status, 0);
    assert.strictEqual(fs.readFileSync(backupFile(world, "shell.qml"), "utf8"), "// v1\n");
    assert.strictEqual(run(world, ["stop"]).status, 0);
    write(world.live, "shell.qml", "// broken\n");
    write(world.live, "NOANSWER", "x\n");
    const got = run(world, ["start"]);
    assert.strictEqual(got.status, 1);
    assert.strictEqual(fs.readFileSync(backupFile(world, "shell.qml"), "utf8"), "// v1\n");
    assert.match(fs.readFileSync(path.join(world.cache, "banditshell/failed.log"), "utf8"), /did not answer shell status/);
    assert.strictEqual(pids(world).length, 1);
    assert.strictEqual(fs.readFileSync(path.join(world.fakeqs, "inst", pids(world)[0]), "utf8").trim(), path.join(world.cache, "banditshell/lastgood"));
});

test("the dry run says what it would do and changes nothing", () => {
    const world = makeWorld();
    const before = liveHead(world);
    startShell(world);
    const target = advance(world, "singleton", {
        "services/qmldir": "module qs.services\nsingleton Thing 1.0 Thing.qml\n",
        "services/Thing.qml": "pragma Singleton\n"
    });
    const calls = fs.readFileSync(path.join(world.fakeqs, "calls"), "utf8").split("\n").length;
    const got = applyTo(world, target, [], { BANDITSHELL_DRY: "1" });
    assert.strictEqual(got.status, 0, got.err + got.out);
    for (const step of [/dry: stage /, /dry: run scripts\/qml-compile-check.sh/, /dry: git merge --ff-only/, /dry: restart the shell/, /dry: on a failed health check: git reset --keep/])
        assert.match(got.out, step);
    assert.strictEqual(liveHead(world), before);
    assert.strictEqual(fs.existsSync(stateFile(world, "previous")), false);
    assert.strictEqual(fs.existsSync(path.join(world.cache, "banditshell/staged")), false);
    assert.strictEqual(pids(world).length, 1);
    assert.strictEqual(fs.readFileSync(path.join(world.fakeqs, "calls"), "utf8").split("\n").length, calls);
});

test("the dry run of restart and rollback touches no shell", () => {
    const world = makeWorld();
    const pid = startShell(world);
    const restart = run(world, ["restart"], { BANDITSHELL_DRY: "1" });
    assert.strictEqual(restart.status, 0, restart.err + restart.out);
    assert.match(restart.out, /dry: stop the running shell/);
    assert.match(restart.out, /dry: start .* with qs -d -p/);
    assert.match(restart.out, /dry: wait up to 1s for shell status/);
    assert.match(restart.out, /dry: refresh the last known good copy/);
    assert.deepStrictEqual(pids(world), [pid]);
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    assert.strictEqual(applyTo(world, target).status, 0);
    const rollback = run(world, ["update", "rollback"], { BANDITSHELL_DRY: "1" });
    assert.strictEqual(rollback.status, 0, rollback.err + rollback.out);
    assert.match(rollback.out, /dry: git reset --keep/);
    assert.strictEqual(liveHead(world), target);
});

test("a shell run from the last known good copy still finds the checkout to update", () => {
    const world = makeWorld();
    assert.strictEqual(run(world, ["start"]).status, 0);
    const pointer = fs.readFileSync(path.join(world.state, "banditshell/root"), "utf8").trim();
    assert.strictEqual(pointer, world.live);
    advance(world, "v2", { "shell.qml": "// v2\n" });
    const backup = path.join(world.cache, "banditshell/lastgood");
    const got = spawnSync("bash", [path.join(backup, "cli/banditshell"), "update", "check", "--json"], {
        encoding: "utf8",
        env: { PATH: `${world.fakebin}:${process.env.PATH}`, HOME: world.home, XDG_STATE_HOME: world.state, XDG_CACHE_HOME: world.cache, XDG_CONFIG_HOME: world.config, GIT_CONFIG_GLOBAL: path.join(world.home, ".gitconfig"), LANG: "C.UTF-8" }
    });
    assert.strictEqual(got.status, 10, got.stderr);
    assert.strictEqual(JSON.parse(got.stdout).state, "available");
});

test("a second update at the same time is turned away", () => {
    const world = makeWorld();
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    fs.mkdirSync(path.dirname(stateFile(world, "lock")), { recursive: true });
    const holder = spawnSync("bash", ["-c", `exec 8>"$1"; flock -n 8; BANDITSHELL_DIR="$2" bash "$3" update apply --to "$4"; echo "exit $?"`, "_", stateFile(world, "lock"), world.live, CLI, target], {
        encoding: "utf8",
        env: { PATH: `${world.fakebin}:${process.env.PATH}`, HOME: world.home, XDG_STATE_HOME: world.state, XDG_CACHE_HOME: world.cache, XDG_CONFIG_HOME: world.config, FAKE_QS_DIR: world.fakeqs, GIT_CONFIG_GLOBAL: path.join(world.home, ".gitconfig"), LANG: "C.UTF-8" }
    });
    assert.match(holder.stdout, /exit 1/);
    assert.match(holder.stderr, /another update is already running/);
});
