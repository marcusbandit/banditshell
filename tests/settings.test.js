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

const Catalogue = lib(path.join(SETTINGS, "catalogue.js"), ["CATS", "PAGES", "PAGE_BY_ID", "CAT_BY_ID", "ROWS", "ROW_BY_KEY", "MODES", "LAYOUTS", "INDEX", "search", "resolve", "options", "format", "show", "step", "nearest", "labelOf", "dwindleRects", "alphabetThumbAt", "bowAt", "zoneOf", "pagesCovered", "val", "present", "nameOf"]);
const Screens = lib(path.join(SETTINGS, "screens.js"), ["rectOf", "overlaps", "contact", "issues", "snap", "settle", "anchor", "nudge", "resize", "fit"]);
const Boards = lib(path.join(SETTINGS, "boards.js"), ["BOARDS", "SAMPLE_VIA", "kle", "extent", "rects", "board", "lit", "struck", "fromSheet"]);
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
    const all = Object.assign({}, PLAN_DEFAULTS, { mode: "none" }, values || {});
    return new Proxy({
        v: k => all[k] !== undefined ? all[k] : true,
        appsFor: () => [["firefox", "firefox"]],
        defaultName: k => k,
        defaultNote: () => "",
        kbLayouts: [{ name: "danish", code: "dk" }],
        touchpads: [{ label: "Touchpad" }],
        btConnected: ["WH-1000XM5"],
        screensOn: ["DP-1"],
        monitorNames: ["DP-1", "HDMI-A-1"],
        mirrorChoices: ["HDMI-A-1"],
        outputs: [["a", "A"]],
        inputs: [["b", "B"]],
        resolutions: [["1920x1080", "1920 × 1080"]],
        rates: [["60", "60 Hz"]],
        bandChoices: [["", "any"]],
        fonts: ["Monocraft"],
        monoFonts: ["Monocraft"],
        zoneChoices: ["Europe/Copenhagen"],
        languageChoices: [["en_GB.UTF-8", "English (UK)"]],
        formatChoices: [["da_DK.UTF-8", "Denmark"]],
        dateChoices: [["slashes", "14/10/2026"]],
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

test("every config key the panel names exists in Config defaults", () => {
    for (const r of Catalogue.ROWS)
        if (r.cfg)
            assert.notStrictEqual(lookup(DEFAULTS, r.cfg), undefined, `${r.page}/${r.k}: ${r.cfg}`);
    for (const k in CONFIG_BACKED)
        assert.notStrictEqual(lookup(DEFAULTS, CONFIG_BACKED[k]), undefined, `${k}: ${CONFIG_BACKED[k]}`);
});

test("nothing waits in the planned store: no default and no row flagged new", () => {
    assert.deepStrictEqual(PLAN_DEFAULTS, {});
    assert.ok(!/\bisNew\b/.test(fs.readFileSync(path.join(SETTINGS, "catalogue.js"), "utf8")));
});

test("rows that name a config key write that same key", () => {
    const special = new Set(["scr:bar", "wallTarget", "level", "warmth", "sheetKeyboard", "sidebar", "autoZone"]);
    for (const r of Catalogue.ROWS)
        if (r.k && r.cfg && !special.has(r.k))
            assert.strictEqual(CONFIG_BACKED[r.k], r.cfg, `${r.k} shows ${r.cfg} but writes ${CONFIG_BACKED[r.k]}`);
});

test("the island's Change place opens the row that writes weather.location", () => {
    const Forecast = lib(path.join(ROOT, "services/weather.js"), ["failureLook"]);
    const fix = Forecast.failureLook("place").fix;
    const found = Catalogue.resolve(fix.row);
    assert.strictEqual(found.page, fix.page);
    assert.strictEqual(found.row.cfg, "weather.location");
    assert.strictEqual(CONFIG_BACKED[found.row.k], "weather.location");
});

test("the weather rows grey out while the weather is off", () => {
    const rows = ["weatherPlace", "weatherUnits", "weatherMinutes"].map(k => Catalogue.ROW_BY_KEY[k]);
    for (const r of rows) {
        assert.strictEqual(r.dis(fakeState({ weatherShow: false })), true, r.k);
        assert.strictEqual(r.dis(fakeState({ weatherShow: true })), false, r.k);
    }
});

test("what NetworkManager owns is never written to config, and no password is stored", () => {
    for (const k of ["hotspot", "hotspotName", "hotspotPass", "hotspotBand", "vpnFirst"])
        assert.ok(!(k in CONFIG_BACKED), `${k} must not be written to config.json`);
});

test("night light, region and accessibility rows write to config", () => {
    for (const k of ["nightSched", "warmFrom", "warmTo", "clock24", "dateFormat", "reduceMotion", "largerText", "contrast"])
        assert.ok(k in CONFIG_BACKED, `${k} writes to config`);
});

test("the new config keys start where the panel's planned values did, and dates keep the shell's old look", () => {
    assert.deepStrictEqual([lookup(DEFAULTS, "screen.schedule"), lookup(DEFAULTS, "screen.warmFrom"), lookup(DEFAULTS, "screen.warmTo")], ["off", "21:00", "07:00"]);
    assert.deepStrictEqual([lookup(DEFAULTS, "region.clock24"), lookup(DEFAULTS, "region.dateFormat")], [true, "words"]);
    assert.deepStrictEqual([lookup(DEFAULTS, "access.lessMotion"), lookup(DEFAULTS, "access.largerText"), lookup(DEFAULTS, "access.moreContrast")], [false, false, false]);
    assert.strictEqual(lookup(DEFAULTS, "access.largerBase"), 11);
    assert.deepStrictEqual(lookup(DEFAULTS, "access.contrastLabel"), [0.96, 0.8, 0.68, 0.24]);
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

test("dark, dark mode, light, night and theme all find the dark apps row", () => {
    for (const q of ["dark", "dark mode", "light", "night", "theme"])
        assert.ok(Catalogue.search(q).some(h => h.row.k === "darkMode" && h.page.id === "colour"), q);
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
    assert.deepStrictEqual(Catalogue.pagesCovered(Catalogue.PAGE_BY_ID.wifi), { settings: 7 });
});

test("sidebar rows point the replica at the part they change", () => {
    assert.strictEqual(Catalogue.zoneOf(Catalogue.ROW_BY_KEY.sbClock), "clock");
    assert.strictEqual(Catalogue.zoneOf(Catalogue.ROW_BY_KEY.trayMax), "tray");
    assert.strictEqual(Catalogue.zoneOf(Catalogue.ROW_BY_KEY.sidebarW), "");
    assert.strictEqual(Catalogue.zoneOf(null), "");
});

test("the sidebar style row offers full and rail and defaults to rail", () => {
    const row = Catalogue.ROW_BY_KEY.sbStyle;
    assert.strictEqual(row.cfg, "sidebar.style");
    assert.deepStrictEqual(row.o, ["full", "rail"]);
    assert.strictEqual(lookup(DEFAULTS, "sidebar.style"), "rail");
    assert.strictEqual(lookup(DEFAULTS, "sidebar.status.brightness"), false);
    assert.strictEqual(CONFIG_BACKED.sbStyle, "sidebar.style");
    assert.strictEqual(Catalogue.zoneOf(Catalogue.ROW_BY_KEY.sbBright), "status");
});

test("notifications in search is a row and stays off by default", () => {
    assert.strictEqual(Catalogue.ROW_BY_KEY.notificationsInSearch.cfg, "launcher.typing.notifications");
    assert.strictEqual(lookup(DEFAULTS, "launcher.typing.notifications"), false);
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

test("the alphabet thumb rests, travels the alphabet and lets go", () => {
    assert.strictEqual(Catalogue.alphabetThumbAt(0), null);
    assert.strictEqual(Catalogue.alphabetThumbAt(1000), 1);
    assert.strictEqual(Catalogue.alphabetThumbAt(6599), null);
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

test("bound keys light up on the board", () => {
    const keys = Boards.board("ansi");
    const lit = Boards.lit(keys, ["super v", "ctrl shift s"]);
    const on = keys.filter((k, i) => lit[i]).map(k => k.label.toLowerCase());
    assert.ok(on.includes("super") && on.includes("v") && on.includes("shift") && on.includes("s"));
});

test("the sheet shape lives in config", () => {
    assert.strictEqual(CONFIG_BACKED.sheetShape, "cheatsheet.shape");
    assert.strictEqual(lookup(DEFAULTS, "cheatsheet.shape"), "iso");
    assert.strictEqual(lookup(DEFAULTS, "cheatsheet.keymap"), "");
    const row = Catalogue.ROW_BY_KEY.sheetKeyboard;
    assert.deepStrictEqual(row.o.map(o => o[0]), ["iso", "ansi", "file"]);
    assert.deepStrictEqual(row.o.map(o => o[1]), ["ISO", "ANSI", "Custom"]);
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
    for (const k of ["scr:on", "scr:mirror", "scr:res", "scr:hz", "scr:scale", "scr:rot", "scr:vrr"]) {
        const r = Catalogue.ROWS.find(x => x.k === k);
        assert.strictEqual(r.detail({ pendingNote: () => "not applied yet", onlyOn: false }), "not applied yet", k);
    }
});

test("the idle rows keep minutes in config and every choice survives the trip", () => {
    const Durations = lib(path.join(SETTINGS, "durations.js"), ["minutesFromChoice", "choiceFromMinutes"]);
    const keys = { idleLock: "idle.lock", idleOff: "idle.screensOff", idleSuspend: "idle.sleep" };
    for (const [k, cfg] of Object.entries(keys)) {
        const row = Catalogue.ROW_BY_KEY[k];
        assert.strictEqual(row.cfg, cfg);
        assert.strictEqual(CONFIG_BACKED[k], cfg);
        assert.strictEqual(typeof lookup(DEFAULTS, cfg), "number");
        for (const [choice] of Catalogue.options(row, fakeState()))
            assert.strictEqual(Durations.choiceFromMinutes(Durations.minutesFromChoice(choice)), choice, `${k}: ${choice}`);
    }
});

test("screens that are off or mirrored take no room on the desk", () => {
    const off = Screens.rectOf("DP-1", { mode: "1920x1200@60", position: "600x0", disabled: true });
    const mirror = Screens.rectOf("DP-2", { mode: "1920x1080@60", position: "0x0", mirror: "HDMI-A-1" });
    const wide = Screens.rectOf("HDMI-A-1", { mode: "5120x1440@144", position: "0x0" });
    assert.deepStrictEqual([off.off, mirror.mirror, wide.off, wide.mirror], [true, "HDMI-A-1", false, ""]);
    assert.deepStrictEqual(Screens.issues([wide, off, mirror]), { clash: [], loose: [] });
    assert.deepStrictEqual(Screens.snap([wide, off], "HDMI-A-1", 590, 0, 20), { x: 590, y: 0, guides: [], corner: null });
});

test("the power rows are served by config or by the system", () => {
    const backed = { chargeLimit: "battery.holdCharge", chargeMax: "battery.holdAt", lowWarn: "battery.warnAt", lowAction: "battery.nearlyEmpty", lidBattery: "power.lid.onBattery", lidPlugged: "power.lid.pluggedIn", lidDocked: "power.lid.docked" };
    for (const [k, cfg] of Object.entries(backed)) {
        const row = Catalogue.ROW_BY_KEY[k];
        assert.strictEqual(row.cfg, cfg, k);
        assert.strictEqual(CONFIG_BACKED[k], cfg, k);
    }
    assert.deepStrictEqual([DEFAULTS.battery.holdCharge, DEFAULTS.battery.holdAt, DEFAULTS.battery.warnAt, DEFAULTS.battery.nearlyEmpty], [true, 80, 15, "nothing"]);
    assert.deepStrictEqual(DEFAULTS.idle, { lock: 0, screensOff: 0, sleep: 0 });
    assert.strictEqual(DEFAULTS.startup.runAutostart, false);
    assert.deepStrictEqual(DEFAULTS.power.lid, { onBattery: "suspend", pluggedIn: "suspend", docked: "nothing" });
    const profile = Catalogue.ROW_BY_KEY.profile;
    assert.ok(!profile.cfg);
    assert.ok(!("profile" in CONFIG_BACKED));
});

test("hibernate is greyed where the machine cannot do it", () => {
    const can = { hibernatePossible: true, nearlyEmptyPercent: 5 };
    const cannot = { hibernatePossible: false, nearlyEmptyPercent: 5 };
    for (const k of ["lidBattery", "lowAction"]) {
        const row = Catalogue.ROW_BY_KEY[k];
        assert.deepStrictEqual(Catalogue.val(row.unavailable, can), [], k);
        const off = Catalogue.val(row.unavailable, cannot);
        assert.strictEqual(off.length, 1, k);
        assert.ok(Catalogue.options(row, cannot).some(o => o[0] === off[0] && /^hibernate/.test(o[0])), k);
    }
    assert.deepStrictEqual(Catalogue.options(Catalogue.ROW_BY_KEY.lowAction, can).map(o => o[1]), ["suspend at 5%", "hibernate at 5%", "nothing"]);
});

test("the power mode row offers what the daemon offers and greys without one", () => {
    const row = Catalogue.ROW_BY_KEY.profile;
    assert.deepStrictEqual(Catalogue.options(row, { profileChoices: ["saver", "balanced"] }).map(o => o[0]), ["saver", "balanced"]);
    assert.strictEqual(row.dis({ profileChoices: [] }), true);
    assert.strictEqual(row.dis({ profileChoices: ["balanced"] }), false);
    const saver = Catalogue.CAT_BY_ID.power.tiles.find(t => t.k === "saver");
    assert.strictEqual(saver.dis({ profileChoices: [] }), true);
});

test("the command line names every mode the panel has", () => {
    const header = fs.readFileSync(path.join(ROOT, "cli/banditshell"), "utf8");
    const line = /banditshell focus mode \[([^\]]+)\]/.exec(header);
    assert.ok(line, "focus mode in the CLI's header");
    assert.deepStrictEqual(line[1].split("|").filter(w => w !== "list"), Catalogue.MODES.map(m => m.id));
});

test("rules are opaque to the schema merge and start empty", () => {
    const opaque = /readonly property var opaque: \[([^\]]*)\]/.exec(fs.readFileSync(path.join(ROOT, "config/Config.qml"), "utf8"));
    assert.ok(opaque[1].includes('"notifications.rules"'));
    assert.deepStrictEqual(lookup(DEFAULTS, "notifications.rules"), {});
});

test("quiet, rules and alert sounds are written to config", () => {
    for (const k of ["dnd", "dndUntil", "dndAlarms", "dndNightly", "rules", "alerts", "alertSet", "alertVol"]) {
        assert.ok(k in CONFIG_BACKED, `${k} is config backed`);
    }
    assert.deepStrictEqual(lookup(DEFAULTS, "sound"), { alerts: false, alertSet: "soft", alertVolume: 0.5 });
});

test("every mode setting can be written by the panel", () => {
    const served = new Set(["profile", "warmth", "level"]);
    for (const m of Catalogue.MODES)
        for (const k of Object.keys(m.set))
            assert.ok(k in CONFIG_BACKED || served.has(k), `${m.id} sets ${k}, which nothing writes`);
});

test("settings Hyprland owns are served by the state: not stored, read and written by case", () => {
    const state = fs.readFileSync(STATE, "utf8");
    for (const k of ["kbDelay", "kbRate", "mouseSpeed", "padSpeed", "naturalScroll", "tapClick", "layout"]) {
        assert.ok(!(k in CONFIG_BACKED), `${k} is stored in config.json`);
        assert.strictEqual(state.split(`case "${k}":`).length - 1, 2, `${k} should be one case in v() and one in write()`);
    }
    for (const k of ["kbDelay", "kbRate", "mouseSpeed", "padSpeed", "naturalScroll", "tapClick"])
        assert.ok(Catalogue.ROW_BY_KEY[k], `${k} has a row`);
});

test("pen buttons are shell keys that default to what the pen already does", () => {
    assert.strictEqual(CONFIG_BACKED.penBtn1, "pen.lowerButton");
    assert.strictEqual(CONFIG_BACKED.penBtn2, "pen.upperButton");
    assert.strictEqual(lookup(DEFAULTS, "pen.lowerButton"), "right click");
    assert.strictEqual(lookup(DEFAULTS, "pen.upperButton"), "middle click");
    for (const k of ["penBtn1", "penBtn2"]) {
        const row = Catalogue.ROW_BY_KEY[k];
        assert.ok(Catalogue.options(row, fakeState()).some(o => o[0] === lookup(DEFAULTS, CONFIG_BACKED[k])), `${k}'s default is one of its choices`);
    }
});

test("an arrangement always starts at 0,0, wherever it was dropped", () => {
    const wide = Screens.rectOf("HDMI-A-1", { mode: "5120x1440@144", position: "10000x-5280" });
    const tall = Screens.rectOf("DP-1", { mode: "1920x1200@60", position: "11040x-6720", transform: 1 });
    assert.deepStrictEqual(Screens.anchor([wide, tall]), { "HDMI-A-1": { x: 0, y: 1440 }, "DP-1": { x: 1040, y: 0 } });
    const home = Screens.rectOf("HDMI-A-1", { mode: "5120x1440@144", position: "0x1440" });
    const above = Screens.rectOf("DP-1", { mode: "1920x1200@60", position: "1040x0", transform: 1 });
    assert.deepStrictEqual(Screens.anchor([home, above]), {});
});

test("screens that are off or mirrored do not pull the arrangement", () => {
    const wide = Screens.rectOf("HDMI-A-1", { mode: "5120x1440@144", position: "300x200" });
    const off = Screens.rectOf("DP-1", { mode: "1920x1200@60", position: "-4000x-4000", disabled: true });
    const copy = Screens.rectOf("DP-2", { mode: "1920x1080@60", position: "-9000x0", mirror: "HDMI-A-1" });
    assert.deepStrictEqual(Screens.anchor([wide, off, copy]), { "HDMI-A-1": { x: 0, y: 0 } });
    assert.deepStrictEqual(Screens.anchor([off]), {});
});

test("the settings preview draws the sheet's own keys, the ISO enter as its two rectangles", () => {
    const keys = Boards.fromSheet([
        { id: "RTRN", cap: "Enter", syms: ["Return"], mod: 0, matrix: "", x: 13.5, y: 2.5, w: 1.5, h: 2, foot: 1.25 },
        { id: "LWIN", cap: "", syms: [], mod: 64, matrix: "", x: 1.25, y: 5.5, w: 1.25, h: 1, foot: 0 },
        { id: "SPCE", cap: "", syms: ["space"], mod: 0, matrix: "", x: 3.75, y: 5.5, w: 6.25, h: 1, foot: 0 }
    ]);
    const [leg, head] = Boards.rects(keys.slice(0, 1)).sort((a, b) => a.h - b.h).reverse();
    assert.deepStrictEqual([leg.x, leg.y, leg.w, leg.h], [13.75, 2.5, 1.25, 2]);
    assert.deepStrictEqual([head.x, head.y, head.w, head.h], [13.5, 2.5, 1.5, 1]);
    assert.strictEqual(Boards.extent(keys.slice(0, 1)).cols, 15);
    assert.strictEqual(keys[1].label, "Super");
    assert.ok(Boards.struck(keys[1], { super: true }));
    assert.strictEqual(keys[2].label, "Space");
    assert.ok(Boards.struck(keys[0], { return: true }));
});
