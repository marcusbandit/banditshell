const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { cleanup, cli } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/pushed-rows.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Pushed = new Function(`${src}\nreturn { parseRow };`)();

const dry = (...args) => {
    const run = cli(args, { env: { BANDITSHELL_DRY: "1" } });
    assert.strictEqual(run.code, 0, `${args.join(" ")}: ${run.err}`);
    return run.out.trim();
};

const addedRow = (...args) => {
    const line = dry("launcher", "add", ...args);
    assert.match(line, /^ipc launcher add \{/);
    const read = Pushed.parseRow(line.slice("ipc launcher add ".length), 0);
    assert.ok(read.row, read.error);
    return read.row;
};

test("launcher add turns flags into a row the shell accepts", () => {
    const row = addedRow("deploy", "failed", "Deploy failed", "--subtitle", "main · 2 min", "--icon", "🚀", "--keywords", "ci  build", "--for", "10m", "--open", "https://ci.example.org/41");
    assert.deepStrictEqual([row.tool, row.id, row.title, row.subtitle, row.icon, row.keywords, row.expires, row.open], ["deploy", "failed", "Deploy failed", "main · 2 min", "🚀", ["ci", "build"], 600_000, "https://ci.example.org/41"]);
});

test("launcher add keeps quotes, backslashes and spaces in what it passes on", () => {
    const row = addedRow("notes", "quote", 'He said "hi" \\o/', "--copy", "line one\nline two");
    assert.strictEqual(row.title, 'He said "hi" \\o/');
    assert.strictEqual(row.copy, "line one\nline two");
});

test("launcher add takes the rest of the line after --run as the command, word by word", () => {
    const row = addedRow("deploy", "logs", "Deploy logs", "--for", "2h", "--run", "kitty", "-e", "journalctl", "-fu", "my unit");
    assert.deepStrictEqual(row.run, ["kitty", "-e", "journalctl", "-fu", "my unit"]);
    assert.strictEqual(row.expires, 7_200_000);
});

test("launcher add passes a row written as JSON through untouched", () => {
    assert.strictEqual(dry("launcher", "add", '{"tool":"a","id":"b","title":"c"}'), 'ipc launcher add {"tool":"a","id":"b","title":"c"}');
});

test("launcher remove and list name the tool and the row", () => {
    assert.strictEqual(dry("launcher", "remove", "deploy", "failed"), "ipc launcher remove deploy failed");
    assert.strictEqual(dry("launcher", "remove", "deploy"), "ipc launcher remove deploy");
    assert.strictEqual(dry("launcher", "list", "deploy"), "ipc launcher list deploy");
    assert.strictEqual(dry("launcher"), "ipc launcher list");
});

test("launcher add refuses a missing title, a bad duration and an unknown flag", () => {
    for (const args of [["add", "a", "b"], ["add", "a", "b", "c", "--for", "soon"], ["add", "a", "b", "c", "--colour", "red"], ["add", "a", "b", "c", "--run"], ["remove"]]) {
        const run = cli(["launcher", ...args], { env: { BANDITSHELL_DRY: "1" } });
        assert.strictEqual(run.code, 2, args.join(" "));
    }
});
