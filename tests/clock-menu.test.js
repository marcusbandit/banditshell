const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/clock-menu.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Menu = new Function(src + "\nreturn { TIMER_PRESETS, presetText, matchZones, missingZoneText, fullNote, timersFull, runningTimers, hour12, hour24, typedNumber, reinsert };")();

const ZONES = [
    "Africa/Abidjan",
    "Africa/Accra",
    "America/Argentina/Buenos_Aires",
    "America/Chicago",
    "America/Los_Angeles",
    "America/New_York",
    "Asia/Hong_Kong",
    "Asia/Tokyo",
    "Europe/Copenhagen",
    "Europe/London",
    "Europe/Paris",
    "Pacific/Auckland"
];

test.describe("matchZones", () => {
    test.it("finds a city typed with spaces", () => {
        assert.deepStrictEqual(Menu.matchZones(ZONES, [], "new york", 8), ["America/New_York"]);
        assert.deepStrictEqual(Menu.matchZones(ZONES, [], "los angeles", 8), ["America/Los_Angeles"]);
        assert.deepStrictEqual(Menu.matchZones(ZONES, [], "hong kong", 8), ["Asia/Hong_Kong"]);
    });

    test.it("still takes the underscore form and ignores case and extra spaces", () => {
        assert.deepStrictEqual(Menu.matchZones(ZONES, [], "new_york", 8), ["America/New_York"]);
        assert.deepStrictEqual(Menu.matchZones(ZONES, [], "   New   York  ", 8), ["America/New_York"]);
    });

    test.it("finds a city by the start of one of its words", () => {
        assert.deepStrictEqual(Menu.matchZones(ZONES, [], "aires", 8), ["America/Argentina/Buenos_Aires"]);
    });

    test.it("ranks an exact city, then a prefix, then a word start, then a substring, then the region", () => {
        const all = ["Europe/Rome", "Asia/Romeo", "America/Port_Rome", "Pacific/Chrome", "Rome/Zed"];
        assert.deepStrictEqual(Menu.matchZones(all, [], "rome", 8), ["Europe/Rome", "Asia/Romeo", "America/Port_Rome", "Pacific/Chrome", "Rome/Zed"]);
    });

    test.it("leaves out zones already taken", () => {
        assert.deepStrictEqual(Menu.matchZones(ZONES, ["America/New_York"], "new york", 8), []);
    });

    test.it("caps the list", () => {
        assert.strictEqual(Menu.matchZones(ZONES, [], "a", 3).length, 3);
    });

    test.it("offers common cities, not the alphabetical start, when the box is empty", () => {
        const found = Menu.matchZones(ZONES, [], "", 8);
        assert.ok(!found.includes("Africa/Abidjan"));
        assert.deepStrictEqual(found.slice(0, 3), ["America/New_York", "America/Los_Angeles", "America/Chicago"]);
        assert.deepStrictEqual(Menu.matchZones(ZONES, [], "  ", 8), found);
    });

    test.it("skips a common city that is already added or missing from the system list", () => {
        const found = Menu.matchZones(ZONES, ["America/New_York"], "", 8);
        assert.ok(!found.includes("America/New_York"));
        assert.ok(!found.includes("Asia/Dubai"));
    });
});

test.describe("messages", () => {
    test.it("names the text that found nothing", () => {
        assert.strictEqual(Menu.missingZoneText("  atlantis  ", []), "no city called atlantis");
    });

    test.it("says so when the city is already added instead of claiming it does not exist", () => {
        assert.strictEqual(Menu.missingZoneText("new york", ["Europe/Copenhagen", "America/New_York"]), "New York is already on the list");
    });

    test.it("says why a full list did nothing", () => {
        assert.strictEqual(Menu.fullNote("timer", 3), "3 timers is the most, remove one");
        assert.strictEqual(Menu.fullNote("alarm", 1), "1 alarm is the most, remove it");
    });
});

test.describe("timer slots", () => {
    const running = { finished: false, paused: false };
    const paused = { finished: false, paused: true };
    const done = { finished: true, paused: false };

    test.it("counts a paused timer as using a slot but not as running", () => {
        assert.strictEqual(Menu.timersFull([running, paused], 2), true);
        assert.strictEqual(Menu.runningTimers([running, paused, done]).length, 1);
        assert.strictEqual(Menu.runningTimers([paused]).length, 0);
    });

    test.it("lets a finished timer make room", () => {
        assert.strictEqual(Menu.timersFull([running, done], 2), false);
    });
});

test.describe("hours", () => {
    test.it("shows midnight and noon as 12", () => {
        assert.deepStrictEqual([0, 1, 11, 12, 13, 23].map(Menu.hour12), [12, 1, 11, 12, 1, 11]);
    });

    test.it("turns a 12-hour pick back into the 24-hour clock", () => {
        assert.deepStrictEqual([[12, false], [1, false], [11, false], [12, true], [3, true], [11, true]].map(([h, pm]) => Menu.hour24(h, pm)), [0, 1, 11, 12, 15, 23]);
    });

    test.it("round-trips every hour of the day", () => {
        for (let hour = 0; hour < 24; hour++)
            assert.strictEqual(Menu.hour24(Menu.hour12(hour), hour >= 12), hour);
    });
});

test.describe("typedNumber", () => {
    test.it("reads digits and clamps to the range", () => {
        assert.strictEqual(Menu.typedNumber("15", 0, 59), 15);
        assert.strictEqual(Menu.typedNumber("06", 0, 23), 6);
        assert.strictEqual(Menu.typedNumber("99", 0, 59), 59);
        assert.strictEqual(Menu.typedNumber("0", 1, 12), 1);
    });

    test.it("ignores anything that is not a digit and reports nothing typed as -1", () => {
        assert.strictEqual(Menu.typedNumber("1:5", 0, 59), 15);
        assert.strictEqual(Menu.typedNumber("", 0, 59), -1);
        assert.strictEqual(Menu.typedNumber("ab", 0, 59), -1);
    });
});

test.describe("reinsert", () => {
    test.it("puts a removed item back where it was", () => {
        assert.deepStrictEqual(Menu.reinsert(["a", "c"], "b", 1), ["a", "b", "c"]);
    });

    test.it("keeps the index inside the list and leaves the original alone", () => {
        const list = ["a"];
        assert.deepStrictEqual(Menu.reinsert(list, "b", 9), ["a", "b"]);
        assert.deepStrictEqual(Menu.reinsert(list, "z", -4), ["z", "a"]);
        assert.deepStrictEqual(list, ["a"]);
    });
});

test.describe("presets", () => {
    test.it("offers 15 and 30 and writes them the same short way", () => {
        assert.ok(Menu.TIMER_PRESETS.includes(15) && Menu.TIMER_PRESETS.includes(30));
        assert.strictEqual(Menu.presetText(15), "15m");
    });
});
