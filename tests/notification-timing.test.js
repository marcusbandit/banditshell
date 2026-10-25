const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notification-timing.js"), "utf8");
const Timing = new Function(src + "\nreturn { span, muteLength, snoozeLength, muted, mutedLine, due, snoozeAdd, hushLength };")();

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

test("a press snoozes or mutes for an hour, until the night ends, or for good", () => {
    const at = (day, h, m) => new Date(2026, 9, day, h, m).getTime();
    assert.strictEqual(Timing.hushLength("hour", at(25, 10, 15), "07:30"), HOUR);
    assert.strictEqual(Timing.hushLength("always", at(25, 10, 15), "07:30"), 0);
    assert.strictEqual(Timing.hushLength("tomorrow", at(25, 23, 0), "07:30"), 8 * HOUR + 30 * MIN);
    assert.strictEqual(Timing.hushLength("tomorrow", at(25, 3, 0), "07:30"), 4 * HOUR + 30 * MIN);
    assert.strictEqual(Timing.hushLength("tomorrow", at(25, 7, 30), "07:30"), at(26, 7, 30) - at(25, 7, 30));
    assert.strictEqual(at(31, 22, 0) + Timing.hushLength("tomorrow", at(31, 22, 0), "07:30"), new Date(2026, 10, 1, 7, 30).getTime());
});

test("tomorrow falls back to midnight when the night has no end set", () => {
    const now = new Date(2026, 9, 25, 20, 0).getTime();
    assert.strictEqual(Timing.hushLength("tomorrow", now, ""), 4 * HOUR);
    assert.strictEqual(Timing.hushLength("tomorrow", now, "25:00"), 4 * HOUR);
    assert.strictEqual(Timing.hushLength("later", now, "07:30"), -1);
});
