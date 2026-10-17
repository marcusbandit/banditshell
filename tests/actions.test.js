const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { ROOT, TMP, cleanup, directory, stubs, cli } = require("./fixtures/cli-stubs.js");

const TABLE = path.join(ROOT, "api/actions.tsv");
const RELEASED = path.join(ROOT, "api/released.txt");
test.after(cleanup);

const LUA_KEYWORDS = new Set(["and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while"]);
const RESERVED = new Set(["api", "action", "bind", "describe", "has", "need", "cli", "root", "run"]);
const STATUS = /^(stable|deprecated=[a-z0-9_.]+|removed=[a-z0-9_.]+)$/;

function parse(text) {
    const lines = text.split("\n").filter(l => l !== "");
    const header = /^# api (\d+)$/.exec(lines[0]);
    const rows = lines.filter(l => !l.startsWith("#")).map(l => {
        const [id, status, since, argv, description, ...extra] = l.split("\t");
        return { id, status, since, argv, description, extra, columns: l.split("\t").length };
    });
    return { api: header ? Number(header[1]) : null, rows };
}

const table = parse(fs.readFileSync(TABLE, "utf8"));
const rules = execFileSync("bash", [path.join(ROOT, "scripts/completion-rules.sh")], { encoding: "utf8" })
    .split("\n").filter(l => l.startsWith("rule\t")).map(l => l.split("\t")[1]);

function stars(id) {
    return id.split(".").filter(s => s === "*").length;
}

function unify(a, b) {
    const x = a.split("."), y = b.split(".");
    return x.length === y.length && x.every((s, i) => s === y[i] || s === "*" || y[i] === "*");
}

function reachable(argv) {
    const words = argv.replace(/\$[1-9]/g, "x").split(" ");
    return rules.some(rule => {
        const parts = rule.split(" ");
        const flags = parts.length > 1 && parts[parts.length - 1].startsWith("--") ? parts.pop().split(",") : [];
        let position = 0;
        for (const word of words) {
            if (word.startsWith("--")) {
                if (!flags.includes(word))
                    return false;
                continue;
            }
            if (position >= parts.length)
                return false;
            const alternatives = parts[position++].split(",");
            if (!alternatives.some(a => a === word || a === "*" || a.startsWith("@")))
                return false;
        }
        return true;
    });
}

test("the table has a version line, five columns on every row, and rows", () => {
    assert.ok(table.api >= 1);
    assert.ok(table.rows.length > 50);
    for (const row of table.rows) {
        assert.strictEqual(row.columns, 5, row.id);
        assert.ok(row.argv && row.description, row.id);
    }
});

test("ids are lowercase segments, a star is a whole segment and never the first", () => {
    for (const { id } of table.rows) {
        const segments = id.split(".");
        assert.ok(segments.length >= 2, `${id} needs a group and an action`);
        for (const [i, segment] of segments.entries()) {
            assert.match(segment, /^([a-z0-9_]+|\*)$/, id);
            if (segment !== "*")
                assert.ok(!LUA_KEYWORDS.has(segment), `${id}: ${segment} is a Lua keyword`);
            if (i === 0)
                assert.notStrictEqual(segment, "*", id);
        }
        assert.ok(!RESERVED.has(segments[0]), `${id} starts with a name the Lua module owns`);
    }
});

test("no id is the front of another, so a name is a function or a group, never both", () => {
    const ids = table.rows.map(r => r.id);
    for (const a of ids)
        for (const b of ids)
            if (a !== b)
                assert.ok(!b.startsWith(a + "."), `${a} is the front of ${b}`);
});

test("ids are unique and every status is stable, deprecated=<id> or removed=<id>", () => {
    const ids = table.rows.map(r => r.id);
    assert.strictEqual(new Set(ids).size, ids.length);
    for (const row of table.rows) {
        assert.match(row.status, STATUS, row.id);
        assert.match(row.since, /^[1-9][0-9]*$/, row.id);
        assert.ok(Number(row.since) <= table.api, `${row.id} claims an api newer than the table`);
    }
});

test("a deprecated or removed id names a replacement that exists and is stable", () => {
    for (const row of table.rows) {
        const target = /^(?:deprecated|removed)=(.+)$/.exec(row.status);
        if (!target)
            continue;
        const hit = table.rows.find(r => r.id === target[1]) ?? table.rows.find(r => unify(r.id, target[1]));
        assert.ok(hit && hit.status === "stable", `${row.id} points at ${target[1]}`);
    }
});

test("wildcards: each star is captured as $1, $2 in order, and no capture is invented", () => {
    for (const row of table.rows) {
        const count = stars(row.id);
        const used = [...row.argv.matchAll(/\$([0-9])/g)].map(m => Number(m[1]));
        assert.deepStrictEqual([...new Set(used)].sort(), Array.from({ length: count }, (_, i) => i + 1), row.id);
        if (count > 1)
            assert.deepStrictEqual(used, [...used].sort(), `${row.id} captures out of order`);
    }
});

test("two wildcard rows with the same number of stars never match the same name", () => {
    const wild = table.rows.filter(r => r.id.includes("*"));
    for (const a of wild)
        for (const b of wild)
            if (a.id < b.id && stars(a.id) === stars(b.id))
                assert.ok(!unify(a.id, b.id), `${a.id} and ${b.id}`);
});

test("argv templates are plain words and descriptions carry no dash punctuation", () => {
    for (const row of table.rows) {
        assert.match(row.argv, /^[A-Za-z0-9_$+.-]+( [A-Za-z0-9_$+.-]+)*$/, row.id);
        assert.ok(!/[\u2013\u2014]/.test(row.description), row.id);
        assert.match(row.description, /^[A-Z]/, row.id);
    }
});

test("every id resolves to a command path that exists in the CLI's help header", () => {
    for (const row of table.rows)
        assert.ok(reachable(row.argv), `${row.id} -> banditshell ${row.argv}`);
});

test("the reachability check does turn down a command the header does not have", () => {
    assert.ok(reachable("panel launcher toggle"));
    assert.ok(reachable("screenshot copy --freeze"));
    assert.ok(!reachable("panel launcher explode"));
    assert.ok(!reachable("volume up"));
    assert.ok(!reachable("screenshot full --freeze"));
});

test("no id that was ever released has been removed from the table", () => {
    const released = fs.readFileSync(RELEASED, "utf8").split("\n").filter(Boolean);
    assert.deepStrictEqual(released, [...new Set(released)].sort(), "api/released.txt is sorted and has no repeats");
    const have = new Set(table.rows.map(r => r.id));
    const gone = released.filter(id => !have.has(id));
    assert.deepStrictEqual(gone, [], `ids are never deleted; turn a retired one into deprecated=<id> or removed=<id>: ${gone.join(", ")}`);
});

function handlers() {
    const snapshot = JSON.parse(fs.readFileSync(path.join(ROOT, "tests/fixtures/ipc-targets.json"), "utf8"));
    const found = {};
    for (const [target, fns] of Object.entries(snapshot))
        found[target] = new Set(fns.map(f => f.split("(")[0]));
    return found;
}

const CONCRETE = { "*": "launcher" };
const ARGUMENTS = { "clock.alarm.add": ["07:00"] };
const DRY_SAFE = new Set(["panel", "output", "screen", "wallpaper", "clock", "focus", "tablet", "config", "launcher", "screenshot", "notifications"]);

test("every id that reaches the shell calls an IPC function the shell really has", () => {
    const known = handlers();
    const bad = [];
    let checked = 0;
    for (const row of table.rows) {
        const first = row.argv.split(" ")[0];
        const skip = !DRY_SAFE.has(first) || /^screenshot full|^tablet probe/.test(row.argv);
        if (skip)
            continue;
        const id = row.id.split(".").map(s => CONCRETE[s] ?? s).join(".");
        const extra = ARGUMENTS[row.id] ?? (/\(arguments:/.test(row.description) ? ["x", "x", "x", "x"] : /\(argument:/.test(row.description) ? ["x"] : []);
        const run = cli(["action", id, ...extra], { env: { BANDITSHELL_DRY: "1" } });
        assert.strictEqual(run.code, 0, `${id}: ${run.err}`);
        assert.deepStrictEqual(run.calls, [], `${id} reached a real tool: ${run.calls.join("; ")}`);
        for (const line of run.out.split("\n").filter(l => l.startsWith("ipc "))) {
            const [, target, fn] = line.split(" ");
            checked++;
            if (!known[target]?.has(fn))
                bad.push(`${id} -> ${target} ${fn}`);
        }
    }
    assert.ok(checked > 80, `only ${checked} calls were checked`);
    assert.deepStrictEqual(bad, [], "ids whose IPC function no handler has (tests/fixtures/ipc-targets.json)");
});

test("action resolves the id when it runs and hands the arguments on", () => {
    const run = cli(["action", "panel.calendar.toggle", "DP-1"], { env: { BANDITSHELL_DRY: "1" } });
    assert.strictEqual(run.code, 0, run.err);
    assert.strictEqual(run.out.trim(), "ipc menu toggle calendar DP-1");
    const builtin = cli(["action", "panel.keyboard.toggle", "DP-1"], { env: { BANDITSHELL_DRY: "1" } });
    assert.strictEqual(builtin.out.trim(), "ipc keyboard toggle DP-1");
    const exact = cli(["action", "wallpaper.set", "/tmp/a b.png", "all"], { env: { BANDITSHELL_DRY: "1" } });
    assert.strictEqual(exact.out.trim(), "ipc wallpaper set /tmp/a b.png all");
});

test("an unknown, malformed or missing id is a usage error that touches nothing", () => {
    for (const args of [["action", "no.such.thing"], ["action", "../x"], ["action", "Panel.close"], ["action"]]) {
        const run = cli(args);
        assert.strictEqual(run.code, 2, args.join(" "));
        assert.ok(!run.calls.some(c => c.startsWith("qs ipc")), args.join(" "));
    }
});

function fixtureTable(...rows) {
    const file = path.join(directory("table"), "actions.tsv");
    fs.writeFileSync(file, ["# api 1", ...rows.map(r => r.join("\t"))].join("\n") + "\n");
    return file;
}

test("a deprecated id still runs and says so once per session", () => {
    const file = fixtureTable(
        ["launcher.show", "deprecated=launcher.toggle", "1", "panel launcher toggle", "Old name"],
        ["launcher.hide", "removed=launcher.close", "1", "panel launcher close", "Older name"]
    );
    const stub = stubs();
    const home = directory("home");
    const env = { BANDITSHELL_API_TABLE: file, BANDITSHELL_DRY: "1" };
    const first = cli(["action", "launcher.show"], { env, stub, home });
    assert.strictEqual(first.code, 0, first.err);
    assert.strictEqual(first.out.trim(), "ipc launcher toggle");
    assert.match(first.err, /launcher\.show is deprecated, use launcher\.toggle/);
    assert.deepStrictEqual(first.calls.filter(c => c.startsWith("hyprctl notify")).length, 1);
    const second = cli(["action", "launcher.show"], { env, stub, home });
    assert.strictEqual(second.out.trim(), "ipc launcher toggle");
    assert.strictEqual(second.err, "");
    assert.strictEqual(second.calls.filter(c => c.startsWith("hyprctl notify")).length, 1);
    const removed = cli(["action", "launcher.hide"], { env, stub, home });
    assert.strictEqual(removed.out.trim(), "ipc launcher close");
    assert.match(removed.err, /launcher\.hide is gone, it now runs launcher\.close/);
});

test("api list, show and check read the table", () => {
    const list = cli(["api", "list", "panel.*"]);
    assert.strictEqual(list.code, 0, list.err);
    assert.match(list.out, /^panel\.close\s+stable\s+Close every panel and menu$/m);
    assert.ok(list.out.split("\n").filter(Boolean).every(l => l.startsWith("panel.")));
    assert.strictEqual(cli(["api"]).out, cli(["api", "list"]).out);
    const json = JSON.parse(cli(["api", "list", "launcher.*", "--json"]).out);
    assert.deepStrictEqual(json.map(r => r.id), ["launcher.toggle", "launcher.open", "launcher.close", "launcher.run"]);
    assert.deepStrictEqual(Object.keys(json[0]), ["id", "status", "since", "argv", "description"]);
    const show = cli(["api", "show", "panel.media.toggle"]);
    assert.match(show.out, /^id\s+panel\.media\.toggle$/m);
    assert.match(show.out, /^pattern\s+panel\.\*\.toggle$/m);
    assert.match(show.out, /^runs\s+banditshell panel media toggle$/m);
    assert.strictEqual(cli(["api", "show", "nope.x"]).code, 2);
    assert.strictEqual(cli(["api", "list", "nope.*"]).code, 1);
    assert.strictEqual(cli(["api", "nonsense"]).code, 2);
    const check = cli(["api", "check"]);
    assert.strictEqual(check.code, 0, check.out + check.err);
    assert.match(check.out, /^ok\s+actions\s+\d+ ids, api \d+/);
});

test("api check names the row that points at a command the CLI does not have", () => {
    const file = fixtureTable(
        ["launcher.toggle", "stable", "1", "panel launcher toggle", "Fine"],
        ["settings.float", "stable", "1", "panel settings float", "Gone since the handler was removed"],
        ["Bad.Id", "maybe", "x", "panel launcher toggle", "Broken"]
    );
    const run = cli(["api", "check"], { env: { BANDITSHELL_API_TABLE: file } });
    assert.strictEqual(run.code, 1);
    assert.match(run.out, /fail\s+action\s+settings\.float: panel settings float is not a command this CLI has/);
    assert.match(run.out, /Bad\.Id: not a valid id/);
    assert.match(run.out, /Bad\.Id: bad status maybe/);
    assert.doesNotMatch(run.out, /launcher\.toggle:/);
});

test("version prints the release, commit, checkout and api, and as JSON", () => {
    const run = cli(["version"]);
    assert.strictEqual(run.code, 0, run.err);
    const newest = JSON.parse(fs.readFileSync(path.join(ROOT, "docs/whats-new.json"), "utf8")).entries[0].id;
    assert.match(run.out, new RegExp(`^version\\s+${newest}$`, "m"));
    assert.match(run.out, new RegExp(`^checkout\\s+${ROOT.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "m"));
    assert.match(run.out, new RegExp(`^api\\s+${table.api}$`, "m"));
    for (const label of ["commit", "branch", "quickshell", "hyprland"])
        assert.match(run.out, new RegExp(`^${label}\\s+\\S`, "m"));
    const json = JSON.parse(cli(["version", "--json"]).out);
    assert.strictEqual(json.version, newest);
    assert.strictEqual(json.api, table.api);
    assert.strictEqual(json.checkout, ROOT);
});

test("--json turns a status block into an object and leaves exit codes alone", () => {
    const stub = stubs();
    fs.writeFileSync(path.join(stub.dir, "qs"), '#!/bin/sh\ncase "$1" in\nlist) ;;\nipc) printf "compositor  Hyprland\\nrounding    12\\nopen=true count=3 name=\\"a b\\"\\nloose words\\n" ;;\nesac\n', { mode: 0o755 });
    const run = cli(["status", "--json"], { stub });
    assert.strictEqual(run.code, 0, run.err);
    assert.deepStrictEqual(JSON.parse(run.out), { compositor: "Hyprland", rounding: 12, open: true, count: 3, name: "a b", text: ["loose words"] });
});

test("the legacy .conf example calls only ids that exist, and no raw banditshell command line", () => {
    const text = fs.readFileSync(path.join(ROOT, "docs/hyprland-binds.example.conf"), "utf8");
    const binds = text.split("\n").filter(l => /^bind[a-z]* = /.test(l) && l.includes("banditshell"));
    assert.ok(binds.length > 20);
    const patterns = table.rows.map(r => r.id.split("."));
    for (const line of binds) {
        const id = /exec, banditshell action ([a-z0-9_.]+)/.exec(line);
        assert.ok(id, line);
        const parts = id[1].split(".");
        assert.ok(patterns.some(p => p.length === parts.length && p.every((s, i) => s === "*" || s === parts[i])), line);
    }
});
