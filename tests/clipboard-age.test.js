const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/clipboard-age.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Age = new Function(src + "\nreturn { age };")();

const NOW = Date.UTC(2026, 9, 28, 12, 0, 0);
const MIN = 60000;

test.describe("clipboard entry age", () => {
    test.it("says how long ago an entry was copied", () => {
        assert.strictEqual(Age.age(NOW - 10000, NOW), "just now");
        assert.strictEqual(Age.age(NOW - 5 * MIN, NOW), "5m ago");
        assert.strictEqual(Age.age(NOW - 3 * 60 * MIN, NOW), "3h ago");
        assert.strictEqual(Age.age(NOW - 24 * 60 * MIN, NOW), "yesterday");
        assert.strictEqual(Age.age(NOW - 14 * 24 * 60 * MIN, NOW), "2w ago");
    });

    test.it("shows no age when the copy time is missing or in the future", () => {
        for (const bad of [undefined, null, 0, -1, NaN, "x", NOW + 10 * MIN])
            assert.strictEqual(Age.age(bad, NOW), "", String(bad));
    });
});
