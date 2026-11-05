const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/weekdays.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Week = new Function(src + "\nreturn { CHOICES, firstDay, order, lead, mondayBased, qtDay, weekNumber };")();

const dates = fs.readFileSync(path.join(ROOT, "services/dates.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Dates = new Function(dates + "\nreturn { isoWeek };")();

test("the week number of a Monday row is the launcher's ISO week", () => {
    for (let day = new Date(2024, 11, 30); day < new Date(2028, 0, 1); day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 7))
        assert.strictEqual(Week.weekNumber(day), Dates.isoWeek(day), day.toDateString());
});

test.describe("firstDay", () => {
    test.it("follows the locale unless a day is chosen", () => {
        assert.strictEqual(Week.firstDay("locale", 0), 0);
        assert.strictEqual(Week.firstDay("locale", 1), 1);
        assert.strictEqual(Week.firstDay("locale", 6), 6);
    });

    test.it("lets the setting beat the locale", () => {
        assert.strictEqual(Week.firstDay("monday", 0), 1);
        assert.strictEqual(Week.firstDay("sunday", 1), 0);
        assert.strictEqual(Week.firstDay("saturday", 1), 6);
    });

    test.it("falls back to Monday when neither side is usable", () => {
        assert.strictEqual(Week.firstDay("locale", undefined), 1);
        assert.strictEqual(Week.firstDay("locale", 9), 1);
        assert.strictEqual(Week.firstDay("toString", 0), 0);
        assert.strictEqual(Week.firstDay("", NaN), 1);
    });
});

test.describe("order and lead", () => {
    test.it("lists the seven days starting at the first one", () => {
        assert.deepStrictEqual(Week.order(1), [1, 2, 3, 4, 5, 6, 0]);
        assert.deepStrictEqual(Week.order(0), [0, 1, 2, 3, 4, 5, 6]);
        assert.deepStrictEqual(Week.order(6), [6, 0, 1, 2, 3, 4, 5]);
    });

    test.it("counts the days of the previous month a grid shows before the 1st", () => {
        const first = new Date(2026, 10, 1);
        assert.strictEqual(first.getDay(), 0);
        assert.strictEqual(Week.lead(first, 1), 6);
        assert.strictEqual(Week.lead(first, 0), 0);
        assert.strictEqual(Week.lead(first, 6), 1);
    });
});

test("alarm days stay Monday-based and Qt names Sunday as 7", () => {
    assert.deepStrictEqual([0, 1, 6].map(Week.mondayBased), [6, 0, 5]);
    assert.deepStrictEqual([0, 1, 6].map(Week.qtDay), [7, 1, 6]);
});

test.describe("weekNumber", () => {
    test.it("gives the ISO week of the row, whichever day the row starts on", () => {
        assert.strictEqual(Week.weekNumber(new Date(2026, 10, 2)), 45);
        assert.strictEqual(Week.weekNumber(new Date(2026, 10, 1)), 45);
        assert.strictEqual(Week.weekNumber(new Date(2026, 9, 25)), 44);
    });

    test.it("carries week 53 and week 1 across new year as ISO does", () => {
        assert.strictEqual(Week.weekNumber(new Date(2020, 11, 28)), 53);
        assert.strictEqual(Week.weekNumber(new Date(2021, 0, 4)), 1);
        assert.strictEqual(Week.weekNumber(new Date(2024, 11, 30)), 1);
    });
});
