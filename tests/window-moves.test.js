const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const lib = (file, names) => new Function(`${fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "")}\nreturn { ${names.join(", ")} };`)();

const Moves = lib("services/window-moves.js", ["NUDGE_STEP", "nudgeTarget", "presetId", "remembered", "restoreRect", "presetFrom", "presetPlan", "withPreset", "withoutPreset"]);
const Search = lib("modules/launcher/search.js", ["presetAsk", "streamsForWindow"]);

const mon = { x: 100, y: 50, activeWorkspace: { id: 2 } };
const client = (cls, extra) => Object.assign({ address: `0x${cls}`, class: cls, floating: false, mapped: true, workspace: { id: 2 }, at: [200, 150], size: [800, 600], fullscreen: 0 }, extra);

const screen = { x: 100, y: 50, width: 1000, height: 800, scale: 1, transform: 0, reserved: [0, 0, 0, 0] };

test.describe("nudging a window", () => {
    test.it("steps a floating window by the step in the asked direction", () => {
        const c = client("a", { floating: true });
        assert.deepStrictEqual(Moves.nudgeTarget(c, "l", 40, screen), { x: 160, y: 150 });
        assert.deepStrictEqual(Moves.nudgeTarget(c, "d", 25, screen), { x: 200, y: 175 });
    });

    test.it("stops at the monitor edge instead of pushing the window off it", () => {
        const c = client("a", { floating: true, at: [110, 150] });
        assert.deepStrictEqual(Moves.nudgeTarget(c, "l", 40, screen), { x: 100, y: 150 });
        assert.strictEqual(Moves.nudgeTarget(client("a", { floating: true, at: [100, 150] }), "l", 40, screen), null);
    });

    test.it("leaves tiled and fullscreen windows alone", () => {
        assert.strictEqual(Moves.nudgeTarget(client("a"), "l", 40, screen), null);
        assert.strictEqual(Moves.nudgeTarget(client("a", { floating: true, fullscreen: 1 }), "l", 40, screen), null);
    });
});

test.describe("restoring a window", () => {
    test.it("brings a floating window back to where it was", () => {
        const saved = Moves.remembered(client("a", { floating: true }));
        assert.deepStrictEqual(Moves.restoreRect(saved), { x: 200, y: 150, w: 800, h: 600 });
    });

    test.it("does not remember a window that is already fullscreen, and tiled ones restore by tiling", () => {
        assert.strictEqual(Moves.remembered(client("a", { fullscreen: 2 })), null);
        assert.strictEqual(Moves.restoreRect(Moves.remembered(client("a"))), null);
    });
});

test.describe("window presets", () => {
    test.it("records the windows of the focused workspace relative to the monitor", () => {
        const preset = Moves.presetFrom("Work", "dwindle", mon, [client("kitty", { floating: true }), client("zen", { workspace: { id: 3 } })]);
        assert.deepStrictEqual(preset.windows, [{ class: "kitty", floating: true, x: 100, y: 100, w: 800, h: 600 }]);
        assert.strictEqual(preset.layout, "dwindle");
    });

    test.it("matches each saved window to one open window of the same class", () => {
        const preset = { windows: [{ class: "kitty", floating: true, x: 10, y: 20, w: 300, h: 200 }, { class: "kitty", floating: false }, { class: "gone", floating: false }] };
        const plan = Moves.presetPlan(preset, mon, [client("kitty"), client("zen")]);
        assert.strictEqual(plan.length, 1);
        assert.deepStrictEqual(plan[0].rect, { x: 110, y: 70, w: 300, h: 200 });
    });

    test.it("gives different names different ids, including names without latin letters", () => {
        const ids = ["Ærø", "Rø", "日本", "🎧", "work", "Work!"].map(Moves.presetId);
        assert.strictEqual(new Set(ids.slice(0, 5)).size, 5);
        assert.strictEqual(Moves.presetId("Work"), Moves.presetId("work"));
        assert.ok(ids.every(id => id.length > 0));
    });

    test.it("saving under a name that exists replaces it", () => {
        const first = Moves.withPreset([], { name: "Work", windows: [1] });
        const again = Moves.withPreset(first, { name: "work", windows: [2] });
        assert.strictEqual(again.length, 1);
        assert.deepStrictEqual(again[0].windows, [2]);
        assert.deepStrictEqual(Moves.withoutPreset(again, again[0].id), []);
    });
});

test.describe("launcher asks", () => {
    test.it("reads the name from a save preset phrase", () => {
        assert.strictEqual(Search.presetAsk("save window preset Coding"), "Coding");
        assert.strictEqual(Search.presetAsk("save preset as Review"), "Review");
        assert.strictEqual(Search.presetAsk("save the files"), "");
    });

    test.it("finds every stream of the focused window's app", () => {
        const streams = [{ binary: "firefox", name: "Firefox", node: 1 }, { binary: "firefox", name: "Firefox", node: 3 }, { binary: "mpv", name: "mpv", node: 2 }];
        assert.deepStrictEqual(Search.streamsForWindow(streams, "firefox").map(x => x.node), [1, 3]);
        assert.deepStrictEqual(Search.streamsForWindow(streams, "org.mozilla.firefox").map(x => x.node), [1, 3]);
        assert.deepStrictEqual(Search.streamsForWindow(streams, "kitty"), []);
    });
});
