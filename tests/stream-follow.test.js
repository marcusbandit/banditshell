const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/stream-follow.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { step } = new Function(src + "\nreturn { step };")();

test("a flag file that appears turns the mode on", () => {
    assert.deepStrictEqual(step({ seen: false }, "loaded", false, "DP-2"), { seen: true, action: "on" });
});

test("a flag file that appears with no stream screen does nothing", () => {
    assert.deepStrictEqual(step({ seen: false }, "loaded", false, ""), { seen: true, action: "none" });
});

test("a flag file that was there and then goes turns the mode off", () => {
    assert.deepStrictEqual(step({ seen: true }, "missing", true, "DP-2"), { seen: false, action: "off" });
});

test("a mode switched on in settings survives a reload with no flag file", () => {
    assert.deepStrictEqual(step({ seen: false }, "missing", true, "DP-2"), { seen: false, action: "none" });
});

test("a flag file that was never seen cannot turn the mode off again", () => {
    let state = { seen: false };
    for (let i = 0; i < 3; i++) {
        const next = step(state, "missing", true, "DP-2");
        assert.strictEqual(next.action, "none");
        state = next;
    }
});

test("removing the flag file twice turns the mode off once", () => {
    const first = step({ seen: true }, "missing", true, "DP-2");
    const second = step(first, "missing", true, "DP-2");
    assert.strictEqual(first.action, "off");
    assert.strictEqual(second.action, "none");
});
