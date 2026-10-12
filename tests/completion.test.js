const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const CLI = path.join(ROOT, "cli/banditshell");
const HOME = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-completion-"));
const ENV = { PATH: "/usr/bin:/bin", HOME, LANG: "C.UTF-8" };

test.after(() => fs.rmSync(HOME, { recursive: true, force: true }));

function run(command, args, input) {
    return execFileSync(command, args, { cwd: ROOT, env: ENV, input, encoding: "utf8" });
}

function hasZsh() {
    try {
        run("zsh", ["-fc", "true"]);
        return true;
    } catch {
        return false;
    }
}

const table = run("bash", ["scripts/completion-rules.sh"]).trim().split("\n").map(line => line.split("\t"));
const zsh = run("bash", ["scripts/zsh-completion.sh", "print"]);
const bash = run("bash", ["scripts/bash-completion.sh", "print"]);
const bashFile = path.join(HOME, "banditshell.bash");
fs.writeFileSync(bashFile, bash);

function cliVerbs() {
    const lines = fs.readFileSync(CLI, "utf8").split("\n");
    const start = lines.indexOf('case "$cmd" in');
    assert.ok(start > 0, "the CLI's top-level case statement");
    const verbs = [];
    for (const line of lines.slice(start + 1)) {
        if (line === "esac")
            break;
        const arm = /^([a-z][a-z |-]*)\)$/.exec(line);
        if (arm)
            verbs.push(...arm[1].split("|").map(v => v.trim()).filter(v => /^[a-z]/.test(v)));
    }
    return verbs.sort();
}

function arrayIn(text, name) {
    const match = new RegExp(`^${name}=\\(([\\s\\S]*?)\\)$`, "m").exec(text);
    assert.ok(match, `${name} in the generated file`);
    return [...match[1].matchAll(/'((?:[^']|'\\'')*)'|(\S+)/g)].map(m => m[1] ?? m[2]);
}

function bashComplete(...words) {
    const script = `source "$1"; shift; COMP_WORDS=(banditshell "$@"); COMP_CWORD=$#; _banditshell; printf '%s\\n' "\${COMPREPLY[@]}"`;
    return run("bash", ["--norc", "--noprofile", "-c", script, "_", bashFile, ...words]).split("\n").filter(Boolean).sort();
}

const tableVerbs = table.filter(r => r[0] === "verb").map(r => r[1]).sort();
const tableRules = table.filter(r => r[0] === "rule").map(r => r[1]);

test("the completion offers exactly the CLI's verbs", () => {
    assert.deepStrictEqual(tableVerbs, cliVerbs());
    assert.deepStrictEqual(arrayIn(zsh, "_bs_verbs").map(v => v.split(":")[0]).sort(), tableVerbs);
    assert.deepStrictEqual(arrayIn(bash, "_bs_verbs").sort(), tableVerbs);
});

test("zsh and bash carry the same rule table", () => {
    assert.deepStrictEqual(arrayIn(zsh, "_bs_rules"), tableRules);
    assert.deepStrictEqual(arrayIn(bash, "_bs_rules"), tableRules);
});

test("the header's panel list is the CLI's SURFACES", () => {
    const surfaces = /^SURFACES=\(([^)]*)\)$/m.exec(fs.readFileSync(CLI, "utf8"))[1].split(/\s+/);
    const panel = table.find(r => r[0] === "values" && r[1] === "panel")[2].split(" ");
    assert.deepStrictEqual(panel, surfaces);
});

test("every value source a rule names is offered by both shells", () => {
    const sources = new Set(tableRules.flatMap(r => r.split(/[ ,]/)).filter(w => w.startsWith("@")).map(w => w.slice(1)));
    for (const source of sources) {
        assert.match(zsh, new RegExp(`^    ${source}\\)`, "m"), `zsh offers ${source}`);
        assert.match(bash, new RegExp(`^    ${source}\\)`, "m"), `bash offers ${source}`);
    }
});

test("verbs that share a header line stay separate verbs", () => {
    for (const verb of ["demo", "gallery", "settingspreview", "lockpreview", "filespreview", "shot"])
        assert.ok(tableVerbs.includes(verb), verb);
    assert.deepStrictEqual(bashComplete("shot", "demo"), []);
});

test("the top level offers every verb, including the ones the audit found missing", () => {
    const offered = bashComplete("");
    for (const verb of ["files", "panic", "help", "check", "demo", "gallery", "settingspreview"])
        assert.ok(offered.includes(verb), verb);
});

test("a sub-argument set never overwrites its sibling", () => {
    assert.deepStrictEqual(bashComplete("set", "volume", ""), ["mute"]);
    assert.deepStrictEqual(bashComplete("set", "volume", "mute", ""), ["off", "on"]);
    assert.deepStrictEqual(bashComplete("set", "tablet", ""), ["lid", "off", "on"]);
    assert.deepStrictEqual(bashComplete("set", "tablet", "lid", ""), ["closed", "open"]);
});

test("dispatch offers its targets and each target's actions", () => {
    assert.ok(bashComplete("dispatch", "").includes("notifications"));
    assert.deepStrictEqual(bashComplete("dispatch", "timer", ""), ["cancel", "pause", "resume", "start", "toggle"]);
    assert.deepStrictEqual(bashComplete("dispatch", "notifications", ""), ["clear"]);
    assert.deepStrictEqual(bashComplete("dispatch", "alarm", "add", "7:00", ""), ["--ask", "--days", "--label", "--run"]);
});

test("get offers the theme and the config keys", () => {
    fs.mkdirSync(path.join(HOME, ".config/banditshell"), { recursive: true });
    fs.writeFileSync(path.join(HOME, ".config/banditshell/config.json"), JSON.stringify({ edge: { bare: true }, theme: "slate" }));
    const offered = bashComplete("get", "");
    assert.ok(offered.includes("theme"));
    let jq = true;
    try {
        run("jq", ["--version"]);
    } catch {
        jq = false;
    }
    if (jq)
        assert.ok(offered.includes("edge.bare"));
});

test("panels include quickcontrols, files and penmap, once each", () => {
    const offered = bashComplete("toggle", "panel", "");
    for (const panel of ["quickcontrols", "files", "penmap", "wallpaper"])
        assert.strictEqual(offered.filter(p => p === panel).length, 1, panel);
});

test("a literal beats a wildcard at the same position", () => {
    const pages = table.find(r => r[0] === "values" && r[1] === "page")[2].split(" ").sort();
    assert.deepStrictEqual(bashComplete("open", "panel", "settings", ""), pages);
});

test("the zsh file parses and matches the same way", { skip: !hasZsh() && "no zsh" }, () => {
    const dir = fs.mkdtempSync(path.join(HOME, "zsh-"));
    fs.writeFileSync(path.join(dir, "_banditshell"), zsh);
    run("zsh", ["-n", path.join(dir, "_banditshell")]);
    const script = `
compadd() { [[ $1 == -a ]] && print -rl -- \${(P)2} }
_describe() { local -a v; v=( "\${(@P)\${@[-1]}}" ); print -rl -- \${v%%:*} }
_files() { print -r -- files }
compdef() { : }
fpath=("$1" $fpath)
autoload -Uz _banditshell
shift
words=(banditshell "$@")
CURRENT=$#words
_banditshell`;
    const complete = (...words) => run("zsh", ["-fc", script, "_", dir, ...words]).split("\n").filter(Boolean).sort();
    assert.deepStrictEqual(complete("set", "volume", "mute", ""), ["off", "on"]);
    assert.deepStrictEqual(complete("dispatch", "timer", ""), ["cancel", "pause", "resume", "start", "toggle"]);
    assert.deepStrictEqual(complete("", ).sort(), tableVerbs);
});

test("completions install, status and remove can take one shell", () => {
    const home = fs.mkdtempSync(path.join(HOME, "one-shell-"));
    const env = { ...ENV, HOME: home };
    const cli = (...args) => {
        try {
            execFileSync(CLI, ["completions", ...args], { cwd: ROOT, env, encoding: "utf8", stdio: "pipe" });
            return 0;
        } catch (error) {
            return error.status;
        }
    };
    assert.strictEqual(cli("status", "zsh", "--quiet"), 2);
    assert.strictEqual(cli("install", "bash", "--quiet"), 0);
    assert.strictEqual(cli("status", "bash", "--quiet"), 0);
    assert.strictEqual(cli("status", "zsh", "--quiet"), 2);
    assert.strictEqual(cli("status", "--quiet"), 2);
    assert.strictEqual(cli("install", "--quiet"), 0);
    assert.strictEqual(cli("status", "--quiet"), 0);
    assert.strictEqual(cli("remove", "zsh", "--quiet"), 0);
    assert.strictEqual(cli("status", "zsh", "--quiet"), 2);
    assert.strictEqual(cli("status", "bash", "--quiet"), 0);
    assert.deepStrictEqual(bashComplete("completions", "status", ""), ["bash", "zsh"]);
});
