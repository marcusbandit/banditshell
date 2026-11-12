const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.resolve(__dirname, "../services/theme-modes.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { wantedTheme, slotToKeep } = new Function(`${src}\nreturn { wantedTheme, slotToKeep };`)();

const colour = { lightTheme: "paper", darkTheme: "slate" };

test("light mode wants the light theme when another is active", () => {
    assert.strictEqual(wantedTheme(colour, true, false, "slate", ["slate", "paper"]), "paper");
});

test("nothing changes when the wanted theme is already active", () => {
    assert.strictEqual(wantedTheme(colour, false, false, "slate", ["slate", "paper"]), "");
});

test("an empty slot, a missing theme or the wallpaper leave the theme alone", () => {
    assert.strictEqual(wantedTheme({ lightTheme: "", darkTheme: "" }, true, false, "slate", ["slate"]), "");
    assert.strictEqual(wantedTheme(colour, true, false, "slate", ["slate"]), "");
    assert.strictEqual(wantedTheme(colour, true, true, "slate", ["slate", "paper"]), "");
});

test("picking a theme only updates the slot that is already in use", () => {
    assert.deepStrictEqual(slotToKeep(colour, true, "mist"), { key: "lightTheme", value: "mist" });
    assert.strictEqual(slotToKeep({ lightTheme: "", darkTheme: "" }, true, "mist"), null);
});
