const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "config/configuration.js"), "utf8");
const Configuration = new Function(src + "\nreturn { merge, assign, lookup, upgrade, upgradeValue, readText, readFailed, reuse, saveDelay, reapply, jsonErrorAt };")();

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

    test.it("copies only the path to a changed key and names the sections it touched", () => {
        const values = defaults();
        const out = Configuration.assign(values, [["sidebar.workspaces.slot", 40], ["theme", "paper"]]);
        assert.deepStrictEqual(out.changed, ["sidebar", "theme"]);
        assert.notStrictEqual(out.values.sidebar, values.sidebar);
        assert.notStrictEqual(out.values.sidebar.workspaces, values.sidebar.workspaces);
        assert.strictEqual(out.values.sidebar.perScreen, values.sidebar.perScreen);
        assert.strictEqual(out.values.font, values.font);
        assert.strictEqual(out.values.files, values.files);
        assert.strictEqual(values.sidebar.workspaces.slot, 32);
        assert.strictEqual(values.theme, "slate");
    });

    test.it("leaves the values as they were when nothing would change", () => {
        const values = defaults();
        const out = Configuration.assign(values, [["sidebar.width", 52], ["clock.cloud", ["claude", "-p"]]]);
        assert.strictEqual(out.refused, "");
        assert.deepStrictEqual(out.changed, []);
        assert.strictEqual(out.values, values);
    });

    test.it("keeps every step of a slider drag and ends on the last one", () => {
        let values = defaults();
        for (const width of [53, 60, 71, 88, 90])
            values = Configuration.assign(values, [["sidebar.width", width]]).values;
        assert.strictEqual(values.sidebar.width, 90);
        assert.strictEqual(JSON.parse(JSON.stringify(values, null, 4)).sidebar.width, 90);
    });

    test.it("stores its own copy of an object, so later edits to it do not leak in", () => {
        const perScreen = { "DP-1": true };
        const out = Configuration.assign(defaults(), [["sidebar.perScreen", perScreen]]);
        perScreen["DP-2"] = true;
        assert.deepStrictEqual(out.values.sidebar.perScreen, { "DP-1": true });
    });
});

test.describe("reuse", () => {
    test.it("keeps the old object for every part that did not change", () => {
        const before = defaults();
        const after = defaults();
        after.sidebar.width = 90;
        const out = Configuration.reuse(before, after);
        assert.deepStrictEqual(out, after);
        assert.notStrictEqual(out, before);
        assert.notStrictEqual(out.sidebar, before.sidebar);
        assert.strictEqual(out.sidebar.perScreen, before.sidebar.perScreen);
        assert.strictEqual(out.sidebar.workspaces, before.sidebar.workspaces);
        assert.strictEqual(out.font, before.font);
        assert.strictEqual(out.files, before.files);
    });

    test.it("returns the old values whole when the file says the same thing", () => {
        const before = defaults();
        assert.strictEqual(Configuration.reuse(before, defaults()), before);
    });

    test.it("notices keys that came or went and arrays that changed length", () => {
        const before = defaults();
        const grew = defaults();
        grew.sidebar.perScreen = { "DP-1": true };
        assert.deepStrictEqual(Configuration.reuse(before, grew).sidebar.perScreen, { "DP-1": true });
        const longer = defaults();
        longer.font.scale.push(5);
        assert.deepStrictEqual(Configuration.reuse(before, longer).font.scale, [2, 3, 4, 5]);
        const shorter = defaults();
        delete shorter.files.zoom;
        assert.strictEqual("zoom" in Configuration.reuse(before, shorter).files, false);
        assert.strictEqual(before.files.zoom, 1.0);
    });
});

test.describe("reapply", () => {
    test.it("keeps a change still waiting to be saved when the file is edited from outside", () => {
        const fromFile = defaults();
        fromFile.theme = "paper";
        const out = Configuration.reapply(fromFile, [["sidebar.width", 90], ["sidebar.width", 96]]);
        assert.strictEqual(out.sidebar.width, 96);
        assert.strictEqual(out.theme, "paper");
    });

    test.it("takes the file as it is when nothing is waiting or a waiting key no longer fits", () => {
        const fromFile = defaults();
        assert.strictEqual(Configuration.reapply(fromFile, []), fromFile);
        assert.strictEqual(Configuration.reapply(fromFile, [["sidebar.gone", 1]]), fromFile);
    });
});

test.describe("saveDelay", () => {
    const quiet = 300;
    const longest = 2000;

    test.it("waits for the writes to go quiet", () => {
        assert.strictEqual(Configuration.saveDelay(1000, 1000, quiet, longest), 300);
        assert.strictEqual(Configuration.saveDelay(1000, 1250, quiet, longest), 300);
    });

    test.it("never holds an unsaved change past the longest wait, however long a drag goes on", () => {
        assert.strictEqual(Configuration.saveDelay(1000, 2800, quiet, longest), 200);
        assert.strictEqual(Configuration.saveDelay(1000, 3000, quiet, longest), 0);
        assert.strictEqual(Configuration.saveDelay(1000, 9000, quiet, longest), 0);
    });

    test.it("saves a drag once, a quiet spell after the last step", () => {
        const steps = [0, 40, 80, 120, 160, 200, 240];
        let since = null;
        let due = null;
        const saves = [];
        for (const at of steps) {
            if (due !== null && at >= due) {
                saves.push(due);
                since = null;
            }
            if (since === null)
                since = at;
            due = at + Configuration.saveDelay(since, at, quiet, longest);
        }
        saves.push(due);
        assert.deepStrictEqual(saves, [540]);
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
    test.it("keeps main when it was set before the upgrade with the keep-channel mark in place", () => {
        const setOnOldCode = { updates: { channel: "main", branch: "main", interval: 30 } };
        assert.deepStrictEqual(Configuration.upgrade(setOnOldCode, true).updates, { channel: "main", channelUpgraded: true, branch: "main", interval: 30 });
        assert.strictEqual(Configuration.upgrade(Configuration.upgrade(setOnOldCode, true)).updates.channel, "main");
        assert.deepStrictEqual(Configuration.upgrade({ updates: { channel: "stable" } }, true).updates, { channel: "stable", channelUpgraded: true });
    });

    test.it("moves a copy on main to the release channel once, and leaves a later choice of main alone", () => {
        const old = { updates: { channel: "main", branch: "main", interval: 30 } };
        const moved = Configuration.upgrade(old);
        assert.deepStrictEqual(moved.updates, { channel: "stable", channelUpgraded: true, branch: "main", interval: 30 });
        const chosen = { updates: Object.assign({}, moved.updates, { channel: "main" }) };
        assert.strictEqual(Configuration.upgrade(chosen), chosen);
        assert.deepStrictEqual(Configuration.upgrade({ updates: { channel: "stable" } }).updates, { channel: "stable", channelUpgraded: true });
        assert.deepStrictEqual(Configuration.upgrade({ theme: "x" }), { theme: "x" });
        assert.deepStrictEqual(Configuration.upgrade({ updates: { channel: "main", channelUpgraded: false } }).updates, { channel: "stable", channelUpgraded: true });
    });

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

    test.it("gives a saved file grid keymap Ctrl+Z for undo unless undo or Ctrl+Z is already bound", () => {
        const saved = { files: { grid: { "Ctrl+C": "copy", F5: "refresh" }, view: "list" } };
        assert.deepStrictEqual(Configuration.upgrade(saved), { files: { grid: { "Ctrl+C": "copy", F5: "refresh", "Ctrl+Z": "undo" }, view: "list" } });
        const moved = { files: { grid: { "Ctrl+U": "undo", F5: "refresh" } } };
        assert.strictEqual(Configuration.upgrade(moved), moved);
        const taken = { files: { grid: { "Ctrl+Z": "trash", F5: "refresh" } } };
        assert.strictEqual(Configuration.upgrade(taken), taken);
    });

    test.it("moves Markdown source saved by the old Settings to the value the file manager shows as source", () => {
        assert.deepStrictEqual(Configuration.upgrade({ files: { markdown: "source", sort: "date" } }), { files: { markdown: "raw", sort: "mtime" } });
        assert.strictEqual(Configuration.upgradeValue("files.markdown", "source"), "raw");
        const current = { files: { markdown: "raw" } };
        assert.strictEqual(Configuration.upgrade(current), current);
    });

    test.it("gives a saved files grid keymap F5 for refresh unless refresh already has a key", () => {
        assert.deepStrictEqual(Configuration.upgrade({ files: { grid: { F2: "rename", "Ctrl+Z": "undo" } } }), { files: { grid: { F2: "rename", "Ctrl+Z": "undo", F5: "refresh" } } });
        const moved = { files: { grid: { "Ctrl+R": "refresh", "Ctrl+Z": "undo" } } };
        assert.strictEqual(Configuration.upgrade(moved), moved);
        const taken = { files: { grid: { F5: "view", "Ctrl+Z": "undo" } } };
        assert.strictEqual(Configuration.upgrade(taken), taken);
    });

    test.it("moves the update colours the shell shipped as defaults off the privacy and accent colours, once", () => {
        const colours = values => {
            const u = Configuration.upgrade(values).updates;
            return [u.availableColour, u.failedColour, u.readyColour, u.coloursUpgraded];
        };
        assert.deepStrictEqual(colours({ updates: { availableColour: "alarm", failedColour: "bright", readyColour: "accent" } }), ["text", "warning", "accent", true]);
        assert.deepStrictEqual(colours({ updates: { availableColour: "#ff5252", failedColour: "#ffb454", readyColour: "#4da3ff" } }), ["text", "warning", "#4da3ff", true]);
        assert.deepStrictEqual(colours({ updates: { availableColour: "mid", failedColour: "#ff0000" } }), ["mid", "#ff0000", undefined, true]);
    });

    test.it("keeps alarm or bright chosen after the colour upgrade ran", () => {
        const chosen = { updates: { availableColour: "alarm", failedColour: "bright", coloursUpgraded: true, channelUpgraded: true } };
        assert.strictEqual(Configuration.upgrade(chosen), chosen);
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

test.describe("reading config.json", () => {
    const boot = () => ({ values: defaults(), loaded: false });
    const read = (raw, state) => Configuration.readText(raw, state, defaults(), false, OPAQUE, {});

    test.it("boots on the defaults when the file does not parse, and writes nothing", () => {
        const got = read('{ "theme": "slate", }', boot());
        assert.strictEqual(got.loaded, true);
        assert.strictEqual(got.unreadable, true);
        assert.strictEqual(got.save, false);
        assert.deepStrictEqual(got.values, defaults());
        assert.match(got.problem, /JSON|token|property/i);
    });

    test.it("says the line and column of a stray comma", () => {
        const got = read('{\n  "theme": "slate",\n}\n', boot());
        assert.deepStrictEqual(got.at, { line: 3, column: 1 });
    });

    test.it("finds a position exactly when JSON.parse refuses", () => {
        const samples = ['{"a" 1}', '{"a":tru}', "[1,2", "{} x", "", '{"a":01}', '{"a":"x\\q"}', '{"a":"\t"}', '{"a":[1,{"b":null}]}', '  {"a":-1.5e3}  ', '"ok"', '{"a":"\\u00e9"}', '{"a":"\\u00g9"}'];
        for (const raw of samples) {
            let parses = true;
            try {
                JSON.parse(raw);
            } catch (e) {
                parses = false;
            }
            assert.strictEqual(Configuration.jsonErrorAt(raw) === null, parses, raw);
        }
    });

    test.it("treats a file that parses to something other than an object as broken", () => {
        for (const raw of ["[]", "null", "42", "\"slate\""]) {
            const got = read(raw, boot());
            assert.deepStrictEqual([got.loaded, got.unreadable, got.save], [true, true, false], raw);
        }
    });

    test.it("keeps the values it had when the file breaks mid-session", () => {
        const running = { values: Object.assign(defaults(), { theme: "dusk" }), loaded: true };
        const got = read("{", running);
        assert.strictEqual(got.values.theme, "dusk");
        assert.deepStrictEqual([got.loaded, got.unreadable, got.save], [true, true, false]);
    });

    test.it("takes the file once it is fixed, and saves only what the schema added", () => {
        const whole = read(JSON.stringify(defaults()), boot()).values;
        const fixed = read(JSON.stringify(whole), { values: defaults(), loaded: true });
        assert.deepStrictEqual([fixed.unreadable, fixed.save], [false, false]);
        const short = read('{ "theme": "dusk" }', boot());
        assert.deepStrictEqual([short.unreadable, short.save, short.values.theme], [false, true, "dusk"]);
    });

    test.it("boots on the defaults when the file cannot be read, and writes nothing", () => {
        const got = Configuration.readFailed(false);
        assert.deepStrictEqual([got.loaded, got.unreadable, got.fresh, got.save], [true, true, false, false]);
    });

    test.it("writes a fresh file only when there was none", () => {
        const got = Configuration.readFailed(true);
        assert.deepStrictEqual([got.loaded, got.unreadable, got.fresh, got.save], [true, false, true, true]);
    });
});

test.describe("readers", () => {
    function qmlFiles(dir) {
        const found = [];
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
            if ([".git", ".scratch", "node_modules", "tests"].includes(entry.name))
                continue;
            const full = path.join(dir, entry.name);
            if (entry.isDirectory())
                found.push(...qmlFiles(full));
            else if (entry.name.endsWith(".qml"))
                found.push(full);
        }
        return found;
    }

    test.it("listen to the section they read, since the values as a whole never change", () => {
        const waiting = [];
        for (const file of qmlFiles(ROOT)) {
            const text = fs.readFileSync(file, "utf8");
            for (const at of text.matchAll(/target:\s*Config\s*\n/g))
                if (/function onValuesChanged\b/.test(text.slice(at.index, text.indexOf("\n    }", at.index) + 1 || undefined)))
                    waiting.push(path.relative(ROOT, file));
        }
        assert.deepStrictEqual(waiting, []);
    });
});
