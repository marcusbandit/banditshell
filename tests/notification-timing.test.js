const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notification-timing.js"), "utf8");
const Timing = new Function(src + "\nreturn { span, muteLength, snoozeLength, muted, mutedLine, due, snoozeAdd, hushAllowed, popupTimeout, wakeTimeout };")();

const MIN = 60 * 1000;
const HOUR = 60 * MIN;
const DAY = 24 * HOUR;

test("a mute length reads the way people type it", () => {
    assert.strictEqual(Timing.muteLength("1h"), HOUR);
    assert.strictEqual(Timing.muteLength("30m"), 30 * MIN);
    assert.strictEqual(Timing.muteLength("90 min"), 90 * MIN);
    assert.strictEqual(Timing.muteLength("2 hours"), 2 * HOUR);
    assert.strictEqual(Timing.muteLength("hour"), HOUR);
    assert.strictEqual(Timing.muteLength("an hour"), HOUR);
    assert.strictEqual(Timing.muteLength("day"), DAY);
    assert.strictEqual(Timing.muteLength("for a day"), DAY);
    assert.strictEqual(Timing.muteLength("1.5h"), 90 * MIN);
    assert.strictEqual(Timing.muteLength("week"), 7 * DAY);
});

test("no length, always or never mean until unmuted", () => {
    for (const word of ["", "always", "never", "Forever", "  "])
        assert.strictEqual(Timing.muteLength(word), 0, word);
});

test("nonsense and absurd lengths are refused", () => {
    for (const word of ["soon", "5", "0m", "-1h", "h1", "100d", "1 parsec"])
        assert.strictEqual(Timing.muteLength(word), -1, word);
});

test("a snooze with no length is ten minutes", () => {
    assert.strictEqual(Timing.snoozeLength(""), 10 * MIN);
    assert.strictEqual(Timing.snoozeLength("1h"), HOUR);
    assert.strictEqual(Timing.snoozeLength("whenever"), -1);
});

test("a rule is muted only before its deadline", () => {
    assert.strictEqual(Timing.muted({ muteUntil: 2000 }, 1000), true);
    assert.strictEqual(Timing.muted({ muteUntil: 1000 }, 1000), false);
    assert.strictEqual(Timing.muted({ muteUntil: 0 }, 1000), false);
    assert.strictEqual(Timing.muted({}, 1000), false);
    assert.strictEqual(Timing.muted(null, 1000), false);
});

test("what is left of a mute is said in its largest whole unit", () => {
    assert.strictEqual(Timing.mutedLine(10 * MIN, 0), "10m");
    assert.strictEqual(Timing.mutedLine(10 * 1000, 0), "1m");
    assert.strictEqual(Timing.mutedLine(3 * HOUR, 0), "3h");
    assert.strictEqual(Timing.mutedLine(2 * DAY, 0), "2d");
    assert.strictEqual(Timing.mutedLine(0, 5), "");
});

test("snoozed entries split into due and waiting without losing any", () => {
    const a = { name: "a" };
    const b = { name: "b" };
    const c = { name: "c" };
    const split = Timing.due([{ entry: a, at: 100 }, { entry: b, at: 300 }, { entry: c, at: 200 }], 200);
    assert.deepStrictEqual(split.ready.map(i => i.entry.name), ["a", "c"]);
    assert.deepStrictEqual(split.waiting.map(i => i.entry.name), ["b"]);
    assert.deepStrictEqual(Timing.due(undefined, 5), { ready: [], waiting: [] });
});

test("snoozing the same entry again moves its deadline", () => {
    const a = { name: "a" };
    const b = { name: "b" };
    const once = Timing.snoozeAdd([], a, 100);
    const both = Timing.snoozeAdd(once, b, 200);
    const again = Timing.snoozeAdd(both, a, 900);
    assert.deepStrictEqual(again.map(i => [i.entry.name, i.at]), [["b", 200], ["a", 900]]);
});

test("a press needs a snooze length, or an app key to mute or unmute", () => {
    assert.strictEqual(Timing.hushAllowed("snooze", HOUR, ""), true);
    assert.strictEqual(Timing.hushAllowed("snooze", 0, "discord"), false);
    assert.strictEqual(Timing.hushAllowed("mute", 0, "discord"), true);
    assert.strictEqual(Timing.hushAllowed("mute", HOUR, ""), false);
    assert.strictEqual(Timing.hushAllowed("mute", -1, "discord"), false);
    assert.strictEqual(Timing.hushAllowed("unmute", 0, "discord"), true);
    assert.strictEqual(Timing.hushAllowed("unmute", 0, ""), false);
    assert.strictEqual(Timing.hushAllowed("shout", HOUR, "discord"), false);
});

test("a popup stays for as long as the app asked", () => {
    assert.strictEqual(Timing.popupTimeout(8000, false, 5000), 8000);
});

test("an app that asks for the server default gets the shell's timeout", () => {
    assert.strictEqual(Timing.popupTimeout(-1, false, 5000), 5000);
    assert.strictEqual(Timing.popupTimeout(undefined, false, 5000), 5000);
});

test("an expire timeout of 0 never expires on its own, as the spec says", () => {
    assert.strictEqual(Timing.popupTimeout(0, false, 5000), 0);
});

test("a critical popup never expires, whatever the app asked", () => {
    assert.strictEqual(Timing.popupTimeout(8000, true, 5000), 0);
    assert.strictEqual(Timing.popupTimeout(-1, true, 5000), 0);
});

test("a woken popup keeps the time it had, and one that never expires still never does", () => {
    assert.strictEqual(Timing.wakeTimeout(8000, false, true, 5000), 8000);
    assert.strictEqual(Timing.wakeTimeout(0, false, true, 5000), 0);
    assert.strictEqual(Timing.wakeTimeout(0, true, false, 5000), 0);
});

test("a woken popup restored from history counts down the shell's timeout", () => {
    assert.strictEqual(Timing.wakeTimeout(0, false, false, 5000), 5000);
});
