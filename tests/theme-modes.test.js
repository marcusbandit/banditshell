const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.resolve(__dirname, "../services/theme-modes.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { targetFor, neutralAfter, slotToKeep } = new Function(`${src}\nreturn { targetFor, neutralAfter, slotToKeep };`)();

const colour = { lightTheme: "paper", darkTheme: "slate" };
const all = ["slate", "paper", "mist"];

test("light mode wants the light theme when another is active", () => {
    assert.strictEqual(targetFor(colour, true, "slate", "slate", all), "paper");
});

test("nothing changes when the wanted theme is already active", () => {
    assert.strictEqual(targetFor(colour, false, "slate", "slate", all), "");
});

test("an empty slot goes back to the picked theme when the mode flips back", () => {
    const only = { lightTheme: "paper", darkTheme: "" };
    assert.strictEqual(targetFor(only, false, "mist", "paper", all), "mist");
});

test("a missing theme or an empty slot with nothing picked leaves the theme alone", () => {
    assert.strictEqual(targetFor(colour, true, "slate", "slate", ["slate"]), "");
    assert.strictEqual(targetFor({ lightTheme: "", darkTheme: "" }, true, "", "slate", all), "");
});

test("the picked theme follows changes made while the mode has no slot", () => {
    assert.strictEqual(neutralAfter({ lightTheme: "", darkTheme: "" }, true, "slate", "mist"), "mist");
    assert.strictEqual(neutralAfter(colour, true, "slate", "mist"), "slate");
});

test("picking a theme only updates the slot that is already in use", () => {
    assert.deepStrictEqual(slotToKeep(colour, true, "mist"), { key: "lightTheme", value: "mist" });
    assert.strictEqual(slotToKeep({ lightTheme: "", darkTheme: "" }, true, "mist"), null);
});
