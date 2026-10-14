const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/update.js"), "utf8");
const Update = new Function(src + "\nreturn { report, explain, ago };")();

const said = text => Update.explain(text.split("\n"), "main");

test("the report splits values, the failure flag and git's own lines", () => {
    const got = Update.report("branch=main\ncount=3\nahead=0\ntarget=abc123\n");
    assert.deepStrictEqual(got, { failed: false, output: [], values: { branch: "main", count: "3", ahead: "0", target: "abc123" } });

    const bad = Update.report("failed\n|error: one\n|\ttwo.txt\n|Aborting\n");
    assert.strictEqual(bad.failed, true);
    assert.deepStrictEqual(bad.output, ["error: one", "\ttwo.txt", "Aborting"]);
});

test("a git line that looks like a value stays git's", () => {
    const got = Update.report("failed\n|fatal: key=value in a message\n");
    assert.deepStrictEqual(got.values, {});
    assert.deepStrictEqual(got.output, ["fatal: key=value in a message"]);
});

test("edited files are named, not reduced to Aborting", () => {
    const text = said("error: Your local changes to the following files would be overwritten by merge:\n\tapp.txt\n\tmodules/Bar.qml\nPlease commit your changes or stash them before you merge.\nAborting");
    assert.match(text, /app\.txt, modules\/Bar\.qml/);
    assert.doesNotMatch(text, /Aborting/);
});

test("files in the way are named", () => {
    const text = said("error: The following untracked working tree files would be overwritten by merge:\n\tnew.txt\nPlease move or remove them before you merge.\nAborting");
    assert.match(text, /already exist here: new\.txt\./);
});

test("a long list is cut after three names", () => {
    const text = said("error: Your local changes to the following files would be overwritten by merge:\n\ta\n\tb\n\tc\n\td\n\te\nAborting");
    assert.match(text, /a, b, c and 2 more/);
});

test("diverged history is said plainly", () => {
    const text = said("hint: Diverging branches can't be fast-forwarded, you need to either:\nhint:\nhint: \tgit merge --no-ff\nfatal: Not possible to fast-forward, aborting.");
    assert.match(text, /commits of its own/);
});

test("network and access failures read as such", () => {
    assert.match(said("fatal: unable to access 'https://github.com/x/y.git/': Could not resolve host: github.com"), /Could not reach GitHub/);
    assert.match(said("remote: Repository not found.\nfatal: repository 'https://github.com/x/y.git/' not found"), /turned the request down/);
    assert.match(said("git@github.com: Permission denied (publickey).\nfatal: Could not read from remote repository.\n\nPlease make sure you have the correct access rights\nand the repository exists."), /turned the request down/);
    assert.match(said("fatal: couldn't find remote ref nosuchbranch"), /no branch called "main"/);
    assert.match(said("timed out"), /too long/);
});

test("a lock and a missing .git are told apart", () => {
    assert.match(said("error: Unable to create '/x/.git/index.lock': File exists.\n\nAnother git process seems to be running in this repository"), /Another git command/);
    assert.match(said("fatal: not a git repository (or any parent up to mount point /)\nStopping at filesystem boundary"), /no git history/);
    assert.doesNotMatch(said("fatal: 'nosuchremote' does not appear to be a git repository"), /no git history/);
});

test("anything unknown falls back to git's last error line", () => {
    assert.strictEqual(said("warning: noise\nfatal: something new went wrong\nmore noise"), "something new went wrong");
    assert.strictEqual(said("only a plain line"), "only a plain line");
    assert.strictEqual(Update.explain([], "main"), "git failed without saying why.");
});

test("ago rounds to the unit a person reads", () => {
    const now = 10 * 24 * 3600000;
    assert.strictEqual(Update.ago(now, now), "just now");
    assert.strictEqual(Update.ago(now - 5 * 60000, now), "5 min ago");
    assert.strictEqual(Update.ago(now - 3 * 3600000, now), "3h ago");
    assert.strictEqual(Update.ago(now - 2 * 24 * 3600000, now), "2d ago");
    assert.strictEqual(Update.ago(now + 60000, now), "just now");
});
