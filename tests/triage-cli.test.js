const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { CLI, ROOT, cleanup, directory, stubs, cli } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

const ISSUE_URL = "https://github.com/fake/repo/issues/7";

function stubGh(stub) {
    fs.writeFileSync(path.join(stub.dir, "gh"), `#!/bin/sh
printf -- '--call\\n' >>"$GH_ARGS"
printf '%s\\n' "$@" >>"$GH_ARGS"
if [ "$1 $2" = "auth status" ]; then exit "\${GH_AUTH:-0}"; fi
if [ "$1 $2" = "issue create" ]; then
    while [ $# -gt 0 ]; do
        if [ "$1" = --body-file ]; then
            if [ "$2" = - ]; then cat >"$GH_BODY"; else cp "$2" "$GH_BODY"; fi
        fi
        shift
    done
    if [ -n "$GH_EXIT" ]; then echo "gh: HTTP 502" >&2; exit "$GH_EXIT"; fi
    if [ -z "$GH_QUIET" ]; then echo ${ISSUE_URL}; fi
fi
`, { mode: 0o755 });
    fs.writeFileSync(path.join(stub.dir, "node"), `#!/bin/sh
case "$*" in
*check-modules.js* | *lint-rules.js*) echo "stub: not run"; exit 0 ;;
esac
exec ${process.execPath} "$@"
`, { mode: 0o755 });
    return { GH_ARGS: path.join(stub.dir, "gh-args.log"), GH_BODY: path.join(stub.dir, "gh-body.md") };
}

function world(extra = {}) {
    const stub = stubs();
    const env = { ...stubGh(stub), BANDITSHELL_TRIAGE_REPO: "fake/repo", PAGER: "cat", ...extra };
    const home = directory("home");
    const resolved = spawnSync("sh", ["-c", "command -v gh"], { env: { PATH: `${stub.dir}:/usr/bin:/bin` }, encoding: "utf8" }).stdout.trim();
    assert.strictEqual(resolved, path.join(stub.dir, "gh"), "the stub gh must come first on PATH");
    return { stub, env, home };
}

function triage(args, { stub, env, home }) {
    const run = cli(["triage", ...args], { stub, env, home });
    const argsLog = fs.existsSync(env.GH_ARGS) ? fs.readFileSync(env.GH_ARGS, "utf8") : "";
    const calls = argsLog.split("--call\n").filter(Boolean).map(c => c.split("\n").slice(0, -1));
    const create = calls.find(c => c[0] === "issue" && c[1] === "create");
    return {
        ...run,
        calls,
        create,
        arg: name => create?.[create.indexOf(name) + 1],
        body: fs.existsSync(env.GH_BODY) ? fs.readFileSync(env.GH_BODY, "utf8") : null,
        saved: savedReports(home)
    };
}

function savedReports(home) {
    const dir = path.join(home, ".local/state/banditshell/triage");
    return fs.existsSync(dir) ? fs.readdirSync(dir).map(name => path.join(dir, name)) : [];
}

function secretWords(home) {
    return {
        text: [
            "clone failed at https://marcus:s3cretpass@github.com/o/r.git",
            "Authorization: Bearer abc123def",
            "retry with Bearer zzz111yyy",
            "Authorization: Basic dXNlcjpwYXNzd29yZA",
            "gh tokens ghp_AAAA1111 gho_BBBB2222 ghu_CCCC3333 ghs_DDDD4444 ghr_EEEE5555 github_pat_11ABC_xyz987",
            "key sk-ant-api03-ZZZZ_yyyy-1234 and sk-proj-QQQQ9999wwww",
            `path ${home}/projects/x`,
            'password: "hunter 2 two"',
            'config password="a b c"',
            '{"apiKey": "sk-live-x1", "name": "kept"}',
            "secret_key: sk9999 and client_secret=cs8888 and GITHUB_TOKEN=gt7777",
            "Cookie: a=b; session=cookiesession123"
        ].join(" and "),
        leaks: ["s3cretpass", "abc123def", "zzz111yyy", "dXNlcjpwYXNzd29yZA", "ghp_AAAA1111", "gho_BBBB2222", "ghu_CCCC3333", "ghs_DDDD4444",
            "ghr_EEEE5555", "github_pat_11ABC_xyz987", "sk-ant-api03-ZZZZ_yyyy-1234", "sk-proj-QQQQ9999wwww", `${home}/projects`,
            "hunter", "a b c", "sk-live-x1", "sk9999", "cs8888", "gt7777", "cookiesession123"]
    };
}

test("every secret kind is masked in the title and in the body", () => {
    const w = world();
    const { text, leaks } = secretWords(w.home);
    const run = triage(["--yes", text], w);
    assert.strictEqual(run.code, 0, run.err);
    const title = run.arg("--title");
    for (const leak of leaks) {
        assert.ok(!title.includes(leak), `title leaks ${leak}`);
        assert.ok(!run.body.includes(leak), `body leaks ${leak}`);
    }
    assert.match(title, /^triage: clone failed at https:\/\/\[removed\]@github\.com/);
    assert.ok(run.body.includes("https://[removed]@github.com/o/r.git"));
    assert.match(run.body, /Bearer \[removed\]/);
    assert.ok(run.body.includes("~/projects/x"));
    assert.ok(run.body.includes('"name": "kept"'));
});

test("the home folder is masked everywhere in the report, a home outside /home included, and look-alike paths stay", () => {
    const w = world();
    const run = triage(["--yes", `at ${w.home}/a and ${w.home}2/b and https://example.com/home/page`], w);
    assert.ok(!run.body.includes(`${w.home}/`));
    assert.ok(run.body.includes("at ~/a"));
    assert.ok(run.body.includes(`${w.home}2/b`));
    assert.ok(run.body.includes("https://example.com/home/page"));
});

test("doctor --report masks the home folder in every section, not only the log", () => {
    const stub = stubs();
    stubGh(stub);
    const home = directory("home");
    const run = cli(["doctor", "--report"], { stub, home, env: { GH_ARGS: "/dev/null", GH_BODY: "/dev/null" } });
    assert.strictEqual(run.code, 0, run.err);
    assert.ok(!run.out.includes(home));
    assert.match(run.out, /^version\s+\S/m);
});

test("a masked title is cut to 120 characters with three dots", () => {
    const w = world();
    const run = triage(["--yes", "the shell froze ".repeat(30)], w);
    const title = run.arg("--title");
    assert.strictEqual(title.length, 120);
    assert.ok(title.startsWith("triage: the shell froze"));
    assert.ok(title.endsWith("..."));
});

test("newlines in the words are flattened in the title and the empty case has a fallback title", () => {
    const w = world();
    const run = triage(["--yes", "first line\nsecond line"], w);
    assert.strictEqual(run.arg("--title"), "triage: first line second line");
    assert.ok(run.body.includes("first line\nsecond line"));
    const bare = triage(["--yes"], world());
    assert.strictEqual(bare.arg("--title"), "triage: a problem report");
});

test("context lines go under the words in the body and stay out of the title", () => {
    const run = triage(["--yes", "the bar went blank", "--context", "Went back in the update menu.\nSkipped: 2026-10-25 (2222222)", "--context", "Current: 2026-10-24"], world());
    assert.strictEqual(run.code, 0, run.err);
    assert.strictEqual(run.arg("--title"), "triage: the bar went blank");
    assert.ok(run.body.startsWith("## what happened\nthe bar went blank\n\nWent back in the update menu.\nSkipped: 2026-10-25 (2222222)\nCurrent: 2026-10-24\n"));
    const bare = triage(["--context", "Went back in the update menu.", "--yes"], world());
    assert.strictEqual(bare.arg("--title"), "triage: a problem report");
    assert.ok(bare.body.startsWith("## what happened\n(no words were given)\n\nWent back in the update menu.\n"));
});

test("context is masked like the words", () => {
    const w = world();
    const { text, leaks } = secretWords(w.home);
    const run = triage(["--yes", "words", "--context", text], w);
    for (const leak of leaks)
        assert.ok(!run.body.includes(leak), `body leaks ${leak}`);
});

test("after -- every argument is a word, flags included, and --context without a value is refused", () => {
    const run = triage(["--context", "ctx", "--", "--yes", "--context"], world());
    assert.strictEqual(run.create, undefined);
    assert.strictEqual(run.saved.length, 1);
    assert.ok(fs.readFileSync(run.saved[0], "utf8").startsWith("## what happened\n--yes --context\n\nctx\n"));
    const refused = triage(["--yes", "words", "--context"], world());
    assert.strictEqual(refused.code, 2);
    assert.match(refused.err, /--context needs a value/);
    assert.strictEqual(refused.create, undefined);
    assert.strictEqual(refused.saved.length, 0);
});

test("a report over the size cut is cut, still sent, and still ends with the cc line", () => {
    const w = world();
    const run = triage(["--yes", "word ".repeat(14000)], w);
    assert.strictEqual(run.code, 0, run.err);
    assert.ok(run.out.includes(`sent: ${ISSUE_URL}`));
    assert.ok(run.body.length < 61000);
    assert.match(run.body, /the report was cut here/);
    assert.match(run.body, /\ncc @fake\n$/);
});

test("ansi colour codes in the log are stripped", () => {
    const w = world();
    fs.writeFileSync(path.join(w.stub.dir, "qs"), "#!/bin/sh\ncase \"$*\" in *' log') printf '\\033[31mred line\\033[0m\\n' ;; esac\n", { mode: 0o755 });
    const run = triage(["--yes", "colours"], w);
    assert.ok(run.body.includes("red line"));
    assert.ok(!run.body.includes("\x1b"));
});

test("without --yes and without a terminal nothing is sent, the report is saved and the way to send it is printed", () => {
    const w = world();
    const run = triage(["the music app froze"], w);
    assert.notStrictEqual(run.code, 0);
    assert.strictEqual(run.create, undefined);
    assert.strictEqual(run.saved.length, 1);
    assert.match(run.out, /no terminal to ask on, so nothing was sent/);
    assert.match(run.out, /not sent\. the report is saved at .*\.md/);
    assert.match(run.out, /send it with: gh issue create --repo fake\/repo --title .* --body-file \//);
    assert.ok(fs.readFileSync(run.saved[0], "utf8").includes("the music app froze"));
});

test("--yes sends to the repo with the title, the words, the report sections and a cc to the owner, the body on stdin", () => {
    const w = world();
    const run = triage(["--yes", "the music app froze"], w);
    assert.strictEqual(run.code, 0, run.err);
    assert.strictEqual(run.arg("--repo"), "fake/repo");
    assert.strictEqual(run.arg("--title"), "triage: the music app froze");
    assert.strictEqual(run.arg("--body-file"), "-");
    assert.ok(run.body.startsWith("## what happened\nthe music app froze\n"));
    for (const head of ["## version", "## config", "## log (last 40 lines)", "## checks"])
        assert.ok(run.body.includes(head), head);
    assert.match(run.body, /\ncc @fake\n$/);
    assert.ok(run.out.includes(`sent: ${ISSUE_URL}`));
    assert.strictEqual(run.saved.length, 0);
});

test("the login check asks about github.com only", () => {
    const w = world();
    const run = triage(["--yes", "words"], w);
    assert.deepStrictEqual(run.calls[0], ["auth", "status", "--hostname", "github.com"]);
});

test("a gh that fails to create saves the report with mode 600 and prints the command", () => {
    const w = world({ GH_EXIT: "1" });
    const run = triage(["--yes", "the bar vanished"], w);
    assert.notStrictEqual(run.code, 0);
    assert.strictEqual(run.saved.length, 1);
    assert.strictEqual(fs.statSync(run.saved[0]).mode & 0o777, 0o600);
    assert.ok(fs.readFileSync(run.saved[0], "utf8").includes("the bar vanished"));
    assert.ok(run.out.includes(run.saved[0]));
    assert.match(run.out, /gh could not create the issue/);
    assert.match(run.out, /send it with: gh issue create --repo fake\/repo --title /);
    assert.ok(!run.out.includes("issues"));
});

test("a gh that times out may have created the issue, so the person is pointed at the issue list", () => {
    for (const extra of [{ GH_EXIT: "124" }, { GH_QUIET: "1" }]) {
        const run = triage(["--yes", "slow network"], world(extra));
        assert.notStrictEqual(run.code, 0);
        assert.match(run.out, /the issue may already exist; look at https:\/\/github\.com\/fake\/repo\/issues before sending this again/);
        assert.strictEqual(run.saved.length, 1);
    }
});

test("a gh that is not logged in saves the report and creates nothing", () => {
    const w = world({ GH_AUTH: "1" });
    const run = triage(["--yes", "words"], w);
    assert.notStrictEqual(run.code, 0);
    assert.strictEqual(run.create, undefined);
    assert.strictEqual(run.saved.length, 1);
    assert.match(run.out, /gh is not logged in to github\.com/);
});

function remoteStub(w, answers) {
    const cases = Object.entries(answers).map(([name, url]) => `${name}) echo '${url}' ;;`).join("\n");
    fs.writeFileSync(path.join(w.stub.dir, "git"), `#!/bin/sh
case "$5" in
${cases}
*) exit 2 ;;
esac
`, { mode: 0o755 });
}

test("the repo comes from origin when the environment names none, in each remote form", () => {
    for (const [remote, repo] of [
        ["git@github.com:own/proj.git", "own/proj"],
        ["ssh://git@github.com/own/proj.git", "own/proj"],
        ["https://github.com/own/proj.git", "own/proj"],
        ["https://github.com/own/proj", "own/proj"],
        ["https://github.com/own/proj.git/", "own/proj"],
        ["https://github.com/own/proj/", "own/proj"]
    ]) {
        const w = world({ BANDITSHELL_TRIAGE_REPO: "" });
        remoteStub(w, { origin: remote });
        const run = triage(["--yes", "words"], w);
        assert.strictEqual(run.arg("--repo"), repo, remote);
        assert.match(run.body, /\ncc @own\n$/, remote);
    }
});

test("the remote named by updates.remote wins over origin", () => {
    const w = world({ BANDITSHELL_TRIAGE_REPO: "" });
    const config = path.join(w.home, ".config/banditshell");
    fs.mkdirSync(config, { recursive: true });
    fs.writeFileSync(path.join(config, "config.json"), JSON.stringify({ updates: { remote: "upstream" } }));
    remoteStub(w, { origin: "git@github.com:fork/proj.git", upstream: "git@github.com:maintainer/proj.git" });
    const run = triage(["--yes", "words"], w);
    assert.strictEqual(run.arg("--repo"), "maintainer/proj");
    assert.match(run.body, /\ncc @maintainer\n$/);
});

test("no github remote saves the report, says so, and prints a command that pastes cleanly", () => {
    const w = world({ BANDITSHELL_TRIAGE_REPO: "" });
    const run = triage(["--yes", "words"], w);
    assert.notStrictEqual(run.code, 0);
    assert.strictEqual(run.create, undefined);
    assert.strictEqual(run.saved.length, 1);
    assert.match(run.out, /no github remote, and BANDITSHELL_TRIAGE_REPO is not set/);
    assert.match(run.out, /send it with: gh issue create --repo OWNER\/REPO --title /);
    assert.ok(!run.out.includes("<"));
});

test("a malformed BANDITSHELL_TRIAGE_REPO is called malformed, not unset", () => {
    const run = triage(["--yes", "words"], world({ BANDITSHELL_TRIAGE_REPO: "https://github.com/own/proj" }));
    assert.notStrictEqual(run.code, 0);
    assert.match(run.out, /BANDITSHELL_TRIAGE_REPO is not in owner\/repo form: https:\/\/github\.com\/own\/proj/);
    assert.ok(!/is not set/.test(run.out));
    assert.strictEqual(run.saved.length, 1);
});

test("the saved file and the printed command are quoted for the shell", () => {
    const home = directory("home with space");
    const w = world();
    const run = triage(["no terminal here"], { ...w, home });
    const file = run.saved[0];
    assert.ok(file.includes(" "));
    assert.ok(run.out.includes(`--body-file ${file.replace(/ /g, "\\ ")}`));
});

function onTerminal(w, answer, words = "the lock screen is blank") {
    if (spawnSync("sh", ["-c", "command -v script"]).status !== 0)
        return null;
    const result = spawnSync("script", ["-qec", `bash ${CLI} triage ${words}`, "/dev/null"], {
        cwd: ROOT,
        input: answer,
        encoding: "utf8",
        env: {
            PATH: `${w.stub.dir}:/usr/bin:/bin`,
            HOME: w.home,
            LANG: "C.UTF-8",
            XDG_RUNTIME_DIR: path.join(w.home, "run"),
            STUB_LOG: w.stub.log,
            NO_COLOR: "1",
            TERM: "dumb",
            ...w.env
        }
    });
    return result.stdout.replace(/\r/g, "");
}

test("on a terminal the report is shown, the question is asked, and only y sends", t => {
    const asked = world();
    const text = onTerminal(asked, "y\n");
    if (text === null)
        return t.skip("script(1) is not available");
    assert.match(text, /title: triage: the lock screen is blank/);
    assert.match(text, /## what happened\nthe lock screen is blank/);
    assert.match(text, /send this to github\.com\/fake\/repo\? \[y\/N\] /);
    assert.ok(fs.readFileSync(asked.env.GH_ARGS, "utf8").includes("issue\ncreate"));
    assert.ok(text.includes(`sent: ${ISSUE_URL}`));

    for (const answer of ["\n", "n\n", "maybe\n"]) {
        const declined = world();
        const out = onTerminal(declined, answer);
        assert.match(out, /not sent/);
        assert.ok(!fs.existsSync(declined.env.GH_BODY), JSON.stringify(answer));
    }
});

test("a pager that is not installed falls back to printing the report before asking", t => {
    const w = world({ PAGER: "no-such-pager-anywhere" });
    const text = onTerminal(w, "n\n");
    if (text === null)
        return t.skip("script(1) is not available");
    const shown = text.indexOf("## what happened");
    const asked = text.indexOf("send this to github.com/fake/repo?");
    assert.ok(shown >= 0 && asked > shown);
});

test("triage is in the help header", () => {
    const run = cli(["help", "triage"]);
    assert.strictEqual(run.code, 0);
    assert.match(run.out, /banditshell triage \[<words>\] \[--context <text>\] \[--yes\]/);
});
