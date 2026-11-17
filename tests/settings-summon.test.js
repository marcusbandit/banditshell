const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.resolve(__dirname, "../services/settings-summon.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { toggleAction } = new Function(`${src}\nreturn { toggleAction };`)();

test("the hotkey closes Settings that is showing", () => {
    assert.strictEqual(toggleAction(true, false, "DP-1", "DP-1"), "hide");
    assert.strictEqual(toggleAction(true, false, "", "DP-1"), "hide");
});

test("the hotkey brings up Settings that a menu is covering instead of closing it", () => {
    assert.strictEqual(toggleAction(true, true, "DP-1", "DP-1"), "show");
});

test("the hotkey opens Settings that is closed or on another screen", () => {
    assert.strictEqual(toggleAction(false, false, "DP-1", "DP-1"), "show");
    assert.strictEqual(toggleAction(true, false, "DP-2", "DP-1"), "show");
});
