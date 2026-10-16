const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.resolve(__dirname, "../components/squircle.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Squircle = new Function(`${src}\nreturn { path, outline };`)();

test.describe("squircle outlines", () => {
    test.it("hands back the same outline it would draw, from memory the second time", () => {
        const fresh = Squircle.outline(120, 40, 12, 12, 12, 12, 4);
        assert.strictEqual(Squircle.path(120, 40, 12, 12, 12, 12, 4), fresh);
        assert.strictEqual(Squircle.path(120, 40, 12, 12, 12, 12, 4), fresh);
    });

    test.it("keeps different shapes apart, offsets included", () => {
        assert.notStrictEqual(Squircle.path(120, 40, 12, 12, 12, 12, 4), Squircle.path(120, 41, 12, 12, 12, 12, 4));
        assert.notStrictEqual(Squircle.path(10, 10, 3, 3, 3, 3, 4, 0, 0), Squircle.path(10, 10, 3, 3, 3, 3, 4, 5, 0));
        assert.strictEqual(Squircle.path(0, 10, 3, 3, 3, 3, 4), "");
    });
});
