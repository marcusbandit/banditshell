const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "config/configuration.js"), "utf8");
const Configuration = new Function(src + "\nreturn { merge, assign, lookup, upgrade, upgradeValue };")();

const OPAQUE = ["files.keys", "files.grid"];

function defaults() {
    return {
        theme: "slate",
        font: { family: "Monocraft", scale: [2, 3, 4] },
        sidebar: { width: 52, enabled: true, perScreen: {}, workspaces: { specials: [], slot: 32 } },
        clock: { cloud: ["claude", "-p"], snoozeMinutes: 9 },
        files: { keys: { "Ctrl+J": "terminal" }, grid: { h: "left" }, zoom: 1.0 }
    };
}

function merged(over) {
    return Configuration.merge(defaults(), over, "", OPAQUE);
}

test.describe("merge", () => {
    test.it("fills every missing key from the defaults", () => {
        assert.deepStrictEqual(merged({}), defaults());
    });

    test.it("keeps a user array whatever its length", () => {
        assert.deepStrictEqual(merged({ clock: { cloud: ["claude", "-p", "--model", "opus"] } }).clock.cloud, ["claude", "-p", "--model", "opus"]);
        assert.deepStrictEqual(merged({ clock: { cloud: ["ollama"] } }).clock.cloud, ["ollama"]);
        assert.deepStrictEqual(merged({ clock: { cloud: [] } }).clock.cloud, []);
        assert.deepStrictEqual(merged({ font: { scale: [1, 2, 3, 4, 5] } }).font.scale, [1, 2, 3, 4, 5]);
        assert.deepStrictEqual(merged({ sidebar: { workspaces: { specials: ["scratch", "music"] } } }).sidebar.workspaces.specials, ["scratch", "music"]);
    });

    test.it("falls back when an array setting holds something else", () => {
        assert.deepStrictEqual(merged({ clock: { cloud: "claude -p" } }).clock.cloud, ["claude", "-p"]);
        assert.deepStrictEqual(merged({ font: { scale: { 0: 1 } } }).font.scale, [2, 3, 4]);
    });

    test.it("falls back to the defaults for a null or wrongly typed section without throwing", () => {
        for (const bad of [null, 5, "wide", true, [], [1, 2]]) {
            const out = merged({ sidebar: bad, theme: "paper" });
            assert.deepStrictEqual(out.sidebar, defaults().sidebar, JSON.stringify(bad));
            assert.strictEqual(out.theme, "paper");
        }
        assert.deepStrictEqual(merged({ sidebar: { workspaces: null } }).sidebar.workspaces, defaults().sidebar.workspaces);
    });

    test.it("falls back when the whole file is not an object", () => {
        for (const bad of [null, 3, "x", []])
            assert.deepStrictEqual(merged(bad), defaults(), JSON.stringify(bad));
    });

    test.it("does not let an object stand in for a plain value", () => {
        assert.strictEqual(merged({ sidebar: { width: { px: 90 } } }).sidebar.width, 52);
        assert.strictEqual(merged({ sidebar: { width: [90] } }).sidebar.width, 52);
        assert.strictEqual(merged({ sidebar: { width: 90 } }).sidebar.width, 90);
    });

    test.it("drops keys the defaults do not know", () => {
        const out = merged({ stray: 1, sidebar: { width: 60, ghost: true } });
        assert.strictEqual(out.stray, undefined);
        assert.strictEqual(out.sidebar.ghost, undefined);
        assert.strictEqual(out.sidebar.width, 60);
    });

    test.it("keeps a user map under an empty default object", () => {
        const out = merged({ sidebar: { perScreen: { "DP-1": false } } });
        assert.deepStrictEqual(out.sidebar.perScreen, { "DP-1": false });
        assert.deepStrictEqual(merged({ sidebar: { perScreen: ["DP-1"] } }).sidebar.perScreen, {});
    });

    test.it("takes the opaque key maps whole", () => {
        const keys = { "Ctrl+K": "terminal" };
        const out = merged({ files: { keys, grid: "nope" } });
        assert.deepStrictEqual(out.files.keys, keys);
        assert.deepStrictEqual(out.files.grid, { h: "left" });
    });

    test.it("reads only the file's own keys", () => {
        const over = JSON.parse('{"__proto__": {"theme": "evil"}, "sidebar": {"__proto__": {"width": 1}}}');
        const out = merged(over);
        assert.strictEqual(out.theme, "slate");
        assert.strictEqual(out.sidebar.width, 52);
        assert.strictEqual({}.theme, undefined);
    });

    test.it("leaves its inputs alone", () => {
        const base = defaults();
        const over = { sidebar: { width: 70 } };
        Configuration.merge(base, over, "", OPAQUE);
        assert.deepStrictEqual(base, defaults());
        assert.deepStrictEqual(over, { sidebar: { width: 70 } });
    });
});

test.describe("assign", () => {
    test.it("sets a nested key on a copy", () => {
        const values = defaults();
        const out = Configuration.assign(values, [["sidebar.width", 90]]);
        assert.strictEqual(out.refused, "");
        assert.strictEqual(out.values.sidebar.width, 90);
        assert.strictEqual(values.sidebar.width, 52);
    });

    test.it("applies a batch together", () => {
        const out = Configuration.assign(defaults(), [["sidebar.perScreen", { "DP-1": true }], ["sidebar.enabled", false]]);
        assert.deepStrictEqual(out.values.sidebar.perScreen, { "DP-1": true });
        assert.strictEqual(out.values.sidebar.enabled, false);
    });

    test.it("refuses the whole batch when one key is unknown", () => {
        const out = Configuration.assign(defaults(), [["sidebar.width", 90], ["sidebar.height", 4]]);
        assert.strictEqual(out.refused, "sidebar.height");
        assert.strictEqual(out.values, null);
    });

    test.it("refuses paths through plain values and empty segments", () => {
        for (const key of ["theme.length", "sidebar.width.x", "nothing.here", "", "sidebar.", ".sidebar", "sidebar..width"])
            assert.strictEqual(Configuration.assign(defaults(), [[key, 1]]).refused, key, key);
    });

    test.it("refuses prototype segments and leaves Object.prototype alone", () => {
        for (const key of ["__proto__.toString", "constructor.prototype.polluted", "sidebar.__proto__.polluted", "prototype", "sidebar.constructor"])
            assert.strictEqual(Configuration.assign(defaults(), [[key, 1]]).refused, key, key);
        assert.strictEqual({}.polluted, undefined);
        assert.strictEqual(typeof {}.toString, "function");
    });

    test.it("refuses inherited names that are not settings", () => {
        for (const key of ["toString", "sidebar.hasOwnProperty", "font.scale.length", "font.scale.map"])
            assert.strictEqual(Configuration.assign(defaults(), [[key, 1]]).refused, key, key);
    });

    test.it("keeps the shape of sections, arrays and plain values", () => {
        assert.strictEqual(Configuration.assign(defaults(), [["sidebar", 5]]).refused, "sidebar");
        assert.strictEqual(Configuration.assign(defaults(), [["sidebar.perScreen", null]]).refused, "sidebar.perScreen");
        assert.strictEqual(Configuration.assign(defaults(), [["clock.cloud", "claude"]]).refused, "clock.cloud");
        assert.strictEqual(Configuration.assign(defaults(), [["sidebar.width", { px: 3 }]]).refused, "sidebar.width");
        assert.deepStrictEqual(Configuration.assign(defaults(), [["clock.cloud", ["ollama", "run"]]]).values.clock.cloud, ["ollama", "run"]);
    });

    test.it("reaches into arrays by index", () => {
        const out = Configuration.assign(defaults(), [["font.scale.1", 7]]);
        assert.deepStrictEqual(out.values.font.scale, [2, 7, 4]);
        assert.strictEqual(Configuration.assign(defaults(), [["font.scale.3", 7]]).refused, "font.scale.3");
    });
});

test.describe("lookup", () => {
    test.it("finds own keys only", () => {
        assert.strictEqual(Configuration.lookup(defaults(), "sidebar.width"), 52);
        assert.strictEqual(Configuration.lookup(defaults(), "font.scale.2"), 4);
        assert.strictEqual(Configuration.lookup(defaults(), "sidebar.nothing"), undefined);
        assert.strictEqual(Configuration.lookup(defaults(), "__proto__"), undefined);
        assert.strictEqual(Configuration.lookup(defaults(), "toString"), undefined);
        assert.strictEqual(Configuration.lookup(defaults(), "theme.length"), undefined);
    });
});

test.describe("upgrade", () => {
    test.it("moves the old launcher name and its sizes to alphabet", () => {
        const old = { launcher: { concept: "niagara", niagara: { width: 700 } }, theme: "slate" };
        assert.deepStrictEqual(Configuration.upgrade(old), { launcher: { concept: "alphabet", alphabet: { width: 700 } }, theme: "slate" });
    });

    test.it("keeps sizes already stored under alphabet and drops the old ones", () => {
        const both = { launcher: { concept: "list", niagara: { width: 700 }, alphabet: { width: 800 } } };
        assert.deepStrictEqual(Configuration.upgrade(both), { launcher: { concept: "list", alphabet: { width: 800 } } });
    });

    test.it("turns a single old launcher value into the new one and leaves the rest", () => {
        assert.strictEqual(Configuration.upgradeValue("launcher.concept", "niagara"), "alphabet");
        assert.strictEqual(Configuration.upgradeValue("launcher.concept", "list"), "list");
        assert.strictEqual(Configuration.upgradeValue("theme", "niagara"), "niagara");
    });

    test.it("splits the old small sidebar clock into stacked at the small size, rail and open", () => {
        const old = { sidebar: { clock: { style: "small", date: "day" } } };
        assert.deepStrictEqual(Configuration.upgrade(old), { sidebar: { clock: { style: "stacked", size: "small", wideStyle: "stacked", wideSize: "small", date: "day" } } });
        assert.strictEqual(Configuration.upgradeValue("sidebar.clock.style", "small"), "stacked");
    });

    test.it("keeps an open clock that was already chosen when it upgrades the small one", () => {
        const old = { sidebar: { clock: { style: "small", wideStyle: "one line" } } };
        assert.deepStrictEqual(Configuration.upgrade(old).sidebar.clock, { style: "stacked", size: "small", wideStyle: "one line" });
    });

    test.it("keeps a hidden sidebar clock hidden when the sidebar opens", () => {
        const old = { sidebar: { clock: { style: "off" } } };
        assert.deepStrictEqual(Configuration.upgrade(old).sidebar.clock, { style: "off", wideStyle: "off" });
    });

    test.it("lets a one line clock become stacked when the sidebar opens", () => {
        const old = { sidebar: { clock: { style: "one line" } } };
        assert.strictEqual(Configuration.upgrade(old), old);
    });

    test.it("moves a files sort saved by the old Settings to the values the file manager sorts on", () => {
        assert.deepStrictEqual(Configuration.upgrade({ files: { sort: "date", view: "list" } }), { files: { sort: "mtime", view: "list" } });
        assert.deepStrictEqual(Configuration.upgrade({ files: { sort: "type" } }), { files: { sort: "kind" } });
        assert.strictEqual(Configuration.upgradeValue("files.sort", "date"), "mtime");
        const current = { files: { sort: "size" } };
        assert.strictEqual(Configuration.upgrade(current), current);
    });

    test.it("moves Markdown source saved by the old Settings to the value the file manager shows as source", () => {
        assert.deepStrictEqual(Configuration.upgrade({ files: { markdown: "source", sort: "date" } }), { files: { markdown: "raw", sort: "mtime" } });
        assert.strictEqual(Configuration.upgradeValue("files.markdown", "source"), "raw");
        const current = { files: { markdown: "raw" } };
        assert.strictEqual(Configuration.upgrade(current), current);
    });

    test.it("leaves a config without a launcher alone", () => {
        const plain = { theme: "slate" };
        assert.strictEqual(Configuration.upgrade(plain), plain);
    });
});

test.describe("literals", () => {
    const literals = { "files.terminal.palette": ["theme"] };
    const base = () => ({ files: { terminal: { palette: ["#000000", "#ffffff"], rows: 16 } } });

    test.it("keeps a spoken word where a list is expected", () => {
        const out = Configuration.merge(base(), { files: { terminal: { palette: "theme" } } }, "", [], literals);
        assert.strictEqual(out.files.terminal.palette, "theme");
    });

    test.it("still refuses any other word", () => {
        const out = Configuration.merge(base(), { files: { terminal: { palette: "neon" } } }, "", [], literals);
        assert.deepStrictEqual(out.files.terminal.palette, ["#000000", "#ffffff"]);
    });

    test.it("falls back to the list when nothing allows the word", () => {
        const out = Configuration.merge(base(), { files: { terminal: { palette: "theme" } } }, "", []);
        assert.deepStrictEqual(out.files.terminal.palette, ["#000000", "#ffffff"]);
    });

    test.it("assigns the word and the list both", () => {
        const word = Configuration.assign(base(), [["files.terminal.palette", "theme"]], literals);
        assert.strictEqual(word.refused, "");
        assert.strictEqual(word.values.files.terminal.palette, "theme");
        const list = Configuration.assign(word.values, [["files.terminal.palette", ["#111111"]]], literals);
        assert.deepStrictEqual(list.values.files.terminal.palette, ["#111111"]);
    });

    test.it("refuses other words, and the word without the allowance", () => {
        assert.strictEqual(Configuration.assign(base(), [["files.terminal.palette", "neon"]], literals).refused, "files.terminal.palette");
        assert.strictEqual(Configuration.assign(base(), [["files.terminal.palette", "theme"]]).refused, "files.terminal.palette");
    });
});
