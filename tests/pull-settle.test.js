const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/pull-settle.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { completes } = new Function(src + "\nreturn { completes };")();

test.describe("a pull settling", () => {
    test.it("lets an opening pull finish on any release still moving forward", () => {
        assert.strictEqual(completes(0.02, 0.1, 0.25, 3, 0), true);
    });

    test.it("lets an opening pull finish past the commit point after a small reversal", () => {
        assert.strictEqual(completes(0.4, -1, 0.25, 3, 0), true);
        assert.strictEqual(completes(0.4, -5, 0.25, 3, 0), false);
    });

    test.it("keeps a reluctant pull open after a small nudge", () => {
        assert.strictEqual(completes(0.02, 0.5, 0.25, 3, 4), false);
    });

    test.it("closes a reluctant pull past the commit point", () => {
        assert.strictEqual(completes(0.3, 0.5, 0.25, 3, 4), true);
        assert.strictEqual(completes(0.3, -5, 0.25, 3, 4), false);
    });

    test.it("closes a reluctant pull on a flick however short", () => {
        assert.strictEqual(completes(0.02, 4, 0.25, 3, 4), true);
    });
});
