const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/controls/secret-marks.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Marks = new Function(src + "\nreturn { FAMILY, shape };")();

test("every mark fits its cell", () => {
    for (const form of Marks.FAMILY) {
        assert.ok(form.width > 0 && form.width <= 1);
        assert.ok(form.height > 0 && form.height <= 1);
    }
});

test("neighbours never share a shape", () => {
    for (let i = 0; i < Marks.FAMILY.length * 3; i++)
        assert.notStrictEqual(Marks.shape(i), Marks.shape(i + 1));
});

test("the shape comes from the position and wraps both ways", () => {
    const n = Marks.FAMILY.length;
    assert.strictEqual(Marks.shape(0), Marks.shape(n));
    assert.strictEqual(Marks.shape(-1), Marks.shape(n - 1));
    assert.strictEqual(Marks.shape(2.7), Marks.shape(2));
});
