const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { CLI, ROOT, cleanup, directory, stubs, cli } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

const ISSUE_URL = "https://github.com/fake/repo/issues/7";

function stubGh(stub) {
    const log = path.join(stub.dir, "gh-args.log");
    const body = path.join(stub.dir, "gh-body.md");
    fs.writeFileSync(path.join(stub.dir, "gh"), `#!/bin/sh
printf -- '--call\\n' >>"$GH_ARGS"
printf '%s\\n' "$@" >>"$GH_ARGS"
if [ "$1 $2" = "auth status" ]; then exit "\${GH_AUTH:-0}"; fi
if [ "$1 $2" = "issue create" ]; then
    while [ $# -gt 0 ]; do
        [ "$1" = --body-file ] && cp "$2" "$GH_BODY"
        shift
    done
    if [ -n "$GH_FAIL" ]; then echo "gh: HTTP 502" >&2; exit 1; fi
    echo ${ISSUE_URL}
fi
`, { mode: 0o755 });
    return { GH_ARGS: log, GH_BODY: body };
}

function world(extra = {}) {
    const stub = stubs();
    const env = { ...stubGh(stub), BANDITSHELL_TRIAGE_REPO: "fake/repo", PAGER: "cat", ...extra };
    const home = directory("home");
    const resolved = spawnSync("sh", ["-c", "command -v gh"], { env: { PATH: `${stub.dir}:/usr/bin:/bin` }, encoding: "utf8" }).stdout.trim();
    assert.strictEqual(resolved, path.join(stub.dir, "gh"), "the stub gh must come first on PATH");
    return { stub, env, home };
}

function triage(args, { stub, env, home }, options = {}) {
    const run = cli(["triage", ...args], { stub, env: { ...env, ...(options.env ?? {}) }, home });
    const argsLog = fs.existsSync(env.GH_ARGS) ? fs.readFileSync(env.GH_ARGS, "utf8") : "";
    const calls = argsLog.split("--call\n").filter(Boolean).map(c => c.split("\n").slice(0, -1));
    const create = calls.find(c => c[0] === "issue" && c[1] === "create");
    return {
        ...run,
        calls: calls,
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

const SECRET_WORDS = [
    "clone failed at https://marcus:s3cretpass@github.com/o/r.git",
    "Authorization: Bearer abc123def",
    "gh tokens ghp_AAAA1111 gho_BBBB2222 ghu_CCCC3333 ghs_DDDD4444 ghr_EEEE5555 github_pat_11ABC_xyz987",
    "key sk-ant-api03-ZZZZ_yyyy-1234",
    "path /home/someone/projects/x"
].join(" and ");

const LEAKS = ["s3cretpass", "abc123def", "ghp_AAAA1111", "gho_BBBB2222", "ghu_CCCC3333", "ghs_DDDD4444",
    "ghr_EEEE5555", "github_pat_11ABC_xyz987", "sk-ant-api03-ZZZZ_yyyy-1234", "/home/someone"];

test("every secret kind is masked in the title and in the body", () => {
    const w = world();
    const run = triage(["--yes", SECRET_WORDS], w);
    assert.strictEqual(run.code, 0, run.err);
    const title = run.arg("--title");
    for (const leak of LEAKS) {
        assert.ok(!title.includes(leak), `title leaks ${leak}`);
        assert.ok(!run.body.includes(leak), `body leaks ${leak}`);
    }
    assert.match(title, /^triage: clone failed at https:\/\/\[removed\]@github\.com/);
    assert.ok(run.body.includes("https://[removed]@github.com/o/r.git"));
    assert.match(run.body, /Bearer \[removed\]/);
    assert.ok(run.body.includes("~/projects/x"));
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
    assert.match(run.out, /send it with: gh issue create --repo fake\/repo --title .* --body-file /);
    assert.ok(fs.readFileSync(run.saved[0], "utf8").includes("the music app froze"));
});

test("--yes sends to the repo with the title, the words, the report sections and a cc to the owner", () => {
    const w = world();
    const run = triage(["--yes", "the music app froze"], w);
    assert.strictEqual(run.code, 0, run.err);
    assert.strictEqual(run.arg("--repo"), "fake/repo");
    assert.strictEqual(run.arg("--title"), "triage: the music app froze");
    assert.ok(run.body.startsWith("## what happened\nthe music app froze\n"));
    for (const head of ["## version", "## config", "## log (last 40 lines)", "## checks"])
        assert.ok(run.body.includes(head), head);
    assert.match(run.body, /\ncc @fake\n$/);
    assert.ok(run.out.includes(`sent: ${ISSUE_URL}`));
    assert.strictEqual(run.saved.length, 0);
});

test("a gh that fails to create saves the report with mode 600 and prints the command", () => {
    const w = world({ GH_FAIL: "1" });
    const run = triage(["--yes", "the bar vanished"], w);
    assert.notStrictEqual(run.code, 0);
    assert.strictEqual(run.saved.length, 1);
    assert.strictEqual(fs.statSync(run.saved[0]).mode & 0o777, 0o600);
    assert.ok(fs.readFileSync(run.saved[0], "utf8").includes("the bar vanished"));
    assert.ok(run.out.includes(run.saved[0]));
    assert.match(run.out, /send it with: gh issue create --repo fake\/repo --title /);
    assert.ok(!run.out.includes("issues/7"));
});

test("a gh that is not logged in saves the report and creates nothing", () => {
    const w = world({ GH_AUTH: "1" });
    const run = triage(["--yes", "words"], w);
    assert.notStrictEqual(run.code, 0);
    assert.strictEqual(run.create, undefined);
    assert.strictEqual(run.saved.length, 1);
    assert.match(run.out, /gh is not logged in/);
});

test("the repo comes from origin when the environment names none, in each remote form", () => {
    for (const [remote, repo] of [
        ["git@github.com:own/proj.git", "own/proj"],
        ["ssh://git@github.com/own/proj.git", "own/proj"],
        ["https://github.com/own/proj.git", "own/proj"],
        ["https://github.com/own/proj", "own/proj"]
    ]) {
        const w = world({ BANDITSHELL_TRIAGE_REPO: "" });
        fs.writeFileSync(path.join(w.stub.dir, "git"), `#!/bin/sh\necho '${remote}'\n`, { mode: 0o755 });
        const run = triage(["--yes", "words"], w);
        assert.strictEqual(run.arg("--repo"), repo, remote);
        assert.match(run.body, /\ncc @own\n$/, remote);
    }
});

test("no github remote saves the report and says so", () => {
    const w = world({ BANDITSHELL_TRIAGE_REPO: "" });
    const run = triage(["--yes", "words"], w);
    assert.notStrictEqual(run.code, 0);
    assert.strictEqual(run.create, undefined);
    assert.strictEqual(run.saved.length, 1);
    assert.match(run.out, /no github remote/);
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

test("triage is in the help header", () => {
    const run = cli(["help", "triage"]);
    assert.strictEqual(run.code, 0);
    assert.match(run.out, /banditshell triage \[--yes\] \[<words>\]/);
});
