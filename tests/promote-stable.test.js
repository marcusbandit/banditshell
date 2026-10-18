const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync, execFileSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const SCRIPT = path.join(ROOT, "scripts/promote-stable.sh");
const roots = [];

const IDENTITY = {
    GIT_AUTHOR_NAME: "fixture", GIT_AUTHOR_EMAIL: "fixture@localhost",
    GIT_COMMITTER_NAME: "fixture", GIT_COMMITTER_EMAIL: "fixture@localhost"
};

test.after(() => {
    for (const dir of roots)
        fs.rmSync(dir, { recursive: true, force: true });
});

function git(dir, ...args) {
    return execFileSync("git", ["-C", dir, ...args], { encoding: "utf8", env: { ...process.env, ...IDENTITY, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" } }).trim();
}

function write(dir, file, text) {
    const full = path.join(dir, file);
    fs.mkdirSync(path.dirname(full), { recursive: true });
    fs.writeFileSync(full, text);
}

const PASSING_TEST = 'require("node:test")("fixture", () => {});\n';
const FAILING_TEST = 'require("node:test")("fixture", () => { throw new Error("broken on purpose"); });\n';
const PASSING_NODE = "process.exit(0);\n";
const FAILING_NODE = 'console.log("3 violations"); process.exit(1);\n';
const PASSING_SH = "#!/usr/bin/env bash\necho CHECKED 0 failures\n";
const FAILING_SH = "#!/usr/bin/env bash\necho FAIL shell.qml\nexit 1\n";

function whatsNew(...entries) {
    return JSON.stringify({ entries: entries.map(e => typeof e === "string" ? { id: e, changes: [{ type: "ui", severity: "minor", text: "x" }] } : e) });
}

function makeWorld(files = {}) {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-promote-"));
    roots.push(root);
    const world = { root, origin: path.join(root, "origin.git"), work: path.join(root, "work") };
    execFileSync("git", ["init", "--bare", "-q", "-b", "main", world.origin]);
    execFileSync("git", ["init", "-q", "-b", "main", world.work]);
    git(world.work, "remote", "add", "origin", world.origin);
    const base = {
        "tests/ok.test.js": PASSING_TEST,
        "scripts/check-modules.js": PASSING_NODE,
        "scripts/lint-rules.js": PASSING_NODE,
        "scripts/qml-compile-check.sh": PASSING_SH,
        "docs/whats-new.json": whatsNew("2026-10-17")
    };
    for (const [file, text] of Object.entries({ ...base, ...files }))
        write(world.work, file, text);
    git(world.work, "add", "-A");
    git(world.work, "commit", "-q", "-m", "main");
    git(world.work, "push", "-q", "origin", "main");
    return world;
}

function advance(world, files, message = "next") {
    for (const [file, text] of Object.entries(files))
        write(world.work, file, text);
    git(world.work, "add", "-A");
    git(world.work, "commit", "-q", "-m", message);
    git(world.work, "push", "-q", "origin", "main");
    return git(world.work, "rev-parse", "HEAD");
}

function promote(world, ...args) {
    const env = { ...process.env, HOME: world.root, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1", ...IDENTITY };
    delete env.NODE_TEST_CONTEXT;
    const got = spawnSync("bash", [SCRIPT, "--repo", world.work, ...args], { encoding: "utf8", env, timeout: 120000 });
    return { status: got.status, out: got.stdout, err: got.stderr };
}

const remoteRefs = world => git(world.origin, "for-each-ref", "--format=%(refname) %(objectname)");

function checked(world, ...args) {
    const before = remoteRefs(world);
    const got = promote(world, ...args);
    assert.strictEqual(remoteRefs(world), before, "the script pushed");
    return got;
}

test("a passing main prints the exact push and tag commands and pushes nothing", () => {
    const world = makeWorld();
    const got = checked(world);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.match(got.out, /^ok\s+node tests$/m);
    assert.match(got.out, /^ok\s+check-modules$/m);
    assert.match(got.out, /^ok\s+lint-rules$/m);
    assert.match(got.out, /^ok\s+qml-compile-check$/m);
    assert.match(got.out, /version 2026-10-17/);
    assert.match(got.out, /^ {2}git push origin main:stable$/m);
    assert.match(got.out, /^ {2}git tag -a v2026\.10\.17 [0-9a-f]{40} -m banditshell\\ 2026-10-17$/m);
    assert.match(got.out, /^ {2}git push origin v2026\.10\.17$/m);
    assert.match(got.out, /nothing was pushed/);
    assert.doesNotMatch(remoteRefs(world), /stable|v2026/);
});

test("a second push the same day makes a tag with the number", () => {
    const world = makeWorld({ "docs/whats-new.json": whatsNew("2026-10-17-3", "2026-10-17-2") });
    const got = checked(world);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.match(got.out, /git tag -a v2026\.10\.17-3 /);
});

test("the example entry is not a version", () => {
    const world = makeWorld({ "docs/whats-new.json": whatsNew({ id: "shape", example: true, changes: [] }, "2026-10-16-7") });
    const got = checked(world);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.match(got.out, /version 2026-10-16-7/);
});

test("a failing node test stops it and prints no push command", () => {
    const world = makeWorld({ "tests/bad.test.js": FAILING_TEST });
    const got = checked(world);
    assert.strictEqual(got.status, 1);
    assert.match(got.err, /FAIL node tests/);
    assert.match(got.err, /not promoted: node tests did not pass/);
    assert.doesNotMatch(got.out + got.err, /git push/);
});

test("each other check stops it too, and they all report together", () => {
    const world = makeWorld({
        "scripts/check-modules.js": FAILING_NODE,
        "scripts/lint-rules.js": FAILING_NODE,
        "scripts/qml-compile-check.sh": FAILING_SH
    });
    const got = checked(world);
    assert.strictEqual(got.status, 1);
    assert.match(got.err, /not promoted: check-modules lint-rules qml-compile-check did not pass/);
    assert.match(got.err, /3 violations/);
    assert.match(got.out, /^ok\s+node tests$/m);
    assert.doesNotMatch(got.out + got.err, /git push/);
});

test("the newest entry must carry a date id", () => {
    for (const text of [whatsNew({ id: "", changes: [] }), whatsNew("v1"), whatsNew({ changes: [] }), "not json", whatsNew({ id: "shape", example: true, changes: [] })]) {
        const world = makeWorld({ "docs/whats-new.json": text });
        const got = checked(world);
        assert.strictEqual(got.status, 1, text);
        assert.match(got.err, /not promoted: /);
        assert.doesNotMatch(got.out + got.err, /git push/);
    }
});

test("main has to be on GitHub already", () => {
    const world = makeWorld();
    write(world.work, "later.txt", "x\n");
    git(world.work, "add", "-A");
    git(world.work, "commit", "-q", "-m", "local only");
    const got = checked(world);
    assert.strictEqual(got.status, 1);
    assert.match(got.err, /is not the same as origin\/main/);
});

test("stable at main is nothing to promote, stable behind main is promoted", () => {
    const world = makeWorld();
    git(world.work, "push", "-q", "origin", "main:refs/heads/stable");
    const same = checked(world);
    assert.strictEqual(same.status, 1);
    assert.match(same.err, /stable is already at/);
    advance(world, { "docs/whats-new.json": whatsNew("2026-10-18", "2026-10-17") });
    const ahead = checked(world);
    assert.strictEqual(ahead.status, 0, ahead.err + ahead.out);
    assert.match(ahead.out, /ahead of stable by 1/);
    assert.match(ahead.out, /git push origin main:stable/);
});

test("a stable that is not an ancestor of main is refused", () => {
    const world = makeWorld();
    git(world.work, "switch", "-q", "-c", "side");
    write(world.work, "side.txt", "x\n");
    git(world.work, "add", "-A");
    git(world.work, "commit", "-q", "-m", "side");
    git(world.work, "push", "-q", "origin", "side:refs/heads/stable");
    git(world.work, "switch", "-q", "main");
    advance(world, { "next.txt": "y\n" });
    const got = checked(world);
    assert.strictEqual(got.status, 1);
    assert.match(got.err, /not an ancestor of main/);
});

test("a tag that exists already is not made again", () => {
    const world = makeWorld();
    git(world.work, "tag", "v2026.10.17");
    const got = checked(world);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.match(got.out, /git push origin main:stable/);
    assert.doesNotMatch(got.out, /git tag -a/);
    assert.match(got.out, /the tag v2026\.10\.17 exists already/);
});

test("the checks run on main as committed, not on the edits in the working tree", () => {
    const world = makeWorld();
    write(world.work, "tests/bad.test.js", FAILING_TEST);
    write(world.work, "scripts/lint-rules.js", FAILING_NODE);
    const got = checked(world);
    assert.strictEqual(got.status, 0, got.err + got.out);
});

test("the remote can be named, and an unknown one is turned down", () => {
    const world = makeWorld();
    git(world.work, "remote", "rename", "origin", "github");
    const got = checked(world, "--remote", "github");
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.match(got.out, /git push github main:stable/);
    const missing = promote(world, "--remote", "nowhere");
    assert.strictEqual(missing.status, 1);
    assert.match(missing.err, /no remote called nowhere/);
});

test("--no-fetch reads what the last fetch brought", () => {
    const world = makeWorld();
    const got = checked(world, "--no-fetch");
    assert.strictEqual(got.status, 0, got.err + got.out);
});

test("an unknown flag prints usage and exits 2, and --help exits 0", () => {
    const world = makeWorld();
    const bad = promote(world, "--now");
    assert.strictEqual(bad.status, 2);
    assert.match(bad.out, /usage: promote-stable\.sh/);
    assert.strictEqual(promote(world, "--help").status, 0);
});
