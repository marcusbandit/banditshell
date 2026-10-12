const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/cli.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Words = new Function(src + "\nreturn { duration, timeOfDay, hhmm, repeatDays, dayWords, columns, zoneKey, zoneMatches };")();

test.describe("duration", () => {
    test.it("reads a bare number as minutes", () => {
        assert.strictEqual(Words.duration("10"), 600);
        assert.strictEqual(Words.duration("1.5"), 90);
    });

    test.it("adds up hours, minutes and seconds in any order", () => {
        assert.strictEqual(Words.duration("1h30m"), 5400);
        assert.strictEqual(Words.duration("90s"), 90);
        assert.strictEqual(Words.duration("2h"), 7200);
        assert.strictEqual(Words.duration("30s1m"), 90);
        assert.strictEqual(Words.duration("0.5h"), 1800);
    });

    test.it("ignores case and spaces", () => {
        assert.strictEqual(Words.duration(" 1H 30M "), 5400);
    });

    test.it("answers 0 for anything it cannot read", () => {
        for (const bad of ["", "bogus", "10x", "m", "h1", "-5", undefined, null])
            assert.strictEqual(Words.duration(bad), 0, `${bad}`);
    });
});

test.describe("timeOfDay", () => {
    test.it("reads 24-hour times with or without the colon", () => {
        assert.strictEqual(Words.timeOfDay("07:00"), 420);
        assert.strictEqual(Words.timeOfDay("0700"), 420);
        assert.strictEqual(Words.timeOfDay("23:59"), 1439);
        assert.strictEqual(Words.timeOfDay("0:00"), 0);
    });

    test.it("reads a bare hour", () => {
        assert.strictEqual(Words.timeOfDay("7"), 420);
        assert.strictEqual(Words.timeOfDay("19"), 1140);
    });

    test.it("reads am and pm", () => {
        assert.strictEqual(Words.timeOfDay("7:30pm"), 1170);
        assert.strictEqual(Words.timeOfDay("12am"), 0);
        assert.strictEqual(Words.timeOfDay("12pm"), 720);
        assert.strictEqual(Words.timeOfDay("7 AM"), 420);
    });

    test.it("answers -1 for impossible or unreadable times", () => {
        for (const bad of ["25:00", "12:60", "13pm", "0am", "7:5", "noon", "", undefined])
            assert.strictEqual(Words.timeOfDay(bad), -1, `${bad}`);
    });
});

test.describe("hhmm", () => {
    test.it("pads both halves to two digits", () => {
        assert.strictEqual(Words.hhmm(7, 5), "07:05");
        assert.strictEqual(Words.hhmm(19, 30), "19:30");
    });
});

test.describe("repeatDays", () => {
    test.it("knows the named sets", () => {
        assert.deepStrictEqual(Words.repeatDays(""), []);
        assert.deepStrictEqual(Words.repeatDays("once"), []);
        assert.deepStrictEqual(Words.repeatDays("never"), []);
        assert.deepStrictEqual(Words.repeatDays("daily"), [0, 1, 2, 3, 4, 5, 6]);
        assert.deepStrictEqual(Words.repeatDays("everyday"), [0, 1, 2, 3, 4, 5, 6]);
        assert.deepStrictEqual(Words.repeatDays("weekdays"), [0, 1, 2, 3, 4]);
        assert.deepStrictEqual(Words.repeatDays("weekends"), [5, 6]);
        assert.deepStrictEqual(Words.repeatDays("weekend"), [5, 6]);
    });

    test.it("reads lists and ranges, sorted and without repeats", () => {
        assert.deepStrictEqual(Words.repeatDays("mon,wed"), [0, 2]);
        assert.deepStrictEqual(Words.repeatDays("wed,mon,wed"), [0, 2]);
        assert.deepStrictEqual(Words.repeatDays("mon-fri"), [0, 1, 2, 3, 4]);
        assert.deepStrictEqual(Words.repeatDays("Monday-Wednesday"), [0, 1, 2]);
    });

    test.it("wraps a range through the end of the week", () => {
        assert.deepStrictEqual(Words.repeatDays("sat-mon"), [0, 5, 6]);
    });

    test.it("answers null for a day it does not know", () => {
        assert.strictEqual(Words.repeatDays("mon,funday"), null);
        assert.strictEqual(Words.repeatDays("mon-tue-wed"), null);
    });
});

test.describe("dayWords", () => {
    test.it("names the sets repeatDays reads", () => {
        assert.strictEqual(Words.dayWords([]), "once");
        assert.strictEqual(Words.dayWords([0, 1, 2, 3, 4, 5, 6]), "daily");
        assert.strictEqual(Words.dayWords([0, 1, 2, 3, 4]), "weekdays");
        assert.strictEqual(Words.dayWords([5, 6]), "weekends");
        assert.strictEqual(Words.dayWords([0, 2]), "mon,wed");
    });

    test.it("reads anything that is not a list as once", () => {
        assert.strictEqual(Words.dayWords(undefined), "once");
    });

    test.it("round-trips through repeatDays", () => {
        for (const spec of ["once", "daily", "weekdays", "weekends", "mon,wed", "tue,thu,sat"])
            assert.strictEqual(Words.dayWords(Words.repeatDays(spec)), spec);
    });
});

test.describe("columns", () => {
    test.it("pads every column but the last to its widest cell", () => {
        const rows = [["1", "10m", "running", "tea"], ["12", "1h 5m", "paused", "x"]];
        assert.strictEqual(Words.columns(rows), "1   10m    running  tea\n12  1h 5m  paused   x");
    });

    test.it("turns cells into strings", () => {
        assert.strictEqual(Words.columns([[1, true, null]]), "1  true  null");
    });

    test.it("answers nothing for no rows", () => {
        assert.strictEqual(Words.columns([]), "");
    });
});

test.describe("zones", () => {
    const zones = ["Europe/Copenhagen", "America/New_York", "America/North_Dakota/New_Salem", "Asia/Tokyo"];

    test.it("keys ignore case, and spaces stand for underscores", () => {
        assert.strictEqual(Words.zoneKey(" America/New York "), "america/new_york");
        assert.strictEqual(Words.zoneKey(undefined), "");
    });

    test.it("prefers an exact match over a partial one", () => {
        assert.deepStrictEqual(Words.zoneMatches("america/new york", zones), ["America/New_York"]);
    });

    test.it("falls back to every zone containing the text", () => {
        assert.deepStrictEqual(Words.zoneMatches("new", zones), ["America/New_York", "America/North_Dakota/New_Salem"]);
        assert.deepStrictEqual(Words.zoneMatches("tokyo", zones), ["Asia/Tokyo"]);
        assert.deepStrictEqual(Words.zoneMatches("atlantis", zones), []);
    });
});
