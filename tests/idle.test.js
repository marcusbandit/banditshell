const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
const Idle = new Function(`${read("services/idle.js")}\nreturn { plan, handledBy };`)();
const Durations = new Function(`${read("modules/settings/durations.js")}\nreturn { minutesFromChoice, choiceFromMinutes };`)();

test("a step with 0 minutes is never planned", () => {
    assert.deepStrictEqual(Idle.plan({ lock: 0, screensOff: 0, sleep: 0 }, true), []);
    assert.deepStrictEqual(Idle.plan({ lock: 5, screensOff: 0, sleep: 0 }, true).map(s => s.name), ["lock"]);
});

test("steps come in the order they fire, with seconds for the idle monitor", () => {
    const steps = Idle.plan({ lock: 15, screensOff: 5, sleep: 30 }, true);
    assert.deepStrictEqual(steps.map(s => [s.name, s.seconds]), [["screensOff", 300], ["lock", 900], ["sleep", 1800]]);
});

test("sleep is only planned on battery", () => {
    const minutes = { lock: 5, screensOff: 10, sleep: 30 };
    assert.ok(Idle.plan(minutes, true).some(s => s.name === "sleep"));
    assert.ok(!Idle.plan(minutes, false).some(s => s.name === "sleep"));
});

test("junk minutes plan nothing instead of firing at once", () => {
    assert.deepStrictEqual(Idle.plan({ lock: "x", screensOff: -3, sleep: undefined }, true), []);
});

test("any pgrep output means hypridle is running", () => {
    assert.strictEqual(Idle.handledBy("3794\n"), true);
    assert.strictEqual(Idle.handledBy(""), false);
    assert.strictEqual(Idle.handledBy("  \n"), false);
});

test("idle choices map to minutes and back", () => {
    for (const [label, minutes] of [["1 min", 1], ["5 min", 5], ["15 min", 15], ["30 min", 30], ["1 h", 60], ["never", 0]]) {
        assert.strictEqual(Durations.minutesFromChoice(label), minutes, label);
        assert.strictEqual(Durations.choiceFromMinutes(minutes), label, label);
    }
});

test("minutes nobody offered still show as themselves, and nonsense reads as never", () => {
    assert.strictEqual(Durations.choiceFromMinutes(7), "7 min");
    assert.strictEqual(Durations.choiceFromMinutes(90), "90 min");
    assert.strictEqual(Durations.choiceFromMinutes(undefined), "never");
    assert.strictEqual(Durations.minutesFromChoice("soon"), 0);
});
