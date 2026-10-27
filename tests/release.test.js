const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync, execFileSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const SCRIPT = path.join(ROOT, "scripts/release.sh");
const HELPER = path.join(ROOT, "services/whatsnew.js");
const roots = [];

const IDENTITY = {
    GIT_AUTHOR_NAME: "fixture", GIT_AUTHOR_EMAIL: "fixture@localhost",
    GIT_COMMITTER_NAME: "fixture", GIT_COMMITTER_EMAIL: "fixture@localhost"
};
const GIT_ENV = { ...process.env, ...IDENTITY, GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1" };

test.after(() => {
    for (const dir of roots)
        fs.rmSync(dir, { recursive: true, force: true });
});

function git(dir, ...args) {
    return execFileSync("git", ["-C", dir, ...args], { encoding: "utf8", env: GIT_ENV }).trim();
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
const FAKE_GH = '#!/usr/bin/env bash\nprintf "%s\\n" "$*" >>"$GH_LOG"\nfor a in "$@"; do [ "$prev" = --notes-file ] && cat "$a" >>"$GH_LOG"; prev="$a"; done\nexit "${GH_EXIT:-0}"\n';

const change = (type, text) => ({ type, severity: "minor", text });
const whatsNew = (...entries) => JSON.stringify({ entries }, null, 4);

function makeWorld() {
    const root = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-release-"));
    roots.push(root);
    const world = { root, origin: path.join(root, "origin.git"), work: path.join(root, "work"), bin: path.join(root, "bin"), ghLog: path.join(root, "gh.log") };
    execFileSync("git", ["init", "--bare", "-q", "-b", "main", world.origin]);
    execFileSync("git", ["init", "-q", "-b", "main", world.work]);
    git(world.work, "remote", "add", "origin", world.origin);
    write(world.bin, "gh", FAKE_GH);
    fs.chmodSync(path.join(world.bin, "gh"), 0o755);
    const files = {
        "tests/ok.test.js": PASSING_TEST,
        "scripts/check-modules.js": PASSING_NODE,
        "scripts/lint-rules.js": PASSING_NODE,
        "scripts/qml-compile-check.sh": PASSING_SH,
        "scripts/release.sh": fs.readFileSync(SCRIPT, "utf8"),
        "services/whatsnew.js": fs.readFileSync(HELPER, "utf8"),
        "docs/whats-new.json": whatsNew({ id: "2026-10-20", changes: [change("features", "Before the first release")] })
    };
    commit(world, files, "feat(launcher): the start");
    return world;
}

function commit(world, files, message) {
    for (const [file, text] of Object.entries(files))
        write(world.work, file, text);
    git(world.work, "add", "-A");
    git(world.work, "commit", "-q", "-m", message);
    git(world.work, "push", "-q", "origin", "main");
    return git(world.work, "rev-parse", "HEAD");
}

function release(world, ...args) {
    const env = { ...GIT_ENV, HOME: world.root, PATH: `${world.bin}:${process.env.PATH}`, GH_LOG: world.ghLog, ...(world.env ?? {}) };
    delete env.NODE_TEST_CONTEXT;
    const got = spawnSync("bash", [SCRIPT, "--repo", world.work, ...args], { encoding: "utf8", env, timeout: 120000 });
    return { status: got.status, out: got.stdout, err: got.stderr };
}

const remoteRefs = world => git(world.origin, "for-each-ref", "--format=%(refname) %(objectname)");
const ghCalls = world => fs.existsSync(world.ghLog) ? fs.readFileSync(world.ghLog, "utf8") : "";

function refused(world, pattern, ...args) {
    const before = remoteRefs(world);
    const got = release(world, ...args);
    assert.strictEqual(got.status, 1, got.out + got.err);
    assert.match(got.err, pattern);
    assert.strictEqual(remoteRefs(world), before, "a refused release pushed");
    assert.strictEqual(ghCalls(world), "", "a refused release wrote a GitHub release");
    return got;
}

test("the first release is v0.1.0, tags main, moves stable and writes the release", () => {
    const world = makeWorld();
    const main = git(world.work, "rev-parse", "HEAD");
    const got = release(world);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.match(got.out, /^ok\s+node tests$/m);
    assert.match(got.out, /becomes v0\.1\.0, the first release/);
    assert.strictEqual(git(world.origin, "rev-parse", "refs/heads/stable"), main);
    assert.strictEqual(git(world.origin, "rev-parse", "refs/tags/v0.1.0^{commit}"), main);
    assert.strictEqual(git(world.origin, "cat-file", "-t", "refs/tags/v0.1.0"), "tag");
    assert.match(ghCalls(world), /^release create v0\.1\.0 --verify-tag --title banditshell v0\.1\.0 --notes-file /m);
    assert.match(ghCalls(world), /The first numbered release of banditshell/);
});

test("a dry run checks and prints the commands but pushes nothing", () => {
    const world = makeWorld();
    const got = refusedNot(world, "--dry-run");
    assert.match(got.out, /^ {2}git tag -a v0\.1\.0 [0-9a-f]{40} -m banditshell\\ v0\.1\.0$/m);
    assert.match(got.out, /^ {2}git push --atomic origin refs\/tags\/v0\.1\.0 [0-9a-f]{40}:refs\/heads\/stable$/m);
    assert.match(got.out, /^ {2}gh release create v0\.1\.0 --verify-tag /m);
    assert.match(got.out, /nothing was tagged or pushed/);
    assert.deepStrictEqual(git(world.work, "tag", "-l"), "");
});

function refusedNot(world, ...args) {
    const before = remoteRefs(world);
    const got = release(world, ...args);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.strictEqual(remoteRefs(world), before, "a dry run pushed");
    assert.strictEqual(ghCalls(world), "");
    return got;
}

test("a feature since the last tag is a minor bump, with notes from what's new since it", () => {
    const world = makeWorld();
    assert.strictEqual(release(world).status, 0);
    fs.rmSync(world.ghLog);
    const log = whatsNew(
        { id: "2026-10-22", changes: [change("features", "A dictionary in the launcher"), change("bugs", "The clock keeps time")] },
        { id: "2026-10-20", changes: [change("features", "Before the first release")] }
    );
    commit(world, { "a.txt": "1" }, "fix(island): the mic settles (#3)");
    const main = commit(world, { "docs/whats-new.json": log }, "feat(launcher): a dictionary (#4)");
    const got = release(world);
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.match(got.out, /becomes v0\.2\.0: 2 commits since v0\.1\.0, with a feature/);
    assert.strictEqual(git(world.origin, "rev-parse", "refs/heads/stable"), main);
    const notes = ghCalls(world);
    assert.match(notes, /## New\n\n- A dictionary in the launcher/);
    assert.match(notes, /## Fixed\n\n- The clock keeps time/);
    assert.doesNotMatch(notes, /Before the first release/);
});

test("fixes only since the last tag is a patch bump", () => {
    const world = makeWorld();
    assert.strictEqual(release(world).status, 0);
    commit(world, { "a.txt": "1" }, "fix(island): the mic settles (#3)");
    commit(world, { "b.txt": "1" }, "docs: a line");
    const got = release(world, "--dry-run");
    assert.strictEqual(got.status, 0, got.err + got.out);
    assert.match(got.out, /becomes v0\.1\.1: 2 commits since v0\.1\.0, fixes only/);
    assert.match(got.out, /nothing you will notice/);
});

test("nothing new since the last tag is refused", () => {
    const world = makeWorld();
    assert.strictEqual(release(world).status, 0);
    fs.rmSync(world.ghLog);
    refused(world, /not released: main has nothing new since v0\.1\.0/);
    refused(world, /nothing new/, "--dry-run");
});

test("a failing check refuses, and every failing check is named", () => {
    const world = makeWorld();
    commit(world, {
        "tests/bad.test.js": FAILING_TEST,
        "scripts/check-modules.js": FAILING_NODE,
        "scripts/lint-rules.js": FAILING_NODE,
        "scripts/qml-compile-check.sh": FAILING_SH
    }, "fix: broken");
    const got = refused(world, /not released: node tests check-modules lint-rules qml-compile-check did not pass/);
    assert.match(got.err, /3 violations/);
    refused(world, /did not pass/, "--dry-run");
});

test("it refuses anything but a clean checkout of origin/main", () => {
    const world = makeWorld();
    write(world.work, "stray.txt", "x");
    refused(world, /edits or untracked files/, "--dry-run");
    fs.rmSync(path.join(world.work, "stray.txt"));

    git(world.work, "commit", "-q", "--allow-empty", "-m", "feat: not pushed");
    refused(world, /not origin\/main/, "--dry-run");
    git(world.work, "reset", "-q", "--hard", "HEAD~1");

    git(world.work, "checkout", "-q", "-b", "side");
    git(world.work, "commit", "-q", "--allow-empty", "-m", "feat: side");
    refused(world, /not origin\/main/, "--dry-run");
});

test("stable that is not behind main is never moved", () => {
    const world = makeWorld();
    git(world.work, "checkout", "-q", "-b", "elsewhere");
    git(world.work, "commit", "-q", "--allow-empty", "-m", "feat: elsewhere");
    git(world.work, "push", "-q", "origin", "elsewhere:stable");
    git(world.work, "checkout", "-q", "main");
    refused(world, /stable \([0-9a-f]{7}\) is not behind main/);
});

test("a refused push leaves no tag behind", () => {
    const world = makeWorld();
    write(world.origin, "hooks/pre-receive", "#!/bin/sh\nexit 1\n");
    fs.chmodSync(path.join(world.origin, "hooks/pre-receive"), 0o755);
    const got = refused(world, /the push was refused, so neither the tag nor stable moved/);
    assert.ok(got);
    assert.strictEqual(git(world.work, "tag", "-l"), "");
});

test("a GitHub failure after the push says how to finish the release", () => {
    const world = makeWorld();
    world.env = { GH_EXIT: "1" };
    const got = release(world);
    assert.strictEqual(got.status, 1);
    assert.match(got.err, /v0\.1\.0 is out and stable moved, but the GitHub release was not written/);
    assert.match(got.err, /gh release create v0\.1\.0 --verify-tag .*release-notes-v0\.1\.0\.md/);
    assert.ok(git(world.origin, "rev-parse", "refs/heads/stable"));
});

function freshClone(world) {
    const clone = path.join(world.root, `clone-${fs.readdirSync(world.root).length}`);
    execFileSync("git", ["clone", "-q", world.origin, clone], { env: GIT_ENV });
    return clone;
}

function installer(world, clone, snippet, extra = {}) {
    const home = path.join(world.root, "home");
    fs.mkdirSync(home, { recursive: true });
    const env = { PATH: process.env.PATH, HOME: home, LANG: "C.UTF-8", XDG_RUNTIME_DIR: path.join(home, "run"), GIT_CONFIG_GLOBAL: "/dev/null", GIT_CONFIG_NOSYSTEM: "1", ...extra };
    return spawnSync("bash", ["-c", `source "${path.join(ROOT, "install.sh")}"; REPO=${JSON.stringify(clone)}; ${snippet}`], { encoding: "utf8", env });
}

test("the installer moves a fresh clone of main back to the newest release, on main and clean", () => {
    const world = makeWorld();
    assert.strictEqual(release(world).status, 0);
    const released = git(world.work, "rev-parse", "HEAD");
    commit(world, { "a.txt": "1" }, "feat: after the release");
    const clone = freshClone(world);
    const dry = installer(world, clone, "DRY_RUN=1; checkout_release; echo \"moved $?\"");
    assert.match(dry.stdout, /would check out v0\.1\.0, the newest release\nmoved 1/);
    assert.notStrictEqual(git(clone, "rev-parse", "HEAD"), released);
    const got = installer(world, clone, "checkout_release; echo \"moved $?\"");
    assert.match(got.stdout, /checked out v0\.1\.0, the newest release\nmoved 0/, got.stderr);
    assert.strictEqual(git(clone, "rev-parse", "HEAD"), released);
    assert.strictEqual(git(clone, "symbolic-ref", "--short", "HEAD"), "main");
    assert.strictEqual(git(clone, "status", "--porcelain"), "");
    assert.match(installer(world, clone, "checkout_release; echo \"moved $?\"").stdout, /^moved 1$/m);
});

test("the installer leaves a copy alone once it has a config, edits, or no release to go to", () => {
    const world = makeWorld();
    const none = freshClone(world);
    assert.match(installer(world, none, "checkout_release; echo \"moved $?\"").stdout, /no release found on GitHub, so this copy stays on main\nmoved 1/);
    assert.strictEqual(release(world).status, 0);
    commit(world, { "a.txt": "1" }, "feat: after the release");

    const configured = freshClone(world);
    const head = git(configured, "rev-parse", "HEAD");
    write(path.join(world.root, "home"), ".config/banditshell/config.json", "{}");
    assert.match(installer(world, configured, "checkout_release; echo \"moved $?\"").stdout, /^moved 1$/m);
    assert.strictEqual(git(configured, "rev-parse", "HEAD"), head);
    fs.rmSync(path.join(world.root, "home/.config"), { recursive: true });

    const edited = freshClone(world);
    write(edited, "a.txt", "mine");
    assert.match(installer(world, edited, "checkout_release; echo \"moved $?\"").stdout, /this copy has edits, so it stays on main\nmoved 1/);
    assert.strictEqual(git(edited, "rev-parse", "HEAD"), head);
});
