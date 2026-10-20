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

test("the top level offers every command and none of the retired ones", () => {
    const offered = bashComplete("");
    assert.deepStrictEqual(offered, tableVerbs);
    for (const gone of ["toggle", "open", "set", "get", "list", "dispatch", "panic", "files", "try", "back", "shot", "demo", "lockpreview"])
        assert.ok(!offered.includes(gone), gone);
});

test("after a panel's name, its own actions sit beside the shared ones", () => {
    assert.deepStrictEqual(bashComplete("panel", "launcher", ""), ["close", "open", "run", "status", "toggle"]);
    assert.deepStrictEqual(bashComplete("panel", "keyboard", ""), ["close", "dock", "float", "open", "page", "status", "toggle"]);
    assert.deepStrictEqual(bashComplete("panel", "media", ""), ["close", "open", "status", "toggle"]);
});

test("a command that ends here is not also read as a placeholder", () => {
    assert.deepStrictEqual(bashComplete("panel", "close", ""), []);
    assert.deepStrictEqual(bashComplete("doctor", ""), ["--json", "--report", "api", "binds"]);
    assert.deepStrictEqual(bashComplete("doctor", "binds", ""), ["rewrite"]);
});

test("action, api and version complete: ids after action, the three api words, --json", () => {
    const ids = table.find(r => r[0] === "values" && r[1] === "id")[2].split(" ").sort();
    assert.ok(ids.includes("launcher.toggle") && ids.includes("panel.clipboard.toggle") && ids.includes("panel.close"));
    assert.ok(!ids.some(id => id.includes("*")));
    assert.deepStrictEqual(bashComplete("action", ""), ids);
    assert.deepStrictEqual(bashComplete("action", "launcher.toggle", ""), []);
    assert.deepStrictEqual(bashComplete("api", ""), ["check", "list", "show"]);
    assert.deepStrictEqual(bashComplete("api", "show", ""), ids);
    assert.deepStrictEqual(bashComplete("api", "list", "x", ""), ["--json"]);
    assert.deepStrictEqual(bashComplete("version", ""), ["--json"]);
    assert.deepStrictEqual(bashComplete("status", ""), ["--json"]);
    assert.ok(bashComplete("", ).includes("action") && bashComplete("", ).includes("api") && bashComplete("", ).includes("version"));
});

test("the offered ids are the table's, wildcard rows spelled out once per panel", () => {
    const rows = fs.readFileSync(path.join(ROOT, "api/actions.tsv"), "utf8").split("\n").filter(l => l && !l.startsWith("#")).map(l => l.split("\t")[0]);
    const ids = table.find(r => r[0] === "values" && r[1] === "id")[2].split(" ");
    const panels = table.find(r => r[0] === "values" && r[1] === "panel")[2].split(" ");
    for (const id of rows.filter(r => !r.includes("*")))
        assert.ok(ids.includes(id), id);
    for (const panel of panels)
        assert.ok(ids.includes(`panel.${panel}.toggle`), panel);
});

test("cli/commands.tsv is exactly what the parser prints now", () => {
    const committed = fs.readFileSync(path.join(ROOT, "cli/commands.tsv"), "utf8");
    assert.strictEqual(committed, run("bash", ["scripts/completion-rules.sh"]), "run: scripts/completion-rules.sh --write");
});

test("help offers the commands", () => {
    assert.deepStrictEqual(bashComplete("help", ""), tableVerbs);
});

test("a literal beats a wildcard at the same position", () => {
    const pages = table.find(r => r[0] === "values" && r[1] === "page")[2].split(" ").sort();
    assert.deepStrictEqual(bashComplete("panel", "settings", "open", ""), pages);
});

test("each group offers its parts, and each part its actions", () => {
    assert.deepStrictEqual(bashComplete("screen", ""), ["border", "brightness", "sidebar", "stream", "temperature"]);
    assert.deepStrictEqual(bashComplete("screen", "border", ""), ["off", "on", "toggle"]);
    assert.deepStrictEqual(bashComplete("output", ""), ["assign", "headphones", "list", "speakers", "toggle"]);
    assert.deepStrictEqual(bashComplete("clock", ""), ["alarm", "timer", "zone"]);
    assert.deepStrictEqual(bashComplete("island", ""), ["end", "list", "push", "update"]);
    assert.deepStrictEqual(bashComplete("island", "end", "build", ""), ["cancelled", "done", "failed"]);
    assert.deepStrictEqual(bashComplete("clock", "timer", ""), ["cancel", "pause", "resume", "start", "toggle"]);
    assert.deepStrictEqual(bashComplete("tablet", ""), ["lid", "off", "on", "pen", "probe", "toggle"]);
    assert.deepStrictEqual(bashComplete("tablet", "lid", ""), ["closed", "open", "toggle"]);
    assert.deepStrictEqual(bashComplete("dev", "preview", ""), ["files", "gallery", "lock", "menu", "settings"]);
    assert.deepStrictEqual(bashComplete("dev", "check", ""), ["boot", "island"]);
    assert.deepStrictEqual(bashComplete("dev", "check", "boot", "out", ""), ["--shots"]);
    assert.deepStrictEqual(bashComplete("dev", "inspect", ""), ["close", "island"]);
    assert.deepStrictEqual(bashComplete("dev", "keyring", ""), ["close", "demo", "status"]);
});

test("dev modules offers its flags, then the packages after --explain", () => {
    const packages = table.find(r => r[0] === "values" && r[1] === "package")[2].split(" ").sort();
    assert.ok(packages.includes("core") && packages.includes("launcher"));
    assert.deepStrictEqual(bashComplete("dev", "modules", ""), ["--explain", "--graph", "--matrix"]);
    assert.deepStrictEqual(bashComplete("dev", "modules", "--explain", ""), packages);
    assert.deepStrictEqual(bashComplete("dev", "modules", "--explain", "launcher-"), packages.filter(p => p.startsWith("launcher-")));
});

test("events offers its filter flag", () => {
    assert.deepStrictEqual(bashComplete("events", ""), ["--filter"]);
});

test("update offers its verbs, and each verb its flags", () => {
    assert.deepStrictEqual(bashComplete("update", ""), ["apply", "check", "rollback", "status"]);
    assert.deepStrictEqual(bashComplete("update", "check", ""), ["--json", "--no-fetch"]);
    assert.deepStrictEqual(bashComplete("update", "apply", ""), ["--detach", "--json", "--to"]);
    assert.deepStrictEqual(bashComplete("update", "status", ""), ["--json"]);
    assert.deepStrictEqual(bashComplete("update", "rollback", ""), []);
});

test("dev lint offers its flags, then the rule ids after --rule", () => {
    const ids = table.find(r => r[0] === "values" && r[1] === "rule")[2].split(" ").sort();
    assert.deepStrictEqual(ids, ["L1", "L10", "L11", "L12", "L13", "L14", "L2", "L3", "L4", "L5", "L6", "L7", "L8", "L9"]);
    assert.deepStrictEqual(bashComplete("dev", "lint", ""), ["--all", "--rule", "--write-baseline"]);
    assert.deepStrictEqual(bashComplete("dev", "lint", "--rule", ""), ids);
    assert.deepStrictEqual(bashComplete("dev", "lint", "--rule", "L1"), ["L1", "L10", "L11", "L12", "L13", "L14"]);
});

test("dev promote offers its two flags and no push", () => {
    assert.deepStrictEqual(bashComplete("dev", "promote", ""), ["--no-fetch", "--remote"]);
    assert.ok(bashComplete("dev", "").includes("promote"));
});

test("flags complete after the words they belong to", () => {
    assert.deepStrictEqual(bashComplete("clock", "alarm", "add", "7:00", ""), ["--ask", "--days", "--label", "--run"]);
    assert.deepStrictEqual(bashComplete("screenshot", "copy", ""), ["--freeze"]);
    assert.deepStrictEqual(bashComplete("island", "push", ""), ["--detail", "--icon", "--id", "--priority", "--progress", "--run", "--text", "--until"]);
    assert.deepStrictEqual(bashComplete("island", "update", "build", ""), ["--detail", "--icon", "--progress", "--text", "--until"]);
});

test("config offers the theme and the config keys", () => {
    fs.mkdirSync(path.join(HOME, ".config/banditshell"), { recursive: true });
    fs.writeFileSync(path.join(HOME, ".config/banditshell/config.json"), JSON.stringify({ edge: { bare: true }, theme: "slate" }));
    assert.deepStrictEqual(bashComplete("config", ""), ["get", "set", "theme"]);
    assert.ok(bashComplete("config", "theme", "").includes("list"));
    let jq = true;
    try {
        run("jq", ["--version"]);
    } catch {
        jq = false;
    }
    if (jq)
        assert.ok(bashComplete("config", "get", "").includes("edge.bare"));
});

test("panels include quickcontrols, files and wallpaper, once each", () => {
    const offered = bashComplete("panel", "");
    for (const panel of ["quickcontrols", "files", "wallpaper", "close"])
        assert.strictEqual(offered.filter(p => p === panel).length, 1, panel);
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
    assert.deepStrictEqual(complete("screen", "border", ""), ["off", "on", "toggle"]);
    assert.deepStrictEqual(complete("clock", "timer", ""), ["cancel", "pause", "resume", "start", "toggle"]);
    assert.deepStrictEqual(complete("panel", "launcher", ""), ["close", "open", "run", "status", "toggle"]);
    assert.deepStrictEqual(complete("panel", "close", ""), []);
    assert.deepStrictEqual(complete("dev", "modules", ""), ["--explain", "--graph", "--matrix"]);
    assert.ok(complete("dev", "modules", "--explain", "").includes("compositor"));
    assert.ok(complete("action", "").includes("launcher.toggle"));
    assert.deepStrictEqual(complete("api", ""), ["check", "list", "show"]);
    assert.deepStrictEqual(complete("version", ""), ["--json"]);
    assert.deepStrictEqual(complete("dev", "lint", ""), ["--all", "--rule", "--write-baseline"]);
    assert.deepStrictEqual(complete("dev", "lint", "--rule", ""), ["L1", "L10", "L11", "L12", "L13", "L14", "L2", "L3", "L4", "L5", "L6", "L7", "L8", "L9"]);
    assert.deepStrictEqual(complete("", ).sort(), tableVerbs);
});

test("a shell left open takes up the file another shell rebuilt", () => {
    const dir = fs.mkdtempSync(path.join(HOME, "rebuilt-"));
    const env = { ...ENV, BASH_COMPLETION_USER_DIR: dir };
    const build = () => execFileSync("bash", ["scripts/bash-completion.sh", "print"], { cwd: ROOT, env, encoding: "utf8" });
    const file = path.join(dir, "completions/banditshell");
    fs.mkdirSync(path.dirname(file));
    fs.writeFileSync(file, build());
    const rebuilt = build().replace(/^_bs_verbs=\(/m, "$&zz-rebuilt ");
    const script = `source "$1"; COMP_WORDS=(banditshell zz); COMP_CWORD=1
_banditshell; printf '%s\\n' "\${COMPREPLY[@]}" ==
printf '%s' "$2" >"$1"
_banditshell; printf '%s\\n' "\${COMPREPLY[@]}" ==
_bs_moved && echo moved || echo settled`;
    const [before, after, state] = execFileSync("bash", ["--norc", "--noprofile", "-c", script, "_", file, rebuilt], { cwd: ROOT, env, encoding: "utf8" }).split("==\n");
    assert.ok(!before.includes("zz-rebuilt"));
    assert.ok(after.includes("zz-rebuilt"));
    assert.strictEqual(state, "settled\n");
});

test("a zsh left open takes up the file another zsh rebuilt", { skip: !hasZsh() && "no zsh" }, () => {
    const dir = fs.mkdtempSync(path.join(HOME, "zsh-rebuilt-"));
    const env = { ...ENV, BANDITSHELL_ZSH_COMPDIR: dir };
    const build = () => execFileSync("bash", ["scripts/zsh-completion.sh", "print"], { cwd: ROOT, env, encoding: "utf8" });
    fs.writeFileSync(path.join(dir, "_banditshell"), build());
    const rebuilt = build().replace(/^_bs_verbs=\($/m, "$&\n    'zz-rebuilt:rebuilt'");
    const script = `
compadd() { [[ $1 == -a ]] && print -rl -- \${(P)2} }
_describe() { local -a v; v=( "\${(@P)\${@[-1]}}" ); print -rl -- \${v%%:*} }
compdef() { : }
fpath=("$1" $fpath)
autoload -Uz _banditshell
words=(banditshell zz)
CURRENT=2
_banditshell; print -r -- '=='
print -rn -- "$2" >"$1/_banditshell"
_banditshell; print -r -- '=='
_bs_moved && print moved || print settled`;
    const [before, after, state] = execFileSync("zsh", ["-fc", script, "_", dir, rebuilt], { cwd: ROOT, env, encoding: "utf8" }).split("==\n");
    assert.ok(!before.includes("zz-rebuilt"));
    assert.ok(after.includes("zz-rebuilt"));
    assert.strictEqual(state, "settled\n");
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
