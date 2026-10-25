const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/tour.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Tour = new Function(`${src}\nreturn { parseState, formatState, shouldStart, chordFor, keyText, plan, current, begin, observe, pass, words, place, sidebarOf, closing, tokens, tail };`)();

const rows = fs.readFileSync(path.join(ROOT, "api/actions.tsv"), "utf8").split("\n")
    .filter(line => line && !line.startsWith("#"))
    .map(line => {
        const [id, , , argv] = line.split("\t");
        return { id, argv };
    });

const bind = (expr, mask, key, extra) => Object.assign({ expr, cmd: "", submap: "", dynamic: false, presses: [{ mask, key }] }, extra);
const exec = (cmd, mask, key) => bind(`hl.dsp.exec_cmd("${cmd}")`, mask, key, { cmd });

test("a fresh config with no tour record starts the tour", () => {
    assert.strictEqual(Tour.shouldStart(true, Tour.parseState("")), true);
});

test("an existing config never starts the tour unprompted", () => {
    assert.strictEqual(Tour.shouldStart(false, Tour.parseState("")), false);
    assert.strictEqual(Tour.shouldStart(false, Tour.parseState("not json")), false);
});

test("a tour that ran or was skipped does not come back, even on a fresh config", () => {
    for (const status of ["done", "skipped"])
        assert.strictEqual(Tour.shouldStart(true, Tour.parseState(Tour.formatState({ status, done: [] }))), false);
});

test("a tour cut off by a reload picks up where it was", () => {
    const state = Tour.parseState(Tour.formatState({ status: "running", done: ["launcher", "island"] }));
    assert.strictEqual(Tour.shouldStart(false, state), true);
    assert.deepStrictEqual(state.done, ["launcher", "island"]);
});

test("the state file drops unknown steps and unknown statuses", () => {
    assert.deepStrictEqual(Tour.parseState('{"status":"weird","done":["launcher","nope",3]}'), { status: "none", done: ["launcher"] });
    assert.deepStrictEqual(Tour.parseState("[1,2]"), { status: "none", done: [] });
});

test("finds the chord a bind gives each step, in every spelling a bind uses", () => {
    const binds = [
        bind("hl.dsp.global(\"banditshell:launcher\")", 64, "SPACE"),
        bind("bs.panel.island.toggle", 65, "M"),
        exec("banditshell panel hotkeys toggle", 65, "Slash"),
        exec("$HOME/bin/banditshell action panel.settings.toggle", 64, "i")
    ];
    assert.strictEqual(Tour.chordFor("launcher", binds, rows), "Super + Space");
    assert.strictEqual(Tour.chordFor("island", binds, rows), "Super + Shift + M");
    assert.strictEqual(Tour.chordFor("hotkeys", binds, rows), "Super + Shift + /");
    assert.strictEqual(Tour.chordFor("settings", binds, rows), "Super + I");
    assert.strictEqual(Tour.chordFor("launcher", [bind("bs.action(\"launcher.toggle\")", 8, "d")], rows), "Alt + D");
});

test("ignores binds that only look alike", () => {
    const binds = [
        exec("banditshell panel launcher close", 64, "space"),
        exec("notbanditshell panel launcher toggle", 64, "x"),
        bind("bs.launcher.toggle", 64, "z", { submap: "resize" }),
        bind("bs.launcher.toggle", 64, "mouse:272"),
        bind("bs.launcher.toggle", 64, "y", { dynamic: true })
    ];
    assert.strictEqual(Tour.chordFor("launcher", binds, rows), "");
    assert.strictEqual(Tour.chordFor("sidebar", binds, rows), "");
});

test("a step with no bind never names a key", () => {
    const steps = Tour.plan({ bare: false, sidebar: "rail", chords: {} });
    for (const step of steps) {
        const said = Tour.words(step, {});
        assert.ok(!/Press [A-Z]/.test(said.ask.replace("Press into", "")), `${step.id} names a key: ${said.ask}`);
    }
});

test("every step says the payoff before the ask", () => {
    const steps = Tour.plan({ bare: false, sidebar: "rail", chords: { launcher: "Super + Space" } });
    for (const step of steps) {
        const said = Tour.words(step, { apps: 40, binds: 12, workspaces: 4 });
        assert.ok(said.title && said.payoff && said.ask && said.away, step.id);
    }
});

test("plans five steps and drops the sidebar when there is none", () => {
    assert.deepStrictEqual(Tour.plan({ bare: false, sidebar: "rail", chords: {} }).map(s => s.id), ["launcher", "island", "sidebar", "hotkeys", "settings"]);
    assert.deepStrictEqual(Tour.plan({ bare: true, sidebar: "none", chords: {} }).map(s => s.id), ["launcher", "island", "hotkeys", "settings"]);
});

test("every step offers one button that opens the thing itself", () => {
    for (const sidebar of ["rail", "full"])
        for (const step of Tour.plan({ bare: false, sidebar, chords: {} }))
            assert.match(Tour.words(step, {}).open, /^(Open|Show) /, step.id);
});

test("a chord stays one piece, with the word before it and the punctuation after it", () => {
    const said = Tour.tokens("Press Super + Shift + /, or drag up.", "Super + Shift + /");
    assert.deepStrictEqual(said[0], { text: "Super + Shift + /", kind: "key", before: "Press", after: "," });
    assert.deepStrictEqual(said.slice(1).map(t => t.text), ["or", "drag", "up."]);
});

test("words to type are marked as typed text", () => {
    const said = Tour.tokens(Tour.closing("", false).again, "");
    assert.deepStrictEqual(said.filter(t => t.kind === "typed").map(t => t.text), ["tour"]);
    assert.ok(!said.some(t => t.text.includes("`") || t.after.includes("`")));
});

test("the finished card leads with the launcher's own key, and names none without a bind", () => {
    assert.match(Tour.closing("Super + Space", false).now, /^Press Super \+ Space /);
    assert.ok(!/Press [A-Z]/.test(Tour.closing("", false).now));
    assert.ok(!/Press [A-Z]/.test(Tour.closing("", true).now));
});

test("the card's pointer aims at the middle of its target and stays on the card", () => {
    const card = { w: 440, h: 260 };
    const rail = { x: 0, y: 0, w: 250, h: 1080 };
    assert.deepStrictEqual(Tour.tail({ x: 266, y: 410, side: "right" }, card, rail), { edge: "left", at: 130 });
    const corner = Tour.tail({ x: 1400, y: 800, side: "leftBottom" }, card, { x: 1860, y: 1020, w: 60, h: 60 });
    assert.strictEqual(corner.edge, "right");
    assert.ok(corner.at <= card.h && corner.at >= 0);
    assert.strictEqual(Tour.tail({ x: 0, y: 0, side: "centre" }, card, rail).edge, "");
});

const steps = Tour.plan({ bare: false, sidebar: "rail", chords: {} });
const none = { launcher: false, island: false, sidebar: false, hotkeys: false, settings: false };
const open = id => Object.assign({}, none, { [id]: true });

test("a step moves on once its surface was summoned and put away", () => {
    let m = Tour.begin([]);
    m = Tour.observe(m, steps, none, open("launcher"));
    assert.strictEqual(m.phase, "seen");
    assert.strictEqual(Tour.current(steps, m.done).id, "launcher");
    m = Tour.observe(m, steps, open("launcher"), none);
    assert.strictEqual(m.phase, "ask");
    assert.strictEqual(Tour.current(steps, m.done).id, "island");
});

test("summoning a later step first counts it, and summoning an earlier one changes nothing", () => {
    let m = Tour.begin(["launcher"]);
    m = Tour.observe(m, steps, none, open("settings"));
    assert.deepStrictEqual(m.done, ["launcher", "settings"]);
    assert.strictEqual(m.phase, "ask");
    m = Tour.observe(Tour.begin(["launcher", "island"]), steps, none, open("launcher"));
    assert.deepStrictEqual(m.done, ["launcher", "island"]);
    assert.strictEqual(Tour.current(steps, m.done).id, "sidebar");
});

test("a surface already open when its step comes up does not count until it is summoned again", () => {
    const m = Tour.observe(Tour.begin([]), steps, open("launcher"), open("launcher"));
    assert.strictEqual(m.phase, "ask");
});

test("skipping a step moves on, and the last one finishes the tour", () => {
    let m = Tour.begin([]);
    for (let i = 0; i < steps.length - 1; i++)
        m = Tour.pass(m, steps);
    assert.strictEqual(Tour.current(steps, m.done).id, "settings");
    m = Tour.pass(m, steps);
    assert.strictEqual(m.phase, "finished");
    assert.strictEqual(Tour.observe(m, steps, none, open("launcher")).phase, "finished");
});

const overlaps = (a, b) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;

test("the card sits beside what it introduces, never on it", () => {
    const bounds = { x: 10, y: 10, w: 1900, h: 1060 };
    const card = { w: 380, h: 200 };
    const cases = [
        { target: { x: 535, y: 400, w: 850, h: 670 }, sides: ["rightBottom", "leftBottom"] },
        { target: { x: 1600, y: 400, w: 300, h: 670 }, sides: ["rightBottom", "leftBottom"] },
        { target: { x: 0, y: 0, w: 250, h: 1080 }, sides: ["right"] },
        { target: { x: 1820, y: 980, w: 100, h: 100 }, sides: ["above", "left"] }
    ];
    for (const c of cases) {
        const spot = Tour.place(card, c.target, bounds, c.sides, [], 16);
        assert.ok(!overlaps({ x: spot.x, y: spot.y, w: card.w, h: card.h }, c.target), JSON.stringify(c.target));
        assert.ok(spot.x >= bounds.x && spot.x + card.w <= bounds.x + bounds.w);
    }
});

test("the card keeps clear of a panel it was told to avoid", () => {
    const bounds = { x: 10, y: 10, w: 1900, h: 1060 };
    const card = { w: 380, h: 200 };
    const settings = { x: 30, y: 140, w: 1300, h: 830 };
    const spot = Tour.place(card, { x: 1820, y: 980, w: 100, h: 100 }, bounds, ["left", "above"], [settings], 16);
    assert.ok(!overlaps({ x: spot.x, y: spot.y, w: card.w, h: card.h }, settings));
});

test("a tour that reached its end before a reload comes back as the finished card, not an empty step", () => {
    const m = Tour.begin(steps.map(s => s.id), steps);
    assert.strictEqual(m.phase, "finished");
    assert.strictEqual(Tour.begin(["launcher"], steps).phase, "ask");
});

test("the sidebar step follows whether any screen has a sidebar, not which screen has focus", () => {
    assert.strictEqual(Tour.sidebarOf({ "DP-1": "none", "HDMI-A-1": "rail" }), "rail");
    assert.strictEqual(Tour.sidebarOf({ "DP-1": "full", "HDMI-A-1": "none" }), "full");
    assert.strictEqual(Tour.sidebarOf({ "DP-1": "none" }), "none");
    assert.strictEqual(Tour.sidebarOf({}), "none");
});

test("every side the card can take has an arrow and a spot", () => {
    const card = { w: 100, h: 50 };
    const bounds = { x: 0, y: 0, w: 1000, h: 1000 };
    const target = { x: 400, y: 400, w: 100, h: 100 };
    for (const side of ["right", "left", "above", "below", "rightTop", "rightBottom", "leftTop", "leftBottom", "centre"])
        assert.strictEqual(Tour.place(card, target, bounds, [side], [], 10).side, side, side);
});
