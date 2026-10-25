const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/session/arming.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Arming = new Function(src + "\nreturn { press };")();

const shutDown = { key: "poweroff" };
const sleep = { key: "suspend", safe: true };

test("a safe action runs on the first press", () => {
    assert.strictEqual(Arming.press(sleep, "", 0, 1000, 400), "run");
});

test("a dangerous action arms on the first press and runs on a later one", () => {
    assert.strictEqual(Arming.press(shutDown, "", 0, 1000, 400), "arm");
    assert.strictEqual(Arming.press(shutDown, "poweroff", 1000, 1400, 400), "run");
});

test("a second press inside the double-click interval is ignored, so a double-click never shuts down", () => {
    assert.strictEqual(Arming.press(shutDown, "poweroff", 1000, 1000, 400), "wait");
    assert.strictEqual(Arming.press(shutDown, "poweroff", 1000, 1399, 400), "wait");
});

test("pressing a different dangerous action arms that one instead", () => {
    assert.strictEqual(Arming.press(shutDown, "reboot", 1000, 1100, 400), "arm");
});
