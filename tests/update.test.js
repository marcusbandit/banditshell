const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/update.js"), "utf8");
const Update = new Function(src + "\nreturn { byHand, report, explain, setAside, ago, nameStatus, classify, summary, button, removedActions, addedSteps, incomingEntries, assess, waitingText, linesOf, outcomeText, phaseOf, parseCheck, channelOf, branchFor, channelText, haveText, following, waitingHeadline, reportWords, reportScript };")();

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

test("edits set aside are named, and nothing set aside says nothing", () => {
    assert.strictEqual(Update.setAside(""), "");
    assert.strictEqual(Update.setAside(undefined), "");
    assert.match(Update.setAside("scripts/zsh-completion.sh\tmodules/Bar.qml"), /zsh-completion\.sh, modules\/Bar\.qml were in the way/);
});

const status = (...rows) => rows.join("\n") + "\n";

const entriesText = list => JSON.stringify({ entries: list });

test("name-status rows are read, renames become a removal and an addition", () => {
    const got = Update.nameStatus(status("M\tshell.qml", "A\tservices/New.qml", "D\told.txt", "R100\ta.qml\tb.qml", "C75\tc.qml\td.qml", "", "junk"));
    assert.deepStrictEqual(got, [
        { status: "M", path: "shell.qml" },
        { status: "A", path: "services/New.qml" },
        { status: "D", path: "old.txt" },
        { status: "D", path: "a.qml" },
        { status: "A", path: "b.qml" },
        { status: "A", path: "d.qml" }
    ]);
    assert.deepStrictEqual(Update.nameStatus(""), []);
    assert.deepStrictEqual(Update.nameStatus(undefined), []);
});

test("a qmldir change is a restart, whatever else came with it", () => {
    const c = Update.classify({ nameStatus: status("M\tservices/qmldir", "M\tservices/Bar.qml") });
    assert.strictEqual(c.kind, "restart");
    assert.strictEqual(c.restart, true);
    assert.deepStrictEqual(c.restartReasons, ["qmldir changed"]);
});

test("a QML file added or removed, or shell.qml touched, is a restart", () => {
    assert.strictEqual(Update.classify({ nameStatus: status("A\tmodules/Foo.qml") }).kind, "restart");
    assert.strictEqual(Update.classify({ nameStatus: status("D\tmodules/Foo.qml") }).kind, "restart");
    assert.strictEqual(Update.classify({ nameStatus: status("M\tshell.qml") }).kind, "restart");
    assert.deepStrictEqual(Update.classify({ nameStatus: status("M\tshell.qml") }).restartReasons, ["shell.qml changed"]);
});

test("editing files in place is a reload", () => {
    const c = Update.classify({ nameStatus: status("M\tmodules/bar/Bar.qml", "M\tservices/update.js") });
    assert.strictEqual(c.kind, "reload");
    assert.strictEqual(c.restart, false);
    assert.deepStrictEqual(c.restartReasons, []);
});

test("docs, tests and scripts alone change nothing the shell runs", () => {
    const c = Update.classify({ nameStatus: status("M\tdocs/whats-new.json", "M\ttests/update.test.js", "M\tREADME.md") });
    assert.strictEqual(c.kind, "none");
    assert.strictEqual(c.cli, false);
});

test("cli, api and lua paths mean the commands changed", () => {
    for (const path of ["cli/banditshell", "api/actions.tsv", "lua/banditshell.lua"])
        assert.strictEqual(Update.classify({ nameStatus: status(`M\t${path}`) }).cli, true, path);
    assert.strictEqual(Update.classify({ nameStatus: status("M\tmodules/Cli.qml") }).cli, false);
});

test("api rows that turned removed are named, rows still alive are not", () => {
    const before = "# id\tstatus\tsince\targv\tdescription\nlauncher.toggle\tstable\t1\tpanel launcher toggle\tx\nold.thing\tdeprecated\t1\told\tx\ngone.thing\tstable\t1\tgone\tx\nlong.gone\tremoved\t1\tx\tx\n";
    const after = "# id\tstatus\tsince\targv\tdescription\nlauncher.toggle\tstable\t1\tpanel launcher toggle\tx\nold.thing\tremoved\t1\told\tx\nlong.gone\tremoved\t1\tx\tx\n";
    assert.deepStrictEqual(Update.removedActions(before, after), ["old.thing", "gone.thing"]);
    assert.deepStrictEqual(Update.removedActions("", after), []);
    const c = Update.classify({ nameStatus: status("M\tapi/actions.tsv"), actionsBefore: before, actionsAfter: after });
    assert.strictEqual(c.api, true);
    assert.deepStrictEqual(c.apiRemoved, ["old.thing", "gone.thing"]);
});

test("helpers, shaders and settings defaults are flagged from their paths", () => {
    const c = Update.classify({ nameStatus: status("M\tsrc/bs-pty.c", "M\tcomponents/blob/blob.frag", "M\tcomponents/blob/blob.frag.qsb", "M\tconfig/Config.qml") });
    assert.strictEqual(c.helpers, true);
    assert.strictEqual(c.shaders, true);
    assert.strictEqual(c.config, true);
    assert.strictEqual(Update.classify({ nameStatus: status("M\tsrc/gamma-client-protocol.h") }).helpers, true);
    assert.strictEqual(Update.classify({ nameStatus: status("M\tsrc/wlr-gamma-control-unstable-v1.xml") }).helpers, false);
});

test("new install steps are the deps, the definition line is not a step", () => {
    const before = "add_step() {\n}\nmain() {\n    add_step jq   \"command -v jq\"  jq 2 \"x\"\n}\n";
    const after = before + "    add_step fd   \"command -v fd\"  fd 2 \"x\"\n    add_step ripgrep \"command -v rg\" ripgrep 2 \"x\"\n";
    assert.deepStrictEqual(Update.addedSteps(before, after), ["fd", "ripgrep"]);
    assert.deepStrictEqual(Update.addedSteps(after, before), []);
    assert.deepStrictEqual(Update.addedSteps("", ""), []);
    const guarded = after + "    if [ \"$PKG_MANAGER\" = apk ]; then\n        add_step gnu-userland x gnu-userland 1 \"x\"\n    fi\n";
    assert.deepStrictEqual(Update.addedSteps(after, guarded), []);
    assert.deepStrictEqual(Update.classify({ nameStatus: status("M\tinstall.sh"), installBefore: before, installAfter: after }).deps, ["fd", "ripgrep"]);
});

test("edits here that the update also touches are listed, others are not", () => {
    const c = Update.classify({
        nameStatus: status("M\tservices/A.qml", "M\tservices/B.qml"),
        dirty: "services/A.qml\nservices/Mine.qml\n"
    });
    assert.deepStrictEqual(c.dirty, ["services/A.qml"]);
});

test("an untracked file the update would add is blocked", () => {
    const c = Update.classify({ nameStatus: status("A\tnotes.txt", "M\tservices/A.qml"), untracked: "notes.txt\nother.txt\n" });
    assert.deepStrictEqual(c.blocked, ["notes.txt"]);
});

test("the notes can add a restart, a deps list and binds, never remove what the diff found", () => {
    const entries = [{ id: "e", changes: [{ text: "x" }], impact: { restart: true, cli: true, binds: ["launcher.toggle"], deps: ["fd"] } }];
    const c = Update.classify({ nameStatus: status("M\tmodules/Bar.qml"), entries });
    assert.strictEqual(c.kind, "restart");
    assert.deepStrictEqual(c.restartReasons, ["the notes for this version say so"]);
    assert.strictEqual(c.cli, true);
    assert.deepStrictEqual(c.binds, ["launcher.toggle"]);
    assert.deepStrictEqual(c.deps, ["fd"]);
    const quiet = Update.classify({ nameStatus: status("M\tservices/qmldir"), entries: [{ id: "e", changes: [], impact: { restart: false, cli: false, binds: [], deps: [] } }] });
    assert.strictEqual(quiet.kind, "restart");
});

test("without notes the diff alone decides", () => {
    const c = Update.classify({ nameStatus: status("M\tmodules/Bar.qml"), entries: [{ id: "e", changes: [], impact: null }] });
    assert.strictEqual(c.kind, "reload");
    assert.deepStrictEqual(c.binds, []);
});

test("the summary names what the person must know, in order", () => {
    const c = Update.classify({
        nameStatus: status("M\tservices/qmldir", "M\tcli/banditshell"),
        commits: 5
    });
    assert.strictEqual(Update.summary(c), "5 changes, restart needed, commands changed");
    assert.strictEqual(Update.button(c), "Update and restart");
});

test("a reload or a change to docs only both say no restart is needed", () => {
    const reload = Update.classify({ nameStatus: status("M\tmodules/Bar.qml"), commits: 1 });
    assert.strictEqual(Update.summary(reload), "1 change, no restart needed");
    assert.strictEqual(Update.button(reload), "Update");
    const quiet = Update.classify({ nameStatus: status("M\tdocs/a.md"), commits: 2 });
    assert.strictEqual(Update.summary(quiet), "2 changes, no restart needed");
    assert.strictEqual(Update.summary(Update.classify({ nameStatus: "" })), "no changes");
});

test("the summary lists deps, removed commands, binds and edits in the way", () => {
    const entries = [{ id: "e", changes: [{ text: "x" }], impact: { restart: false, cli: false, binds: ["a", "b"], deps: [] } }];
    const c = Update.classify({
        nameStatus: status("M\tmodules/Bar.qml", "M\tinstall.sh", "M\tsrc/bs-ls.c", "M\tapi/actions.tsv", "M\tconfig/Config.qml"),
        installBefore: "    add_step jq x\n",
        installAfter: "    add_step jq x\n    add_step fd x\n    add_step ripgrep x\n    add_step jq2 x\n",
        actionsBefore: "a\tstable\nb\tstable\n",
        actionsAfter: "a\tremoved\nb\tstable\n",
        dirty: "modules/Bar.qml\nconfig/Config.qml",
        entries,
        commits: 3
    });
    assert.strictEqual(Update.summary(c), "1 change, no restart needed, commands changed, 1 command removed, 2 binds affected, helpers rebuild, needs fd, ripgrep and jq2, settings defaults changed, 2 of your edits are in the way");
});

test("incoming entries are the ones the local log lacks, examples and empty ones left out", () => {
    const before = entriesText([{ id: "old", changes: [{ type: "ui", severity: "minor", text: "Old." }] }]);
    const after = entriesText([
        { id: "new", date: "2026-10-18", changes: [{ type: "bugs", severity: "major", text: " Fixed. " }], impact: { restart: true, binds: ["x", 3] } },
        { id: "silent", changes: [] },
        { id: "example", example: true, changes: [{ text: "Shape." }] },
        { id: "old", changes: [{ type: "ui", severity: "minor", text: "Old." }] }
    ]);
    const got = Update.incomingEntries(before, after);
    assert.strictEqual(got.length, 1);
    assert.strictEqual(got[0].id, "new");
    assert.strictEqual(got[0].changes[0].text, "Fixed.");
    assert.deepStrictEqual(got[0].impact, { restart: true, cli: false, binds: ["x"], deps: [] });
    assert.deepStrictEqual(Update.incomingEntries("not json", after).map(e => e.id), ["new", "old"]);
    assert.deepStrictEqual(Update.incomingEntries(before, "garbage"), []);
});

test("a report from facts joins meta, classification, summary and entries", () => {
    const report = Update.assess({
        meta: "state=available\nhead=aaa\ntarget=bbb\nbranch=main\nbehind=2\nahead=0\nskipped=0\ncheckedAt=1700000000000\n",
        nameStatus: status("M\tservices/qmldir"),
        dirty: "", untracked: "", actionsBefore: "", actionsAfter: "", installBefore: "", installAfter: "",
        whatsnewBefore: entriesText([]),
        whatsnewAfter: entriesText([{ id: "n", changes: [{ type: "ui", severity: "minor", text: "Looks different." }] }])
    });
    assert.strictEqual(report.state, "available");
    assert.strictEqual(report.behind, 2);
    assert.strictEqual(report.skipped, false);
    assert.strictEqual(report.summary, "1 change, restart needed");
    assert.strictEqual(report.button, "Update and restart");
    assert.deepStrictEqual(report.entries.map(e => e.id), ["n"]);
    assert.match(Update.waitingText(report), /^update waiting: 1 change, restart needed\n  n\n    - Looks different\.\nrun: banditshell update apply$/);
    assert.match(Update.waitingText(Object.assign({}, report, { targetVersion: "v0.2.0" })), /^v0\.2\.0 is waiting: 1 change, restart needed\n/);
    const lines = Update.linesOf(report).split("\n");
    assert.ok(lines.includes("kind=restart"));
    assert.ok(lines.includes("restart=1"));
    assert.ok(lines.includes("button=Update and restart"));
});

test("a made check line and a phase line read back, anything else is null", () => {
    assert.deepStrictEqual(Update.phaseOf('{"phase":"verify","text":"Checking it loads..."}'), { phase: "verify", text: "Checking it loads..." });
    assert.strictEqual(Update.phaseOf("plain text"), null);
    assert.strictEqual(Update.phaseOf('{"nophase":1}'), null);
    assert.strictEqual(Update.parseCheck(""), null);
    assert.strictEqual(Update.parseCheck("[1]") instanceof Array, true);
});

test("the outcome tells where the person stands in plain words", () => {
    assert.strictEqual(Update.outcomeText(null), "");
    assert.strictEqual(Update.outcomeText({ ok: true, to: "abcdef123", toLabel: "2026-10-18" }), "Updated to 2026-10-18.");
    assert.strictEqual(Update.outcomeText({ ok: false, from: "1111111aaa", to: "2222222bbb", why: "The shell did not answer" }),
        "Update 2222222 did not start, so you are back on 1111111. The shell did not answer. It will be tried again when a newer version arrives.");
});

test("a rollback by hand says where it went back to, not that something failed", () => {
    const back = { ok: false, hand: true, fromLabel: "2026-10-24", toLabel: "2026-10-25", why: "rolled back by hand" };
    assert.strictEqual(Update.outcomeText(back, "2026-10-24"),
        "Back on 2026-10-24; the shell restarted on it. 2026-10-25 is skipped until a newer version arrives.");
    assert.match(Update.outcomeText(back, "2026-10-25"), /still runs 2026-10-25\. Run banditshell restart to start 2026-10-24\./);
    assert.strictEqual(Update.byHand({ ok: false, why: "rolled back by hand" }), false);
});

const quotingSrc = fs.readFileSync(path.join(ROOT, "services/quoting.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { posix } = new Function(quotingSrc + "\nreturn { posix };")();

const wentBack = { ok: false, hand: true, from: "1111111aaaa", to: "2222222bbbb", fromLabel: "2026-10-24", toLabel: "2026-10-25", why: "rolled back by hand" };

test("a report after going back carries the words, the skipped version and the current one", () => {
    assert.strictEqual(Update.reportWords("  the bar   went blank ", wentBack, "2026-10-24"),
        "the bar went blank\n\nWent back in the update menu.\nSkipped: 2026-10-25 (2222222)\nCurrent: 2026-10-24 (1111111)");
    assert.match(Update.reportWords("\nthe bar went blank\n\n\n\nexpected  the clock \n", wentBack, "2026-10-24"),
        /^the bar went blank\n\nexpected the clock\n\nWent back/);
    assert.match(Update.reportWords("", { ...wentBack, fromLabel: "", toLabel: "" }, ""), /^\(no words were given\)\n[^]*Skipped: 2222222\nCurrent: 1111111$/);
    assert.match(Update.reportWords("x", wentBack, "2026-10-25"), /Current: 2026-10-25$/);
});

test("the report command hands the words to triage as one argument, whatever they hold", () => {
    const os = require("node:os");
    const { spawnSync } = require("node:child_process");
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-report-"));
    try {
        const cli = path.join(dir, "it's a cli");
        const out = path.join(dir, "args");
        fs.writeFileSync(cli, `printf '%s\\0' "$@" >'${out}'\n`);
        for (const words of ["it's $(touch pwned) `touch pwned` \"q\" \\ ;|&", "--yes"]) {
            const ran = spawnSync("sh", ["-c", Update.reportScript(posix, cli, words, wentBack, "2026-10-24")], { cwd: dir, input: "\n", encoding: "utf8" });
            assert.strictEqual(ran.status, 0, ran.stderr);
            const args = fs.readFileSync(out, "utf8").split("\0").slice(0, -1);
            assert.deepStrictEqual(args, ["triage", Update.reportWords(words, wentBack, "2026-10-24")]);
            assert.ok(!args.includes("--yes"));
            assert.ok(!fs.existsSync(path.join(dir, "pwned")));
        }
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
});

test("a channel is stable or main, and anything else reads as stable, the default", () => {
    assert.strictEqual(Update.channelOf("stable"), "stable");
    assert.strictEqual(Update.channelOf(" main "), "main");
    assert.strictEqual(Update.channelOf("beta"), "stable");
    assert.strictEqual(Update.channelOf(undefined), "stable");
});

test("the channel picks the branch, and a branch other than main overrides it", () => {
    assert.strictEqual(Update.branchFor("main", "main"), "main");
    assert.strictEqual(Update.branchFor("stable", "main"), "stable");
    assert.strictEqual(Update.branchFor("stable", ""), "stable");
    assert.strictEqual(Update.branchFor("stable", "dev"), "dev");
    assert.strictEqual(Update.branchFor("main", "dev"), "dev");
    assert.strictEqual(Update.branchFor(undefined, undefined), "stable");
});

test("the menu names the channel, or the branch followed in its place", () => {
    assert.strictEqual(Update.channelText("stable", "main"), "stable channel");
    assert.strictEqual(Update.channelText("main", "main"), "main channel");
    assert.strictEqual(Update.channelText("stable", "dev"), "following dev");
});

test("a copy on main follows stable, any other branch only follows itself", () => {
    assert.strictEqual(Update.following("main", "stable"), true);
    assert.strictEqual(Update.following("stable", "stable"), true);
    assert.strictEqual(Update.following("feature", "stable"), false);
    assert.strictEqual(Update.following("main", "dev"), false);
    assert.strictEqual(Update.following("dev", "dev"), true);
});

test("a missing stable branch says there is no release yet, without sending anyone to main", () => {
    const text = "fatal: couldn't find remote ref stable";
    assert.match(Update.explain(text.split("\n"), "stable"), /no release on GitHub yet/);
    assert.doesNotMatch(Update.explain(text.split("\n"), "stable"), /main/);
    assert.strictEqual(Update.explain(text.split("\n"), "dev"), 'GitHub has no branch called "dev".');
});

test("a waiting release on stable is named by its number, anything else by its commits", () => {
    assert.strictEqual(Update.waitingHeadline("stable", 4, "v0.2.0"), "v0.2.0 is ready");
    assert.strictEqual(Update.waitingHeadline("stable", 1, ""), "1 new commit on stable");
    assert.strictEqual(Update.waitingHeadline("main", 3, "v0.1.0+3"), "3 new commits on main");
});

test("the count is the changes listed, and commits only when nothing is listed", () => {
    const entries = [{ id: "a", changes: [{ text: "x" }, { text: "y" }, { text: "z" }] }];
    assert.strictEqual(Update.summary(Update.classify({ nameStatus: "M\tmodules/Foo.qml", entries, commits: 1 })), "3 changes, no restart needed");
    assert.strictEqual(Update.summary(Update.classify({ nameStatus: "M\tmodules/Foo.qml", entries: [], commits: 4 })), "4 changes, no restart needed");
});

test("the menu says which version you have and what you follow, never Version v", () => {
    assert.strictEqual(Update.haveText("v0.1.0", "stable", "main"), "You have v0.1.0, on the stable channel");
    assert.strictEqual(Update.haveText("v0.2.0+2", "main", "main"), "You have v0.2.0+2, on the main channel");
    assert.strictEqual(Update.haveText("v0.1.0", "stable", "dev"), "You have v0.1.0, following dev");
    assert.strictEqual(Update.haveText("", "stable", "main"), "On the stable channel");
});
