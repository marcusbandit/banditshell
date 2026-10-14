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

const Catalogue = lib(path.join(SETTINGS, "catalogue.js"), ["CATS", "PAGES", "PAGE_BY_ID", "CAT_BY_ID", "ROWS", "ROW_BY_KEY", "MODES", "LAYOUTS", "INDEX", "search", "resolve", "options", "format", "show", "step", "nearest", "labelOf", "dwindleRects", "niagaraAt", "bowAt", "zoneOf", "pagesCovered", "val", "present", "nameOf"]);
const Screens = lib(path.join(SETTINGS, "screens.js"), ["rectOf", "overlaps", "contact", "issues", "snap", "settle", "nudge", "resize", "fit"]);
const Boards = lib(path.join(SETTINGS, "boards.js"), ["BOARDS", "SAMPLE_VIA", "kle", "readVia", "extent", "rects", "board", "lit"]);
const Frames = lib(path.join(SETTINGS, "scenes/keyframes.js"), ["bezier", "STANDARD", "ARRIVE", "BACK", "at", "pulse", "steps"]);

function block(file, opener) {
    const text = fs.readFileSync(file, "utf8");
    const start = text.indexOf(opener);
    assert.ok(start >= 0, `${opener} is in ${file}`);
    let i = text.indexOf("{", start);
    let depth = 0;
    for (let j = i; j < text.length; j++) {
        if (text[j] === "{")
            depth++;
        else if (text[j] === "}") {
            depth--;
            if (depth === 0)
                return text.slice(i, j + 1);
        }
    }
    throw new Error(`unclosed ${opener}`);
}

const DEFAULTS = new Function(`return (${block(path.join(ROOT, "config/Config.qml"), "readonly property var defaults:")});`)();
const STATE = path.join(SETTINGS, "SettingsState.qml");
const CONFIG_BACKED = new Function(`return (${block(STATE, "readonly property var configBacked:")});`)();
const PLAN_DEFAULTS = new Function(`return (${block(STATE, "readonly property var planDefaults:")});`)();

function lookup(values, key) {
    return key.split(".").reduce((at, part) => at === undefined || at === null ? undefined : at[part], values);
}

const NUMERIC = new Set(["neutral", "tunnelCount", "appsPlaying", "btNear", "starredCount", "trayCount", "batteryPct", "healthPct", "startupOn", "keyCount", "changeCount", "clipseWaiting", "usedMinutes"]);

function fakeState(values) {
    const all = Object.assign({}, PLAN_DEFAULTS, values || {});
    return new Proxy({
        v: k => all[k] !== undefined ? all[k] : true,
        appsFor: () => [["firefox", "firefox"]],
        kbLayouts: [{ name: "danish", code: "dk" }],
        btConnected: ["WH-1000XM5"],
        screensOn: ["DP-1"],
        monitorNames: ["DP-1", "HDMI-A-1"],
        outputs: [["a", "A"]],
        inputs: [["b", "B"]],
        resolutions: [["1920x1080", "1920 × 1080"]],
        rates: [["60", "60 Hz"]],
        bandChoices: [["", "any"]],
        fonts: ["Monocraft"],
        monoFonts: ["Monocraft"],
        zoneChoices: ["Europe/Copenhagen"],
        branches: ["main"],
        specialNames: [],
        pendingNote: () => ""
    }, {
        get: (target, key) => key in target ? target[key] : typeof key === "string" ? (NUMERIC.has(key) ? 3 : key === "hasBattery" || key === "healthKnown" ? true : "x") : undefined
    });
}

const EXPECTED = [
    ["connections", ["wifi", "bluetooth", "wired", "vpn"]],
    ["sound", ["output", "mic", "mixer", "notifications", "alerts"]],
    ["display", ["screens", "light"]],
    ["look", ["colour", "wallpaper", "type", "shape"]],
    ["desktop", ["sidebar", "windows", "launcher", "clipboard"]],
    ["focus", ["modes", "clock", "screentime"]],
    ["input", ["keyboard", "shortcuts", "pointer", "tablet", "pen"]],
    ["power", ["battery", "powermode", "lock"]],
    ["apps", ["defaults", "startup", "files", "terminal", "capture"]],
    ["system", ["region", "access", "updates", "shell", "about"]]
];

test("the rail is the ten categories of the mockup, each with its pages in order", () => {
    assert.deepStrictEqual(Catalogue.CATS.map(c => [c.id, c.pages.map(p => p.id)]), EXPECTED);
});

test("every page lands in exactly one category", () => {
    const seen = Catalogue.PAGES.map(p => p.id);
    assert.strictEqual(new Set(seen).size, seen.length);
    for (const p of Catalogue.PAGES)
        assert.ok(Catalogue.CAT_BY_ID[p.cat].pages.includes(p));
});

test("every row number from the settings list 1 to 121 has a row", () => {
    const covered = new Set();
    for (const r of Catalogue.ROWS)
        for (const n of [].concat(r.n === undefined ? [] : r.n))
            covered.add(n);
    for (let n = 1; n <= 121; n++)
        assert.ok(covered.has(n), `#${n} has no row`);
});

test("every config key the panel names exists in Config defaults, unless the row is planned", () => {
    for (const r of Catalogue.ROWS)
        if (r.cfg && !r.isNew)
            assert.notStrictEqual(lookup(DEFAULTS, r.cfg), undefined, `${r.page}/${r.k}: ${r.cfg}`);
    for (const k in CONFIG_BACKED)
        assert.notStrictEqual(lookup(DEFAULTS, CONFIG_BACKED[k]), undefined, `${k}: ${CONFIG_BACKED[k]}`);
});

test("rows that name a config key write that same key", () => {
    const special = new Set(["scr:bar", "wallTarget", "level", "warmth", "sheetKeyboard", "sidebar"]);
    for (const r of Catalogue.ROWS)
        if (r.k && r.cfg && !r.isNew && !special.has(r.k))
            assert.strictEqual(CONFIG_BACKED[r.k], r.cfg, `${r.k} shows ${r.cfg} but writes ${CONFIG_BACKED[r.k]}`);
});

test("settings with nothing behind them yet keep a value of their own", () => {
    const served = new Set(["scr:on", "scr:mirror"]);
    for (const r of Catalogue.ROWS)
        if (r.isNew && r.k && !served.has(r.k))
            assert.ok(r.k in PLAN_DEFAULTS, `${r.k} is new but has no planned default`);
});

test("every planned setting has a ticket in the backend plan", () => {
    const dir = path.join(ROOT, ".scratch/settings-backends");
    const plan = [fs.readFileSync(path.join(dir, "spec.md"), "utf8")].concat(fs.readdirSync(path.join(dir, "issues")).map(f => fs.readFileSync(path.join(dir, "issues", f), "utf8"))).join("\n");
    for (const r of Catalogue.ROWS) {
        if (!r.isNew)
            continue;
        const names = r.k ? [`\`${r.k}\``] : r.kind === "w" ? [`\`${r.w}\``, Catalogue.labelOf(r)] : [r.label];
        assert.ok(names.some(n => plan.includes(n)), `${r.page}: ${names[0]} is planned but no ticket names it`);
    }
});

test("a setting is either planned or written to config, never both", () => {
    for (const k in CONFIG_BACKED)
        assert.ok(!(k in PLAN_DEFAULTS), `${k} has a planned default and a config key`);
});

test("what NetworkManager owns is never kept as a planned value, and no password is stored", () => {
    for (const k of ["hotspot", "hotspotName", "hotspotPass", "hotspotBand", "tunnels"])
        assert.ok(!(k in PLAN_DEFAULTS), `${k} is NetworkManager's, not a planned value`);
    for (const k of ["hotspot", "hotspotName", "hotspotPass", "hotspotBand", "vpnFirst"])
        assert.ok(!(k in CONFIG_BACKED), `${k} must not be written to config.json`);
});

test("planned settings are not config keys yet", () => {
    for (const r of Catalogue.ROWS)
        if (r.isNew && r.k)
            assert.ok(!(r.k in CONFIG_BACKED), `${r.k} is planned but SettingsState writes it to config`);
});

test("every widget and every preview has its file", () => {
    const cap = s => s.charAt(0).toUpperCase() + s.slice(1);
    for (const r of Catalogue.ROWS)
        if (r.kind === "w")
            assert.ok(fs.existsSync(path.join(SETTINGS, "widgets", `${cap(r.w)}Widget.qml`)), `widget ${r.w}`);
    for (const c of Catalogue.CATS)
        assert.ok(fs.existsSync(path.join(SETTINGS, "scenes", `${cap(c.preview)}Scene.qml`)), `scene ${c.preview}`);
    for (const p of Catalogue.PAGES)
        assert.ok(fs.existsSync(path.join(SETTINGS, "scenes", `${cap(p.preview)}Scene.qml`)), `scene ${p.preview}`);
});

test("statuses, blurbs, details and options all render against a live state", () => {
    const s = fakeState();
    for (const c of Catalogue.CATS) {
        assert.strictEqual(typeof c.blurb(s), "string", c.id);
        c.suggest(s);
        for (const t of c.tiles)
            if (t.det)
                assert.strictEqual(typeof t.det(s), "string", `${c.id}/${t.k}`);
    }
    for (const p of Catalogue.PAGES)
        assert.strictEqual(typeof p.status(s), "string", p.id);
    for (const r of Catalogue.ROWS) {
        Catalogue.val(r.detail, s);
        if (r.dis)
            r.dis(s);
        if (r.o)
            for (const o of Catalogue.options(r, s))
                assert.strictEqual(o.length, 2, `${r.k} option`);
    }
});

test("option pairs survive being handed over as array-likes", () => {
    const row = { o: [{ 0: true, 1: "forward", length: 2 }, { 0: false, 1: "back", length: 2 }] };
    assert.deepStrictEqual(Catalogue.options(row, {}), [[true, "forward"], [false, "back"]]);
    assert.deepStrictEqual(Catalogue.options({ o: ["move", "swap"] }, {}), [["move", "move"], ["swap", "swap"]]);
});

test("search matches labels, keywords and config keys, and takes a list number", () => {
    assert.strictEqual(Catalogue.search("").length, 0);
    assert.strictEqual(Catalogue.search("snooze")[0].label, "Snooze");
    assert.ok(Catalogue.search("106").every(h => h.nums.includes(106)));
    assert.ok(Catalogue.search("106").length > 0);
    assert.ok(Catalogue.search("clock.cloud").some(h => h.row.cfg === "clock.cloud"));
    assert.ok(Catalogue.search("charge limit").some(h => h.page.id === "battery"));
    assert.ok(Catalogue.search("volume").length <= 12);
    assert.strictEqual(Catalogue.search("nothing like this at all").length, 0);
});

test("resolve takes categories, pages, old names, row keys and config keys", () => {
    assert.deepStrictEqual(Catalogue.resolve("connections"), { cat: "connections", page: "", row: null });
    assert.strictEqual(Catalogue.resolve("wifi").page, "wifi");
    assert.strictEqual(Catalogue.resolve("monitors").page, "screens");
    assert.strictEqual(Catalogue.resolve("keybinds").page, "shortcuts");
    assert.strictEqual(Catalogue.resolve("snooze").row.k, "snooze");
    assert.strictEqual(Catalogue.resolve("windows.edge").page, "windows");
    assert.strictEqual(Catalogue.resolve("not a page"), null);
});

test("values read the way the rows say them", () => {
    const s = fakeState();
    const row = k => Catalogue.ROW_BY_KEY[k];
    assert.strictEqual(Catalogue.show(row("wifi"), true, s), "on");
    assert.strictEqual(Catalogue.show(row("volStep"), 0.05, s), "5%");
    assert.strictEqual(Catalogue.format(row("snooze"), 9, s), "9 min");
    assert.strictEqual(Catalogue.format(row("surfaceAlpha"), 0.88, s), "12%");
    assert.strictEqual(Catalogue.format(row("wallReveal"), 0, s), "cut");
    assert.strictEqual(Catalogue.format(row("mouseSpeed"), 0, s), "as is");
    assert.strictEqual(Catalogue.format(row("warmth"), 0, s), "off");
});

test("steps stay inside the range and off the float crumbs", () => {
    const r = Catalogue.ROW_BY_KEY.clipMax;
    assert.strictEqual(Catalogue.step(r, 2000, 1), 2000);
    assert.strictEqual(Catalogue.step(r, 50, -1), 50);
    assert.strictEqual(Catalogue.step(Catalogue.ROW_BY_KEY.iconScale, 1.1, 1), 1.15);
    assert.strictEqual(Catalogue.nearest(Catalogue.ROW_BY_KEY.wallFit, 1.27), 1.25);
});

test("pages count the settings they cover and the new ones among them", () => {
    assert.deepStrictEqual(Catalogue.pagesCovered(Catalogue.PAGE_BY_ID.wifi), { settings: 7, fresh: 0 });
    assert.strictEqual(Catalogue.pagesCovered(Catalogue.PAGE_BY_ID.vpn).fresh, 0);
});

test("sidebar rows point the replica at the part they change", () => {
    assert.strictEqual(Catalogue.zoneOf(Catalogue.ROW_BY_KEY.sbClock), "clock");
    assert.strictEqual(Catalogue.zoneOf(Catalogue.ROW_BY_KEY.trayMax), "tray");
    assert.strictEqual(Catalogue.zoneOf(Catalogue.ROW_BY_KEY.sidebarW), "");
    assert.strictEqual(Catalogue.zoneOf(null), "");
});

test("modes only change settings that exist", () => {
    for (const m of Catalogue.MODES)
        for (const k of Object.keys(m.set))
            assert.ok(Catalogue.ROW_BY_KEY[k], `${m.id} sets ${k}`);
});

test("dwindle splits the last window each time", () => {
    assert.deepStrictEqual(Catalogue.dwindleRects(1), [{ x: 0, y: 0, w: 100, h: 100 }]);
    const three = Catalogue.dwindleRects(3);
    assert.strictEqual(three.length, 3);
    assert.strictEqual(three[0].w, 49);
    assert.strictEqual(three[1].x, 51);
    assert.strictEqual(three[2].y, 51);
});

test("the niagara thumb rests, travels the alphabet and lets go", () => {
    assert.strictEqual(Catalogue.niagaraAt(0), null);
    assert.strictEqual(Catalogue.niagaraAt(1000), 1);
    assert.strictEqual(Catalogue.niagaraAt(6599), null);
    assert.strictEqual(Catalogue.bowAt(5, null, 34, 4.5), 0);
    assert.strictEqual(Catalogue.bowAt(5, 5, 34, 4.5), 1);
    assert.strictEqual(Catalogue.bowAt(20, 5, 34, 4.5), 0);
});

test("built-in boards parse from KLE and the ISO enter has its second rectangle", () => {
    assert.strictEqual(Boards.board("ansi").length, 61);
    const iso = Boards.board("iso");
    const enter = iso.find(k => k.label === "Enter");
    assert.strictEqual(enter.h, 2);
    assert.strictEqual(enter.w2, 1.5);
    assert.strictEqual(Boards.rects(iso).length, iso.length + 1);
    assert.deepStrictEqual(Boards.extent(Boards.board("ansi")), { cols: 15, rows: 5 });
    assert.ok(Boards.extent(Boards.board("split")).cols > 15);
});

test("a VIA file is read, and a wrong file says why", () => {
    const sample = Boards.readVia(JSON.stringify(Boards.SAMPLE_VIA));
    assert.strictEqual(sample.name, "sample 65%");
    assert.ok(sample.keys.every(k => k.label === ""));
    assert.throws(() => Boards.readVia("{"), /isn’t JSON/);
    assert.throws(() => Boards.readVia("{}"), /no layouts.keymap/);
    assert.throws(() => Boards.readVia(JSON.stringify({ layouts: { keymap: [] } })), /no keys/);
});

test("bound keys light up on the board", () => {
    const keys = Boards.board("ansi");
    const lit = Boards.lit(keys, ["super v", "ctrl shift s"]);
    const on = keys.filter((k, i) => lit[i]).map(k => k.label.toLowerCase());
    assert.ok(on.includes("super") && on.includes("v") && on.includes("shift") && on.includes("s"));
});

test("keyframe curves start at 0, end at 1 and hold between frames", () => {
    for (const curve of [Frames.STANDARD, Frames.ARRIVE]) {
        assert.strictEqual(curve(0), 0);
        assert.strictEqual(curve(1), 1);
        assert.ok(Math.abs(curve(0.5) - 0.5) < 0.5);
    }
    assert.ok(Frames.BACK(0.7) > 1);
    const frames = [[[0, 20], { x: 0 }], [[60, 100], { x: 10 }]];
    assert.strictEqual(Frames.at(frames, 0.1).x, 0);
    assert.strictEqual(Frames.at(frames, 0.8).x, 10);
    const mid = Frames.at(frames, 0.4, x => x).x;
    assert.ok(Math.abs(mid - 5) < 1e-9);
    assert.ok(Math.abs(Frames.pulse(1.5, 0.5, 2) - 0.5) < 1e-9);
});

const DESK = [
    Screens.rectOf("DP-1", { mode: "1920x1200@59.95", position: "0x0", scale: 1, transform: 1 }),
    Screens.rectOf("HDMI-A-1", { mode: "5120x1440@143.99", position: "1200x240", scale: 1, transform: 0 })
];

test("a screen's size on the desk follows its mode, scale and turn", () => {
    assert.deepStrictEqual([DESK[0].w, DESK[0].h, DESK[0].hz], [1200, 1920, 60]);
    assert.deepStrictEqual([DESK[1].x, DESK[1].y, DESK[1].w, DESK[1].h], [1200, 240, 5120, 1440]);
    const scaled = Screens.rectOf("eDP-1", { mode: "2880x1800@120", position: "-1440x-900", scale: 2, transform: 0 });
    assert.deepStrictEqual([scaled.x, scaled.y, scaled.w, scaled.h], [-1440, -900, 1440, 900]);
    assert.deepStrictEqual(Screens.issues(DESK), { clash: [], loose: [] });
});

test("dragging snaps to edges and centres within reach, and leaves it alone outside", () => {
    const near = Screens.snap(DESK, "HDMI-A-1", 1206, 236, 20);
    assert.deepStrictEqual([near.x, near.y], [1200, 240]);
    assert.ok(near.guides.some(g => g.axis === "x" && g.at === 1200 && g.kind === "edge"));
    assert.ok(near.guides.some(g => g.axis === "y" && g.at === 960 && g.kind === "centre"));
    const far = Screens.snap(DESK, "HDMI-A-1", 1300, 600, 20);
    assert.deepStrictEqual([far.x, far.y, far.guides.length], [1300, 600, 0]);
});

test("lining up corner to corner marks the corner", () => {
    const s = Screens.snap(DESK, "HDMI-A-1", 1195, 4, 20);
    assert.deepStrictEqual([s.x, s.y], [1200, 0]);
    assert.deepStrictEqual(s.corner, { x: 1200, y: 0 });
});

test("a dropped screen that floats or overlaps settles against the nearest edge", () => {
    const over = Screens.settle(DESK, "HDMI-A-1", 600, 240, 20);
    const placed = Screens.rectOf("HDMI-A-1", { mode: "5120x1440@144", position: `${over.x}x${over.y}` });
    assert.ok(!Screens.overlaps(placed, DESK[0]));
    assert.ok(Screens.contact(placed, DESK[0]) > 0);
    const left = Screens.settle(DESK, "HDMI-A-1", -5300, 300, 20);
    assert.strictEqual(left.x, -5120);
    const kept = Screens.settle(DESK, "HDMI-A-1", 1200, 300, 20);
    assert.deepStrictEqual(kept, { x: 1200, y: 300 });
});

test("arrows nudge but never push one screen into another", () => {
    assert.strictEqual(Screens.nudge(DESK, "HDMI-A-1", -1, 0), null);
    assert.deepStrictEqual(Screens.nudge(DESK, "HDMI-A-1", 0, 10), { x: 1200, y: 250 });
    assert.deepStrictEqual(Screens.nudge(DESK, "HDMI-A-1", 1, 0), { x: 1201, y: 240 });
});

test("turning a screen keeps it centred and pushes what sat to its right", () => {
    const fresh = Screens.rectOf("DP-1", { mode: "1920x1200@60", position: "0x0", scale: 1, transform: 0 });
    assert.deepStrictEqual(Screens.resize(DESK, "DP-1", fresh), { "DP-1": { x: 0, y: 360 }, "HDMI-A-1": { x: 1920, y: 240 } });
});

test("the view fits every screen inside its padding", () => {
    const view = Screens.fit(DESK, 800, 400, 40);
    assert.ok(view.ox + 0 * view.k >= 39.9 && view.ox + 6320 * view.k <= 760.1);
    assert.ok(view.oy + 0 * view.k >= 39.9 && view.oy + 1920 * view.k <= 360.1);
});

test("a desktop without a battery or a lid hides what it can't use", () => {
    const mains = fakeState({});
    const desk = new Proxy(mains, { get: (t, k) => k === "hasBattery" || k === "hasLid" ? false : t[k] });
    const laptop = new Proxy(mains, { get: (t, k) => k === "hasBattery" || k === "hasLid" ? true : t[k] });
    const power = Catalogue.PAGE_BY_ID.powermode;
    assert.strictEqual(Catalogue.nameOf(power, desk), "Power");
    assert.strictEqual(Catalogue.nameOf(power, laptop), "Power and lid");
    assert.ok(!Catalogue.present(Catalogue.PAGE_BY_ID.battery, desk));
    assert.ok(Catalogue.present(Catalogue.PAGE_BY_ID.battery, laptop));
    assert.deepStrictEqual(power.groups.filter(g => Catalogue.present(g, desk)).map(g => g.t || ""), [""]);
    assert.strictEqual(power.status(desk), desk.v("profile"));
    assert.ok(Catalogue.CAT_BY_ID.power.tiles.filter(t => Catalogue.present(t, desk)).every(t => t.k !== "chargeLimit"));
});

test("screen rows that wait for apply say so", () => {
    for (const k of ["scr:res", "scr:hz", "scr:scale", "scr:rot", "scr:vrr"]) {
        const r = Catalogue.ROWS.find(x => x.k === k);
        assert.strictEqual(r.detail({ pendingNote: () => "not applied yet" }), "not applied yet", k);
    }
});
