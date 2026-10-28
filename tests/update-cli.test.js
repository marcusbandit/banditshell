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
    useChannel(world, "main");
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
    assert.match(got.out, /^up to date at v1 on main\n$/);
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
    assert.match(text.out, /^v2 is waiting: 1 change, no restart needed\n {2}v2\n {4}- Change v2\.\nrun: banditshell update apply\n$/);
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
    write(world.config, "banditshell/config.json", JSON.stringify({ theme: "x", updates: { remote: "upstream", channel: "main", channelUpgraded: true, branch: "main", seen: "" } }, null, 2));
    const got = run(world, ["update", "check", "--json"]);
    assert.strictEqual(got.status, 0, got.err);
    assert.strictEqual(JSON.parse(got.out).remote, "upstream");
    write(world.config, "banditshell/config.json", JSON.stringify({ updates: { remote: "-bad", channel: "main", channelUpgraded: true, branch: "main" } }));
    assert.strictEqual(run(world, ["update", "check"]).status, 1);
});

function useChannel(world, channel, branch = "main") {
    write(world.config, "banditshell/config.json", JSON.stringify({ updates: { remote: "origin", channel, channelUpgraded: true, branch, seen: "" } }, null, 2));
}

test("check carries the channel and the versions on both sides of the update", () => {
    const world = makeWorld();
    const current = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(current.channel, "main");
    assert.strictEqual(current.version, "v1");
    advance(world, "v2", { "services/Foo.qml": "// foo two\n", "docs/whats-new.json": whatsNew("v2", "v1") });
    const waiting = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(waiting.channel, "main");
    assert.strictEqual(waiting.version, "v1");
    assert.strictEqual(waiting.targetVersion, "v2");
});

test("the stable channel follows the stable branch and only moves when stable does", () => {
    const world = makeWorld();
    git(world.work, "push", "-q", "origin", "HEAD:refs/heads/stable");
    useChannel(world, "stable");
    const target = advance(world, "v2", { "services/Foo.qml": "// foo two\n", "docs/whats-new.json": whatsNew("v2", "v1") });
    const still = run(world, ["update", "check", "--json"]);
    assert.strictEqual(still.status, 0, still.err);
    const quiet = JSON.parse(still.out);
    assert.strictEqual(quiet.state, "current");
    assert.strictEqual(quiet.channel, "stable");
    assert.strictEqual(quiet.branch, "stable");
    assert.match(run(world, ["update", "check"]).out, /^up to date at v1 on stable\n$/);
    git(world.work, "push", "-q", "origin", "main:refs/heads/stable");
    const waiting = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(waiting.state, "available");
    assert.strictEqual(waiting.target, target);
    assert.strictEqual(waiting.targetVersion, "v2");
    const before = liveHead(world);
    const done = applyTo(world, target);
    assert.strictEqual(done.status, 0, done.err + done.out);
    assert.strictEqual(liveHead(world), target);
    assert.notStrictEqual(before, target);
    assert.strictEqual(git(world.live, "symbolic-ref", "--short", "HEAD"), "main");
});

test("a checkout ahead of stable is up to date, never taken back", () => {
    const world = makeWorld();
    git(world.work, "push", "-q", "origin", "HEAD:refs/heads/stable");
    advance(world, "v2", { "docs/whats-new.json": whatsNew("v2", "v1") });
    git(world.live, "pull", "-q", "--ff-only");
    useChannel(world, "stable");
    const head = liveHead(world);
    const got = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(got.state, "current");
    assert.strictEqual(liveHead(world), head);
});

test("a stable channel with no release yet stays where it is, calmly", () => {
    const world = makeWorld();
    useChannel(world, "stable");
    const head = liveHead(world);
    const text = run(world, ["update", "check"]);
    assert.strictEqual(text.status, 0, text.err);
    assert.match(text.out, /^there is no release on stable yet, so this copy stays at v1\n$/);
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(json.state, "current");
    assert.strictEqual(json.version, "v1");
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json", "--no-fetch"]).out).state, "current");
    assert.match(run(world, ["update", "apply"]).out, /Already up to date/);
    assert.strictEqual(liveHead(world), head);
});

test("with no release yet, a copy off main reads as paused, on a branch or detached", () => {
    for (const move of [["switch", "-q", "-c", "elsewhere"], ["switch", "-q", "--detach"]]) {
        const world = makeWorld();
        useChannel(world, "stable");
        git(world.live, ...move);
        const got = run(world, ["update", "check", "--json"]);
        assert.strictEqual(got.status, 0, got.err);
        assert.strictEqual(JSON.parse(got.out).state, "paused");
        const text = run(world, ["update", "check"]);
        assert.strictEqual(text.status, 0, text.err);
        assert.match(text.out, /so it does not follow stable/);
    }
});

test("before stable was ever fetched, update says it has not looked yet instead of claiming no release", () => {
    const world = makeWorld();
    cut(world, "v0.1.0", liveHead(world));
    useChannel(world, "stable");
    const quick = run(world, ["update"]);
    assert.strictEqual(quick.status, 0, quick.err);
    assert.match(quick.out, /stable has not been checked yet; banditshell update check looks\n$/);
    assert.doesNotMatch(quick.out, /no release/);
    assert.match(run(world, ["update", "check"]).out, /^up to date at v0\.1\.0 on stable\n$/);
});

test("a check that fails still names the version this copy is on", () => {
    const world = makeWorld();
    git(world.live, "remote", "set-url", "origin", path.join(world.root, "gone.git"));
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(json.state, "error");
    assert.strictEqual(json.version, "v1");
});

test("a branch other than main overrides the channel", () => {
    const world = makeWorld();
    git(world.work, "push", "-q", "origin", "HEAD:refs/heads/dev");
    useChannel(world, "stable", "dev");
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(json.channel, "stable");
    assert.strictEqual(json.branch, "dev");
    assert.strictEqual(json.state, "paused");
});

test("a copy on a feature branch is paused on the stable channel too", () => {
    const world = makeWorld();
    git(world.work, "push", "-q", "origin", "HEAD:refs/heads/stable");
    useChannel(world, "stable");
    git(world.live, "switch", "-q", "-c", "elsewhere");
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json"]).out).state, "paused");
});

test("a channel that is neither stable nor main is turned down before anything is fetched", () => {
    const world = makeWorld();
    useChannel(world, "beta");
    const got = run(world, ["update", "check"]);
    assert.strictEqual(got.status, 1);
    assert.match(got.err, /updates\.channel in config\.json is "beta", and it has to be stable or main/);
});

test("version names the version, the channel and the branch it follows", () => {
    const world = makeWorld();
    const first = run(world, ["version"]);
    let rows = first.out;
    assert.match(rows, /^version\s+v1$/m);
    assert.match(rows, /^channel\s+main$/m);
    assert.match(rows, /^follows\s+main$/m);
    useChannel(world, "stable");
    rows = run(world, ["version"]).out;
    assert.match(rows, /^channel\s+stable$/m);
    assert.match(rows, /^follows\s+stable$/m);
    const json = JSON.parse(run(world, ["version", "--json"]).out);
    assert.strictEqual(json.version, "v1");
    assert.strictEqual(json.channel, "stable");
    assert.strictEqual(json.follows, "stable");
});

function cut(world, tag, sha) {
    git(world.work, "tag", "-a", tag, sha, "-m", `banditshell ${tag}`);
    git(world.work, "push", "-q", "origin", `refs/tags/${tag}`, `${sha}:refs/heads/stable`);
}

const forget = world => fs.rmSync(path.join(world.config, "banditshell/config.json"), { force: true });

test("a copy with no config, or no channel in it, follows releases", () => {
    const world = makeWorld();
    cut(world, "v0.1.0", liveHead(world));
    for (const config of [null, { theme: "x" }, { updates: { remote: "origin", branch: "main" } }]) {
        forget(world);
        if (config)
            write(world.config, "banditshell/config.json", JSON.stringify(config));
        const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
        assert.strictEqual(json.channel, "stable");
        assert.strictEqual(json.branch, "stable");
        assert.match(run(world, ["version"]).out, /^follows\s+stable$/m);
    }
});

test("a config the shell wrote with main before releases follows releases, and main chosen after stays main", () => {
    const world = makeWorld();
    cut(world, "v0.1.0", liveHead(world));
    write(world.config, "banditshell/config.json", JSON.stringify({ updates: { channel: "main", branch: "main", remote: "origin" } }, null, 4));
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json"]).out).channel, "stable");
    write(world.config, "banditshell/config.json", JSON.stringify({ updates: { channel: "main", channelUpgraded: true, branch: "main" } }, null, 4));
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json"]).out).channel, "main");
});

test("main set before the upgrade, with the keep-channel mark, stays main on the CLI side too", () => {
    const world = makeWorld();
    cut(world, "v0.1.0", liveHead(world));
    write(world.config, "banditshell/config.json", JSON.stringify({ updates: { channel: "main", branch: "main", remote: "origin" } }, null, 4));
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json"]).out).channel, "stable");
    write(world.state, "banditshell/keep-channel", "main\n");
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json"]).out).channel, "main");
    assert.match(run(world, ["version"]).out, /^follows\s+main$/m);
});

test("an install on main from before releases lands on the newest release, on its own main branch", () => {
    const world = makeWorld();
    forget(world);
    const old = liveHead(world);
    const release = advance(world, "feat: two", { "services/Foo.qml": "// foo two\n", "docs/whats-new.json": whatsNew("v2", "v1") });
    cut(world, "v0.1.0", release);
    advance(world, "feat: three", { "services/Foo.qml": "// foo three\n", "docs/whats-new.json": whatsNew("v3", "v2", "v1") });
    const text = run(world, ["update", "check"]);
    assert.strictEqual(text.status, 10, text.err);
    assert.match(text.out, /^v0\.1\.0 is waiting: 1 change, no restart needed\n {2}v2\n/);
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(json.target, release);
    assert.strictEqual(json.version, "v1");
    assert.strictEqual(json.targetVersion, "v0.1.0");
    assert.deepStrictEqual(json.entries.map(e => e.id), ["v2"]);
    const done = applyTo(world, release);
    assert.strictEqual(done.status, 0, done.err + done.out);
    assert.match(done.out, /Updated to v0\.1\.0/);
    assert.strictEqual(liveHead(world), release);
    assert.notStrictEqual(old, release);
    assert.strictEqual(git(world.live, "symbolic-ref", "--short", "HEAD"), "main");
    assert.strictEqual(git(world.live, "status", "--porcelain"), "");
    assert.match(run(world, ["update"]).out, /^v0\.1\.0 on main, up to date at v0\.1\.0 on stable\n$/);
    assert.match(run(world, ["version"]).out, /^version\s+v0\.1\.0$/m);
});

test("a copy already past the newest release stays put and shows how far past it is", () => {
    const world = makeWorld();
    cut(world, "v0.1.0", liveHead(world));
    advance(world, "fix: a", { "a.txt": "a" });
    advance(world, "fix: b", { "b.txt": "b" });
    git(world.live, "pull", "-q", "--ff-only");
    const head = liveHead(world);
    forget(world);
    const json = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(json.state, "current");
    assert.strictEqual(json.version, "v0.1.0+2");
    assert.strictEqual(liveHead(world), head);
    useChannel(world, "main");
    assert.match(run(world, ["version"]).out, /^version\s+v0\.1\.0\+2$/m);
});

test("rollback on stable goes to the release before, even with nothing recorded, and skips the one it left", () => {
    const world = makeWorld();
    forget(world);
    const first = liveHead(world);
    cut(world, "v0.1.0", first);
    const second = advance(world, "feat: two", { "services/Foo.qml": "// foo two\n", "docs/whats-new.json": whatsNew("v2", "v1") });
    cut(world, "v0.2.0", second);
    assert.strictEqual(applyTo(world, second).status, 0);
    fs.rmSync(stateFile(world, "previous"));
    const before = JSON.parse(run(world, ["update", "check", "--json", "--no-fetch"]).out);
    assert.strictEqual(before.previous, first);
    assert.strictEqual(before.previousVersion, "v0.1.0");
    const back = run(world, ["update", "rollback"]);
    assert.strictEqual(back.status, 0, back.err + back.out);
    assert.match(back.out, /Went back to v0\.1\.0/);
    assert.strictEqual(liveHead(world), first);
    assert.strictEqual(readState(world, "skip"), second);
    const after = JSON.parse(run(world, ["update", "check", "--json"]).out);
    assert.strictEqual(after.state, "skipped");
    assert.strictEqual(after.previous, "");
    const again = run(world, ["update", "rollback"]);
    assert.strictEqual(again.status, 1);
    assert.match(again.err, /no earlier release to go back to/);
});

test("rollback on stable steps over a release that already failed on this copy", () => {
    const world = makeWorld();
    forget(world);
    const first = liveHead(world);
    cut(world, "v0.1.0", first);
    const broken = advance(world, "fix: two", { "a.txt": "2" });
    cut(world, "v0.1.1", broken);
    const third = advance(world, "fix: three", { "a.txt": "3" });
    cut(world, "v0.1.2", third);
    fs.mkdirSync(path.dirname(stateFile(world, "skip")), { recursive: true });
    fs.writeFileSync(stateFile(world, "skip"), `${broken}\n`);
    assert.strictEqual(applyTo(world, third).status, 0);
    const json = JSON.parse(run(world, ["update", "check", "--json", "--no-fetch"]).out);
    assert.strictEqual(json.previousVersion, "v0.1.0");
    fs.writeFileSync(stateFile(world, "previous"), `${broken}\n`);
    const dry = run(world, ["update", "rollback"], { BANDITSHELL_DRY: "1" });
    assert.strictEqual(dry.status, 0, dry.err + dry.out);
    assert.match(dry.out, new RegExp(`git reset --keep ${first.slice(0, 7)}`));
    assert.strictEqual(readState(world, "previous"), broken);
    assert.strictEqual(liveHead(world), third);
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

test("a reload that breaks the shell, and a restart that breaks it too, rolls back", () => {
    const world = makeWorld();
    const before = liveHead(world);
    startShell(world);
    const target = advance(world, "throws", { REFERROR: "x\n", "services/Foo.qml": "// foo version two\n" });
    const got = applyTo(world, target);
    assert.strictEqual(got.status, 1, got.err + got.out);
    assert.match(got.out, /reload did not take, restarting/);
    assert.strictEqual(liveHead(world), before);
    assert.match(JSON.parse(readState(world, "result.json")).why, /ReferenceError/);
    assert.strictEqual(pids(world).length, 1);
});

test("a reload that fails but starts clean on a restart keeps the new version", () => {
    const world = makeWorld();
    const pid = startShell(world);
    const target = advance(world, "inline", { RELOADFAIL: "x\n", "services/Foo.qml": "// foo version two\n" });
    const got = applyTo(world, target, ["--json"]);
    assert.strictEqual(got.status, 0, got.err + got.out);
    const phases = got.out.trim().split("\n").map(l => JSON.parse(l).phase);
    assert.deepStrictEqual(phases, ["stage", "verify", "apply", "health", "restart", "done"]);
    assert.strictEqual(liveHead(world), target);
    const now = pids(world);
    assert.strictEqual(now.length, 1);
    assert.notStrictEqual(now[0], pid);
    assert.strictEqual(JSON.parse(readState(world, "result.json")).ok, true);
    assert.strictEqual(fs.existsSync(stateFile(world, "skip")), false);
    assert.ok(fs.existsSync(backupFile(world, "RELOADFAIL")));
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
    assert.strictEqual(result.hand, true);
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json"]).out).state, "skipped");
    const again = run(world, ["update", "rollback"]);
    assert.strictEqual(again.status, 1);
    assert.match(again.err, /no earlier version/);
});

test("reinstalling the version a rollback skipped takes it again and forgets the skip", () => {
    const world = makeWorld();
    startShell(world);
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    assert.strictEqual(applyTo(world, target).status, 0);
    assert.strictEqual(run(world, ["update", "rollback"]).status, 0);
    assert.strictEqual(readState(world, "skip"), target);
    const got = run(world, ["update", "apply", "--to", target]);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.strictEqual(liveHead(world), target);
    assert.ok(!fs.existsSync(stateFile(world, "skip")));
    assert.strictEqual(JSON.parse(readState(world, "result.json")).ok, true);
    assert.strictEqual(run(world, ["update", "rollback"]).status, 0);
    assert.strictEqual(readState(world, "skip"), target);
});

test("the check names the version a rollback returns to, and forgets it once back there", () => {
    const world = makeWorld();
    const before = liveHead(world);
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json", "--no-fetch"]).out).previous, "");
    startShell(world);
    const target = advance(world, "v2", { "shell.qml": "// v2\n", "docs/whats-new.json": whatsNew("v2", "v1") });
    assert.strictEqual(applyTo(world, target).status, 0);
    const after = JSON.parse(run(world, ["update", "check", "--json", "--no-fetch"]).out);
    assert.strictEqual(after.previous, before);
    assert.strictEqual(after.previousVersion, "v1");
    assert.strictEqual(run(world, ["update", "rollback"]).status, 0);
    const back = JSON.parse(run(world, ["update", "check", "--json", "--no-fetch"]).out);
    assert.strictEqual(back.previous, "");
    assert.strictEqual(back.previousVersion, "");
});

test("a detached rollback reports through progress.log and toasts no failed start", () => {
    const world = makeWorld();
    const before = liveHead(world);
    startShell(world);
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    assert.strictEqual(applyTo(world, target).status, 0);
    const got = run(world, ["update", "rollback", "--detach"]);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.strictEqual(got.out, "");
    assert.strictEqual(waitForResult(world).why, "rolled back by hand");
    const lines = progress(world);
    assert.strictEqual(lines[lines.length - 1].phase, "rolledback");
    assert.ok(lines.every(l => l.at > 1700000000));
    assert.strictEqual(liveHead(world), before);
    const notes = fs.existsSync(path.join(world.fakeqs, "notes")) ? fs.readFileSync(path.join(world.fakeqs, "notes"), "utf8") : "";
    assert.doesNotMatch(notes, /did not start/);
});

test("rollback refuses to take this copy's own commits off the branch, and the check offers none", () => {
    const world = makeWorld();
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    assert.strictEqual(applyTo(world, target).status, 0);
    write(world.live, "mine.txt", "mine\n");
    git(world.live, "add", "mine.txt");
    git(world.live, "commit", "-q", "-m", "mine");
    const mine = liveHead(world);
    assert.strictEqual(JSON.parse(run(world, ["update", "check", "--json", "--no-fetch"]).out).previous, "");
    const got = run(world, ["update", "rollback"]);
    assert.strictEqual(got.status, 1);
    assert.match(got.err, /commit\(s\) of its own/);
    assert.strictEqual(liveHead(world), mine);
});

test("rollback refuses on a copy paused on another branch", () => {
    const world = makeWorld();
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    assert.strictEqual(applyTo(world, target).status, 0);
    git(world.live, "checkout", "-q", "-b", "elsewhere");
    const got = run(world, ["update", "rollback"]);
    assert.strictEqual(got.status, 1);
    assert.strictEqual(liveHead(world), target);
});

test("a rollback by hand that git refuses changes nothing and skips nothing", () => {
    const world = makeWorld();
    const target = advance(world, "v2", { "shell.qml": "// v2\n" });
    assert.strictEqual(applyTo(world, target).status, 0);
    write(world.live, "shell.qml", "// my own edit\n");
    const got = run(world, ["update", "rollback", "--json"]);
    assert.strictEqual(got.status, 1);
    const lines = got.out.split("\n").filter(Boolean).map(l => JSON.parse(l));
    assert.deepStrictEqual(lines.map(l => l.phase), ["goback", "failed"]);
    assert.strictEqual(liveHead(world), target);
    assert.strictEqual(JSON.parse(readState(world, "result.json")).ok, true);
    assert.ok(!fs.existsSync(stateFile(world, "skip")));
});

test("a detached rollback with nothing recorded fails in progress.log with a time", () => {
    const world = makeWorld();
    assert.strictEqual(run(world, ["update", "rollback", "--detach"]).status, 0);
    const deadline = Date.now() + 30000;
    while (progress(world).pop()?.phase !== "failed" && Date.now() < deadline)
        spawnSync("sleep", ["0.2"]);
    const last = progress(world).pop();
    assert.strictEqual(last.phase, "failed");
    assert.ok(last.at > 1700000000);
});

test("status is one line, update alone is the same line, and --json carries the last outcome", () => {
    const world = makeWorld();
    const alone = run(world, ["update"]);
    assert.strictEqual(alone.status, 0, alone.err);
    assert.match(alone.out, /^v1 on main, up to date at v1 on main\n$/);
    const target = advance(world, "singleton", { "services/qmldir": "module qs.services\n// x\n" });
    run(world, ["update", "check"]);
    const waiting = run(world, ["update"]);
    assert.match(waiting.out, /^v1 on main, v1 is waiting: 1 change, restart needed\n$/);
    assert.strictEqual(applyTo(world, target).status, 0);
    const full = run(world, ["update", "status"]);
    assert.match(full.out, /last update: reached /);
    assert.match(full.out, /update rollback goes back to v1/);
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
