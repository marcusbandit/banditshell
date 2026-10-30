const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Columns = lib("modules/files/row-columns.js", ["flow"]);

test.describe("sort headers in icon view", () => {
    test.it("keeps headers on one line while they fit, exact fit included", () => {
        assert.deepStrictEqual(Columns.flow([40, 30, 20], 0, 110, 10), [{x: 0, line: 0}, {x: 50, line: 0}, {x: 90, line: 0}]);
    });

    test.it("moves a header that would cross the edge to the next line", () => {
        assert.deepStrictEqual(Columns.flow([40, 30, 20, 50], 4, 100, 10).map(p => p.line), [0, 0, 1, 1]);
        assert.strictEqual(Columns.flow([40, 30, 20, 50], 4, 100, 10)[2].x, 4);
    });

    test.it("never leaves a line empty for a header wider than the row", () => {
        assert.deepStrictEqual(Columns.flow([200, 30], 0, 100, 10), [{x: 0, line: 0}, {x: 0, line: 1}]);
    });

    test.it("keeps one line before the header has a width", () => {
        assert.deepStrictEqual(Columns.flow([40, 30, 20, 50], 4, 0, 10).map(p => p.line), [0, 0, 0, 0]);
    });
});
