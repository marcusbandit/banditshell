const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/quickcontrols/quick-switches.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Switches = new Function(`${src}\nreturn { nextProfile, powerRaised };`)();

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

const More = new Function(`${src}\nreturn { networkState, powerDetail };`)();

test("the network tile names the Wi-Fi network, then a cable, then says why it is offline", () => {
    assert.strictEqual(More.networkState(true, true, "Example Net", false), "Example Net");
    assert.strictEqual(More.networkState(true, true, "Example Net", true), "Example Net");
    assert.strictEqual(More.networkState(true, false, "", true), "Ethernet");
    assert.strictEqual(More.networkState(true, false, "", false), "Off");
    assert.strictEqual(More.networkState(true, true, "", false), "Not connected");
    assert.strictEqual(More.networkState(false, false, "", false), "Not connected");
});

test("the power tile reads the battery first when there is one", () => {
    assert.strictEqual(More.powerDetail("Performance", false, 0), "Performance");
    assert.strictEqual(More.powerDetail("Balanced", true, 81.6), "82%, Balanced");
    assert.strictEqual(More.powerDetail("", true, 40), "40%");
});
