const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notification-search.js"), "utf8");
const Search = new Function(src + "\nreturn { age, threads, threadKey };")();

const NOW = new Date(2026, 9, 17, 14, 30, 0).getTime();
const ago = ms => NOW - ms;
const MIN = 60 * 1000;
const HOUR = 60 * MIN;

test("under a minute draws nothing", () => {
    assert.strictEqual(Search.age(ago(0), NOW), "");
    assert.strictEqual(Search.age(ago(59 * 1000), NOW), "");
    assert.strictEqual(Search.age(NOW + 5000, NOW), "");
    assert.strictEqual(Search.age(0, NOW), "");
    assert.strictEqual(Search.age(undefined, NOW), "");
});

test("minutes then hours on the same day", () => {
    assert.strictEqual(Search.age(ago(MIN), NOW), "1m");
    assert.strictEqual(Search.age(ago(2 * MIN + 30000), NOW), "2m");
    assert.strictEqual(Search.age(ago(59 * MIN), NOW), "59m");
    assert.strictEqual(Search.age(ago(HOUR), NOW), "1h");
    assert.strictEqual(Search.age(ago(5 * HOUR + 59 * MIN), NOW), "5h");
});

test("a few hours that cross midnight still read as hours", () => {
    const late = new Date(2026, 9, 17, 1, 10, 0).getTime();
    const before = new Date(2026, 9, 16, 22, 40, 0).getTime();
    assert.strictEqual(Search.age(before, late), "2h");
});

test("the day before names the clock time", () => {
    const evening = new Date(2026, 9, 16, 21, 4, 0).getTime();
    assert.strictEqual(Search.age(evening, NOW), "yesterday 21:04");
    const morning = new Date(2026, 9, 16, 9, 5, 0).getTime();
    assert.strictEqual(Search.age(morning, NOW), "yesterday 09:05");
});

test("within a week it names the weekday, beyond it the date", () => {
    const tuesday = new Date(2026, 9, 13, 8, 0, 0).getTime();
    assert.strictEqual(Search.age(tuesday, NOW), "Tue 08:00");
    const earlier = new Date(2026, 9, 3, 8, 0, 0).getTime();
    assert.strictEqual(Search.age(earlier, NOW), "3 Oct");
    const lastYear = new Date(2025, 11, 24, 8, 0, 0).getTime();
    assert.strictEqual(Search.age(lastYear, NOW), "24 Dec 2025");
});

const note = (app, summary, minutesAgo, extra = {}) => Object.assign({ appName: app, summary, time: ago(minutesAgo * MIN), category: "" }, extra);

test("a chat burst from one sender is one thread, newest first", () => {
    const burst = [note("Signal", "Ida", 1), note("Signal", "Ida", 2), note("Signal", "Ida", 3), note("Signal", "Ida", 4)];
    const groups = Search.threads(burst);
    assert.strictEqual(groups.length, 1);
    assert.strictEqual(groups[0].entries.length, 4);
    assert.strictEqual(groups[0].newest, burst[0]);
    assert.strictEqual(groups[0].app, "signal");
});

test("the input order does not decide the thread order, time does", () => {
    const a = note("Signal", "Ida", 5);
    const b = note("Mail", "Invoice", 1);
    const c = note("Signal", "Ida", 2);
    const groups = Search.threads([a, b, c]);
    assert.deepStrictEqual(groups.map(g => g.entries.length), [1, 2]);
    assert.strictEqual(groups[0].newest, b);
    assert.strictEqual(groups[1].newest, c);
});

test("another sender or another app is another thread", () => {
    const groups = Search.threads([note("Signal", "Ida", 1), note("Signal", "Jonas", 2), note("Telegram", "Ida", 3)]);
    assert.strictEqual(groups.length, 3);
});

test("a gap longer than ten minutes starts a new thread", () => {
    const groups = Search.threads([note("Signal", "Ida", 1), note("Signal", "Ida", 5), note("Signal", "Ida", 30), note("Signal", "Ida", 34)]);
    assert.deepStrictEqual(groups.map(g => g.entries.length), [2, 2]);
});

test("the desktop id outranks the name an app calls itself", () => {
    const one = note("Signal", "Ida", 1, { appId: "signal-desktop.desktop" });
    const two = note("signal", "Ida", 2, { appId: "signal-desktop.desktop" });
    assert.strictEqual(Search.threads([one, two]).length, 1);
});

test("a notification with no summary threads by its category", () => {
    const groups = Search.threads([note("App", "", 1, { category: "x" }), note("App", "", 2, { category: "x" }), note("App", "", 3, { category: "y" })]);
    assert.deepStrictEqual(groups.map(g => g.entries.length), [2, 1]);
});

test("nothing in, nothing out", () => {
    assert.deepStrictEqual(Search.threads([]), []);
    assert.deepStrictEqual(Search.threads(undefined), []);
});

test("a thread keeps its id when a newer message joins it", () => {
    const before = Search.threads([note("Signal", "Ida", 5), note("Signal", "Ida", 6)]);
    const after = Search.threads([note("Signal", "Ida", 1), note("Signal", "Ida", 5), note("Signal", "Ida", 6)]);
    assert.strictEqual(before[0].id, after[0].id);
});

test("two threads of one sender have different ids", () => {
    const groups = Search.threads([note("Signal", "Ida", 1), note("Signal", "Ida", 60)]);
    assert.strictEqual(groups.length, 2);
    assert.notStrictEqual(groups[0].id, groups[1].id);
});
