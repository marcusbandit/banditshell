const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/currency.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Money = new Function(src + "\nreturn { stale };")();

const HOUR = 3600 * 1000;
const AFTER = 12 * HOUR;

test("rates fetched just now are fresh", () => {
    const fetched = Date.UTC(2026, 9, 27, 8);
    assert.strictEqual(Money.stale(fetched, fetched, AFTER), false);
    assert.strictEqual(Money.stale(fetched, fetched + 11 * HOUR, AFTER), false);
});

test("a shell left running past twelve hours finds its rates stale", () => {
    const fetched = Date.UTC(2026, 9, 27, 8);
    assert.strictEqual(Money.stale(fetched, fetched + 13 * HOUR, AFTER), true);
    assert.strictEqual(Money.stale(fetched, fetched + 3 * 24 * HOUR, AFTER), true);
});

test("rates never fetched are stale", () => {
    assert.strictEqual(Money.stale(0, Date.UTC(2026, 9, 27, 8), AFTER), true);
});
