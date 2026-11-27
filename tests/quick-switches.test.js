const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/quickcontrols/quick-switches.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Switches = new Function(`${src}\nreturn { powerLabel, powerIcon, nextProfile, powerRaised };`)();

test("the power switch steps through the modes the daemon offers and wraps", () => {
    const all = ["saver", "balanced", "fast"];
    assert.strictEqual(Switches.nextProfile(all, "saver"), "balanced");
    assert.strictEqual(Switches.nextProfile(all, "balanced"), "fast");
    assert.strictEqual(Switches.nextProfile(all, "fast"), "saver");
    assert.strictEqual(Switches.nextProfile(["saver", "balanced"], "balanced"), "saver");
});

test("an unknown or missing mode starts the cycle at the first choice", () => {
    assert.strictEqual(Switches.nextProfile(["saver", "balanced", "fast"], "custom-tuned"), "saver");
    assert.strictEqual(Switches.nextProfile([], "balanced"), "");
    assert.strictEqual(Switches.nextProfile(undefined, "balanced"), "");
});

test("only a mode away from balanced lights the switch", () => {
    assert.strictEqual(Switches.powerRaised("balanced"), false);
    assert.strictEqual(Switches.powerRaised("saver"), true);
    assert.strictEqual(Switches.powerRaised("fast"), true);
    assert.strictEqual(Switches.powerRaised(""), false);
});

test("every mode has a label and an icon, and an unknown one falls back", () => {
    assert.strictEqual(Switches.powerLabel("fast"), "Performance");
    assert.strictEqual(Switches.powerIcon("saver"), "eco");
    assert.strictEqual(Switches.powerLabel("custom-tuned"), "Power mode");
    assert.strictEqual(Switches.powerIcon("custom-tuned"), "bolt");
});
