const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const SETTINGS = path.join(ROOT, "modules/settings");

function lib(file, names) {
    const src = fs.readFileSync(file, "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

function block(file, opener) {
    const text = fs.readFileSync(file, "utf8");
    const start = text.indexOf(opener);
    assert.ok(start >= 0, `${opener} is in ${file}`);
    const open = text.indexOf("{", start);
    let depth = 0;
    for (let j = open; j < text.length; j++) {
        if (text[j] === "{")
            depth++;
        else if (text[j] === "}" && --depth === 0)
            return text.slice(open, j + 1);
    }
    throw new Error(`unclosed ${opener}`);
}

const Restore = lib(path.join(SETTINGS, "restore.js"), ["exportable", "newest", "read", "diff", "phrase", "summary", "same"]);
const Configuration = lib(path.join(ROOT, "config/configuration.js"), ["assign"]);

const CONFIG = path.join(ROOT, "config/Config.qml");
const STATE = path.join(SETTINGS, "SettingsState.qml");
const DEFAULTS = new Function(`return (${block(CONFIG, "readonly property var defaults:")});`)();
const OPAQUE = new Function(`return ${fs.readFileSync(CONFIG, "utf8").match(/readonly property var opaque: (\[.*\])/)[1]};`)();
const LITERALS = new Function(`return (${block(CONFIG, "readonly property var literals:")});`)();
const CONFIG_BACKED = new Function(`return (${block(STATE, "readonly property var configBacked:")});`)();
const PLAN_DEFAULTS = new Function(`return (${block(STATE, "readonly property var planDefaults:")});`)();

const clone = value => JSON.parse(JSON.stringify(value));

function world(extra) {
    const current = clone(DEFAULTS);
    const state = Object.assign({
        current,
        planned: {},
        rows: {},
        servicePaths: {}
    }, extra);
    return {
        defaults: DEFAULTS,
        opaque: OPAQUE,
        current: state.current,
        configBacked: Object.assign({}, CONFIG_BACKED, state.configBacked),
        planDefaults: Object.assign({}, PLAN_DEFAULTS, state.planDefaults),
        planned: state.planned,
        servicePaths: state.servicePaths,
        fits: (key, value) => !Configuration.assign(state.current, [[key, value]], LITERALS).refused,
        transformWrite: (key, value) => key === "notifTimeout" ? value * 1000 : value,
        hasRow: key => key in state.rows,
        rowValue: key => state.rows[key]
    };
}

function copyOf(config, planned) {
    return { config: config ?? {}, planned: planned ?? {} };
}

test.describe("reading a copy", () => {
    test.it("takes a copy with config and planned settings", () => {
        const out = Restore.read(JSON.stringify({ config: { theme: "slate" }, planned: { kbDelay: 400 } }));
        assert.deepStrictEqual(out.file, { config: { theme: "slate" }, planned: { kbDelay: 400 } });
    });

    test.it("takes a copy with only one of the two", () => {
        assert.deepStrictEqual(Restore.read('{"config":{}}').file, { config: {}, planned: {} });
        assert.deepStrictEqual(Restore.read('{"planned":{}}').file, { config: {}, planned: {} });
    });

    test.it("says plainly why a file is no copy", () => {
        assert.strictEqual(Restore.read("{").why, "that file is not valid JSON");
        assert.strictEqual(Restore.read("").why, "that file is not valid JSON");
        assert.strictEqual(Restore.read("[1]").why, "that file is not a settings copy");
        assert.strictEqual(Restore.read("5").why, "that file is not a settings copy");
        assert.strictEqual(Restore.read("{}").why, "that file has neither config nor planned settings in it");
        assert.strictEqual(Restore.read('{"config":[1]}').why, "the config in that file is not a table of settings");
        assert.strictEqual(Restore.read('{"config":{},"planned":"x"}').why, "the planned settings in that file are not a table");
    });
});

test.describe("finding the copy", () => {
    test.it("picks the newest by the date in its name and ignores everything else", () => {
        const names = ["banditshell-settings-2026-10-02-0915.json", "notes.txt", "banditshell-settings-2026-10-14-1730.json", "banditshell-settings-2026-10-14-0800.json", "banditshell-settings-.json"];
        assert.strictEqual(Restore.newest(names), "banditshell-settings-2026-10-14-1730.json");
        assert.strictEqual(Restore.newest(["a.json", ""]), "");
        assert.strictEqual(Restore.newest([]), "");
    });
});

test.describe("exporting", () => {
    test.it("leaves the passwords out and the input alone", () => {
        const config = clone(DEFAULTS);
        config.obs.password = "hunter2";
        const planned = { hotspotPass: "wifi-secret", hotspotName: "mine", kbDelay: 300 };
        const out = Restore.exportable(config, planned);
        assert.ok(!("password" in out.config.obs));
        assert.strictEqual(out.config.obs.host, "");
        assert.deepStrictEqual(out.planned, { hotspotName: "mine", kbDelay: 300 });
        assert.strictEqual(config.obs.password, "hunter2");
        assert.strictEqual(planned.hotspotPass, "wifi-secret");
        assert.ok(!JSON.stringify(out).includes("hunter2"));
        assert.ok(!JSON.stringify(out).includes("wifi-secret"));
    });

    test.it("keeps every other part of the config", () => {
        const out = Restore.exportable(DEFAULTS, {});
        const expected = clone(DEFAULTS);
        delete expected.obs.password;
        assert.deepStrictEqual(out.config, expected);
    });

    test.it("tolerates a config without the secret in it", () => {
        const out = Restore.exportable({ theme: "slate" }, undefined);
        assert.deepStrictEqual(out, { config: { theme: "slate" }, planned: {} });
    });
});

test.describe("what would change", () => {
    test.it("finds nothing when the copy is what you have now", () => {
        const w = world();
        const exported = Restore.exportable(w.current, {});
        const out = Restore.diff(copyOf(exported.config), w);
        assert.deepStrictEqual(out, { changes: [], skipped: [] });
    });

    test.it("names a changed setting with the row that shows it", () => {
        const w = world();
        const out = Restore.diff(copyOf({ volume: { step: 0.1 } }), w);
        assert.deepStrictEqual(out.changes, [{ route: "config", path: "volume.step", key: "volStep", from: 0.05, to: 0.1 }]);
    });

    test.it("names a setting the panel has no row for by its path", () => {
        const out = Restore.diff(copyOf({ launcher: { alphabet: { width: 700 } } }), world());
        assert.deepStrictEqual(out.changes, [{ route: "config", path: "launcher.alphabet.width", key: "", from: 760, to: 700 }]);
    });

    test.it("compares free maps and key maps whole, whatever their key order", () => {
        const w = world();
        w.current.launcher.hidden = { a: true, b: true };
        const same = Restore.diff(copyOf({ launcher: { hidden: { b: true, a: true } } }), w);
        assert.strictEqual(same.changes.length, 0);
        const moved = Restore.diff(copyOf({ launcher: { hidden: { a: true } }, files: { keys: { "Ctrl+J": "preview" } } }), w);
        assert.deepStrictEqual(moved.changes.map(c => c.path), ["launcher.hidden", "files.keys"]);
        assert.deepStrictEqual(moved.changes[0].from, { a: true, b: true });
    });

    test.it("takes a palette word where a list was", () => {
        const out = Restore.diff(copyOf({ files: { terminal: { palette: "theme" } } }), world());
        assert.deepStrictEqual(out.changes.map(c => [c.path, c.key, c.to]), [["files.terminal.palette", "termColours", "theme"]]);
        assert.strictEqual(Restore.diff(copyOf({ files: { terminal: { palette: "neon" } } }), world()).skipped.length, 1);
    });

    test.it("skips what is not a setting here and says so", () => {
        const out = Restore.diff(copyOf({ nonsense: 1, volume: { step: 0.1, bogus: 2 }, sidebar: { workspaces: { specials: 5 } } }, { bogus: 1 }), world());
        assert.deepStrictEqual(out.changes.map(c => c.path), ["volume.step"]);
        assert.deepStrictEqual(out.skipped.map(s => s.key).sort(), ["bogus", "nonsense", "sidebar.workspaces.specials", "volume.bogus"]);
        assert.strictEqual(out.skipped.find(s => s.key === "nonsense").why, "not a setting here");
        assert.strictEqual(out.skipped.find(s => s.key === "sidebar.workspaces.specials").why, "this machine cannot take that value");
    });

    test.it("skips a value in the place of a whole section", () => {
        const out = Restore.diff(copyOf({ sidebar: 5 }), world());
        assert.deepStrictEqual(out, { changes: [], skipped: [{ key: "sidebar", why: "not a section here" }] });
    });

    test.it("never takes a password, in the config or in the planned lists", () => {
        const out = Restore.diff(copyOf({ obs: { password: "x", host: "studio.lan" } }, { hotspotPass: "y" }), world());
        assert.deepStrictEqual(out.changes.map(c => c.path), ["obs.host"]);
        assert.deepStrictEqual(out.skipped, [{ key: "obs.password", why: "passwords stay out of copies" }, { key: "hotspotPass", why: "passwords stay out of copies" }]);
    });

    test.it("compares a planned setting against its default until it was ever changed", () => {
        assert.ok("customLayout" in PLAN_DEFAULTS);
        const untouched = Restore.diff(copyOf({}, { customLayout: "", kbDelay2: 1 }), world());
        assert.deepStrictEqual(untouched.changes, []);
        assert.deepStrictEqual(untouched.skipped, [{ key: "kbDelay2", why: "not a setting here" }]);
        const changed = world({ planned: { customLayout: "orbit" } });
        assert.deepStrictEqual(Restore.diff(copyOf({}, { customLayout: "orbit" }), changed).changes, []);
        assert.deepStrictEqual(Restore.diff(copyOf({}, { customLayout: "" }), changed).changes, [{ route: "planned", path: "", key: "customLayout", from: "orbit", to: "" }]);
    });

    test.it("refuses a planned value of another kind", () => {
        const out = Restore.diff(copyOf({}, { customLayout: 5, startup: {} }), world());
        assert.deepStrictEqual(out.changes, []);
        assert.strictEqual(out.skipped.length, 2);
    });

    test.it("refuses a value of another kind for a setting that has moved to config", () => {
        assert.ok("dnd" in CONFIG_BACKED && !("dnd" in PLAN_DEFAULTS));
        const out = Restore.diff(copyOf({ volume: { step: "big" } }, { dnd: "yes" }), world());
        assert.deepStrictEqual(out.changes, []);
        assert.deepStrictEqual(out.skipped.map(s => s.key), ["volume.step", "dnd"]);
    });

    test.it("sends a planned key that has since moved to config through its transform", () => {
        assert.ok("notifTimeout" in CONFIG_BACKED && !("notifTimeout" in PLAN_DEFAULTS));
        const out = Restore.diff(copyOf({}, { notifTimeout: 8 }), world());
        assert.deepStrictEqual(out.changes, [{ route: "config", path: "notifications.timeout", key: "notifTimeout", from: 5000, to: 8000 }]);
    });

    test.it("follows the maps, not a list, when more keys move", () => {
        const w = world({ configBacked: { dnd: "usage.capHours" } });
        delete w.planDefaults.dnd;
        const out = Restore.diff(copyOf({}, { dnd: 6 }), w);
        assert.deepStrictEqual(out.changes, [{ route: "config", path: "usage.capHours", key: "dnd", from: 10, to: 6 }]);
    });

    test.it("lets the copy's own config win over a planned value for the same key", () => {
        const out = Restore.diff(copyOf({ notifications: { timeout: 3000 } }, { notifTimeout: 8 }), world());
        assert.deepStrictEqual(out.changes.map(c => [c.path, c.to]), [["notifications.timeout", 3000]]);
    });

    test.it("leaves a planned key that has since moved to config alone when it already matches", () => {
        const out = Restore.diff(copyOf({}, { notifTimeout: 5 }), world());
        assert.deepStrictEqual(out.changes, []);
    });

    test.it("sends a key that a service owns through its row", () => {
        const w = world({ rows: { overAmpish: false } });
        const out = Restore.diff(copyOf({}, { overAmpish: true }), w);
        assert.deepStrictEqual(out.changes, [{ route: "setting", path: "", key: "overAmpish", from: false, to: true }]);
        assert.deepStrictEqual(Restore.diff(copyOf({}, { overAmpish: false }), w).changes, []);
    });

    test.it("sends the theme through the service that applies it", () => {
        const w = world({ rows: { theme: "slate" }, servicePaths: { theme: "theme" } });
        const out = Restore.diff(copyOf({ theme: "ember" }), w);
        assert.deepStrictEqual(out.changes, [{ route: "setting", path: "theme", key: "theme", from: "slate", to: "ember" }]);
        assert.strictEqual(Restore.diff(copyOf({ theme: "slate" }), w).changes.length, 0);
    });

    test.it("ignores what the panel keeps for itself", () => {
        const out = Restore.diff(copyOf({}, { modeWas: { dnd: false } }), world());
        assert.deepStrictEqual(out, { changes: [], skipped: [] });
    });
});

test.describe("saying it", () => {
    test.it("phrases values short and plain", () => {
        assert.strictEqual(Restore.phrase(true), "on");
        assert.strictEqual(Restore.phrase(false), "off");
        assert.strictEqual(Restore.phrase(0.30000000000000004), "0.3");
        assert.strictEqual(Restore.phrase(""), "empty");
        assert.strictEqual(Restore.phrase(undefined), "nothing");
        assert.strictEqual(Restore.phrase("a".repeat(40)), `${"a".repeat(25)}…`);
        assert.strictEqual(Restore.phrase(["claude", "-p"]), "claude, -p");
        assert.strictEqual(Restore.phrase([{ a: 1 }, { a: 2 }]), "2 items");
        assert.strictEqual(Restore.phrase([]), "empty");
        assert.strictEqual(Restore.phrase({}), "empty");
        assert.strictEqual(Restore.phrase({ a: 1 }), "1 entry");
        assert.strictEqual(Restore.phrase({ a: 1, b: 2 }), "2 entries");
    });

    test.it("counts the changes and the skips", () => {
        assert.strictEqual(Restore.summary([1], []), "1 change");
        assert.strictEqual(Restore.summary([1, 2], [1]), "2 changes · 1 skipped");
    });

    test.it("compares deeply and ignores key order", () => {
        assert.ok(Restore.same({ a: [1, { b: 2 }], c: 3 }, { c: 3, a: [1, { b: 2 }] }));
        assert.ok(!Restore.same({ a: 1 }, { a: 1, b: 2 }));
        assert.ok(!Restore.same([1, 2], [2, 1]));
        assert.ok(!Restore.same([], {}));
    });
});
