const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const SOURCES = path.join(ROOT, "modules/launcher/sources");
const SEARCH = fs.readFileSync(path.join(ROOT, "modules/launcher/LauncherSearch.qml"), "utf8");
const DOC = fs.readFileSync(path.join(ROOT, "docs/architecture/launcher-sources.md"), "utf8");

const ROWS = ["kinds", "groups", "activate", "actionsFor"];
const OPTIONAL = ["intent", "alone", "caps", "commands", "prefixes", "phrases", "rowById", "complete", "confirmActionsFor", "listsWifi"];
const FUNCTIONS = ["activate", "actionsFor", "rowById", "complete", "confirmActionsFor"];
const CONTRACT = ["search"].concat(ROWS, OPTIONAL);

function members(text) {
    const out = {};
    for (const m of text.matchAll(/^    (?:required |readonly )*property [\w<>]+ (\w+)/gm))
        out[m[1]] = "property";
    for (const m of text.matchAll(/^    function (\w+)\(/gm))
        out[m[1]] = "function";
    return out;
}

function sourceFiles() {
    return fs.readdirSync(SOURCES).filter(f => f.endsWith("Source.qml")).map(f => ({
        name: f.slice(0, -4),
        text: fs.readFileSync(path.join(SOURCES, f), "utf8")
    }));
}

function builtIn() {
    const list = /readonly property list<QtObject> builtIn: \[\n([\s\S]*?)\n    \]/.exec(SEARCH);
    assert.ok(list, "LauncherSearch.builtIn is a literal list");
    return [...list[1].matchAll(/^        (\w+) \{$/gm)].map(m => m[1]);
}

function kindsOf(text) {
    const m = /readonly property var kinds: \[([^\]]*)\]/.exec(text);
    return m ? [...m[1].matchAll(/"([^"]+)"/g)].map(k => k[1]) : null;
}

test.describe("launcher source contract", () => {
    test.it("lists every built-in source that has a file, and nothing else", () => {
        const files = sourceFiles().map(f => f.name).sort();
        assert.deepStrictEqual(builtIn().slice().sort(), files);
    });

    test.it("gives every source search, and a source with rows all four row members", () => {
        for (const { name, text } of sourceFiles()) {
            const has = members(text);
            if (ROWS.some(m => has[m]))
                for (const m of ROWS)
                    assert.ok(has[m], `${name} declares ${m}`);
            assert.match(text, /^    required property var search$/m, `${name} takes search as a required property`);
        }
    });

    test.it("declares functions as functions and properties as properties", () => {
        for (const { name, text } of sourceFiles()) {
            const has = members(text);
            for (const m of CONTRACT.filter(c => has[c]))
                assert.strictEqual(has[m], FUNCTIONS.includes(m) ? "function" : "property", `${name}.${m}`);
        }
    });

    test.it("gives every kind to exactly one source", () => {
        const owner = {};
        for (const { name, text } of sourceFiles()) {
            if (!members(text).kinds)
                continue;
            const kinds = kindsOf(text);
            assert.ok(kinds && kinds.length, `${name} lists its kinds literally`);
            for (const k of kinds) {
                assert.ok(!owner[k], `${k} is claimed by ${owner[k]} and ${name}`);
                owner[k] = name;
            }
        }
    });

    test.it("reads nothing from a source that the contract leaves out", () => {
        const read = new Set([...SEARCH.matchAll(/\b(?:owner|aloneSource|s)\??\.(\w+)/g)].map(m => m[1]));
        for (const m of read)
            assert.ok(CONTRACT.includes(m), `LauncherSearch reads ${m} from a source`);
    });

    test.it("describes every member on the contract page", () => {
        for (const m of CONTRACT)
            assert.match(DOC, new RegExp("^\\| `" + m + "(?:\\(row\\)|\\(id\\))?` \\| " + (m === "search" ? "yes" : ROWS.includes(m) ? "rows" : "no") + " \\|", "m"), m);
    });
});
