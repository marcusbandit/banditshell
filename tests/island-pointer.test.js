const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/island/pointer-watch.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Pointer = new Function(src + "\nreturn { gap, nextCheck };")();

test.describe("island pointer watch", () => {
    test.it("measures no gap inside the zone and the straight distance outside it", () => {
        assert.strictEqual(Pointer.gap(50, 50, 0, 0, 100, 100), 0);
        assert.strictEqual(Pointer.gap(103, 104, 0, 0, 100, 100), 5);
        assert.strictEqual(Pointer.gap(-40, 50, 0, 0, 100, 100), 40);
    });

    test.it("never waits long enough for a pointer at full speed to reach the zone unseen", () => {
        for (const distance of [0, 10, 320, 800, 1600, 5000]) {
            const wait = Pointer.nextCheck(distance, 80, 400, 10000);
            assert.ok(wait >= 80 && wait <= 400, `${distance}: ${wait}`);
            assert.ok(wait <= 80 || distance / 10000 * 1000 >= wait - 1, `${distance}: ${wait}`);
        }
    });
});
