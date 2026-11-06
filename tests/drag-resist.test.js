const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/drag-resist.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { resist } = new Function(src + "\nreturn { resist };")();

test.describe("drag give", () => {
    test.it("moves at the give up to the commit distance", () => {
        assert.strictEqual(resist(100, 200, 0.5), 50);
        assert.strictEqual(resist(-100, 200, 0.5), -50);
    });

    test.it("follows the pointer one to one past the commit distance", () => {
        assert.strictEqual(resist(300, 200, 0.5), 200);
        assert.strictEqual(resist(-500, 200, 0.5), -400);
    });

    test.it("is continuous at the commit distance", () => {
        assert.strictEqual(resist(200, 200, 0.5), resist(199.999, 200, 0.5) + 0.0005);
    });
});
