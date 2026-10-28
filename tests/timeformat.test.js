const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/timeformat.js"), "utf8");
const Format = new Function(src + "\nreturn { STYLES, styleOf, hourPart, minutePart, clockText, timeText, dateText, stampText, recentText, changedText, exampleText };")();

const MORNING = new Date(2026, 9, 14, 9, 5, 7);
const AFTERNOON = new Date(2026, 9, 14, 14, 32, 0);
const MIDNIGHT = new Date(2026, 9, 14, 0, 4, 0);
const NOON = new Date(2026, 9, 14, 12, 0, 0);

test("a 24-hour clock pads the hour, a 12-hour one does not", () => {
    assert.strictEqual(Format.timeText(MORNING, true, false), "09:05");
    assert.strictEqual(Format.timeText(MORNING, false, false), "9:05 am");
    assert.strictEqual(Format.timeText(AFTERNOON, true, false), "14:32");
    assert.strictEqual(Format.timeText(AFTERNOON, false, false), "2:32 pm");
});

test("midnight and noon read as 12 on a 12-hour clock", () => {
    assert.strictEqual(Format.timeText(MIDNIGHT, false, false), "12:04 am");
    assert.strictEqual(Format.timeText(NOON, false, false), "12:00 pm");
    assert.strictEqual(Format.timeText(MIDNIGHT, true, false), "00:04");
});

test("seconds ride along when asked for", () => {
    assert.strictEqual(Format.timeText(MORNING, true, true), "09:05:07");
    assert.strictEqual(Format.timeText(MORNING, false, true), "9:05:07 am");
});

test("hours and minutes can be asked for apart, the hour padded either way", () => {
    assert.strictEqual(Format.hourPart(AFTERNOON, true), "14");
    assert.strictEqual(Format.hourPart(AFTERNOON, false), "02");
    assert.strictEqual(Format.hourPart(MIDNIGHT, false), "12");
    assert.strictEqual(Format.minutePart(MORNING), "05");
});

test("a bare hour and minute format the same as a moment", () => {
    assert.strictEqual(Format.clockText(7, 0, true), "07:00");
    assert.strictEqual(Format.clockText(19, 30, false), "7:30 pm");
});

test("each date style has its own look for every place a date is shown", () => {
    const at = style => shape => Format.dateText(AFTERNOON, style, shape);
    assert.deepStrictEqual(["headline", "brief", "year", "day", "month"].map(at("slashes")), ["Wednesday 14/10", "Wed 14/10", "14/10/2026", "14/10", "10/2026"]);
    assert.deepStrictEqual(["headline", "brief", "year", "day", "month"].map(at("dotted")), ["Wednesday 14. October", "Wed 14. Oct.", "14. Oct. 2026", "14. Oct.", "Oct. 2026"]);
    assert.deepStrictEqual(["headline", "brief", "year", "day", "month"].map(at("iso")), ["Wednesday 2026-10-14", "Wed 2026-10-14", "2026-10-14", "10-14", "2026-10"]);
    assert.deepStrictEqual(["headline", "brief", "year", "day", "month"].map(at("words")), ["Wednesday 14 October", "Wed 14 Oct", "14 Oct 2026", "14 Oct", "October 2026"]);
});

test("names stay English whatever the system language is", () => {
    const sunday = new Date(2026, 0, 4, 10, 0, 0);
    assert.strictEqual(Format.dateText(sunday, "words", "headline"), "Sunday 4 January");
});

test("a style the shell does not know falls back, and the old planned strings still mean something", () => {
    assert.strictEqual(Format.styleOf("nonsense"), "words");
    assert.strictEqual(Format.styleOf(undefined), "words");
    assert.strictEqual(Format.styleOf("14. okt. 2026"), "dotted");
    assert.strictEqual(Format.styleOf("2026-10-14"), "iso");
    assert.strictEqual(Format.styleOf("wed 14 oct"), "words");
    assert.strictEqual(Format.styleOf("iso"), "iso");
    assert.strictEqual(Format.dateText(AFTERNOON, "nonsense", "year"), "14 Oct 2026");
});

test("a stamp is a date with a year and the time after it", () => {
    assert.strictEqual(Format.stampText(AFTERNOON, "words", true), "14 Oct 2026  14:32");
    assert.strictEqual(Format.stampText(AFTERNOON, "slashes", false), "14/10/2026  2:32 pm");
});

test("a recent time shows the hour today, the day this year and the month before that", () => {
    const now = new Date(2026, 9, 14, 20, 0, 0);
    assert.strictEqual(Format.recentText(AFTERNOON, now, "words", true), "14:32");
    assert.strictEqual(Format.recentText(new Date(2026, 2, 3, 8, 0, 0), now, "words", true), "3 Mar");
    assert.strictEqual(Format.recentText(new Date(2025, 2, 3, 8, 0, 0), now, "words", true), "March 2025");
});

test("a changed date says Today, then day and month, with the year once it is not this year", () => {
    const now = new Date(2026, 9, 14, 20, 0, 0);
    assert.strictEqual(Format.changedText(AFTERNOON, now, "words"), "Today");
    assert.strictEqual(Format.changedText(new Date(2026, 9, 13, 23, 59, 0), now, "words"), "13 Oct");
    assert.strictEqual(Format.changedText(new Date(2026, 0, 1, 0, 0, 0), now, "words"), "1 Jan");
    assert.strictEqual(Format.changedText(new Date(2025, 11, 31, 23, 0, 0), now, "words"), "31 Dec 2025");
    assert.strictEqual(Format.changedText(new Date(2025, 4, 2, 8, 0, 0), now, "iso"), "2025-05-02");
});

test("every style has an example the panel can list, in lower case", () => {
    assert.deepStrictEqual(Format.STYLES.map(s => Format.exampleText(s, AFTERNOON)), ["14/10/2026", "14. oct. 2026", "2026-10-14", "14 oct 2026"]);
});
