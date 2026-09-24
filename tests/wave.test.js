// components/wave.js: the scrubber's wave is fixed at its START.
//
// Every case here is about the anchor. The polyline exists so the pip can
// uncover more of one wave without moving what is already drawn, so the
// property worth checking is not "does it look like a sine" but "does a point
// at a given x stay put while everything about the length changes".

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

// The source is a QML .js import: no exports, so it is read and evaluated, and
// the names it declares are handed back by the trailing return. The `.pragma`
// line is QML's, not JavaScript's, so it goes before the evaluation.
const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/wave.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Wave = new Function(src + "\nreturn { points };")();

const close = (a, b) => Math.abs(a - b) < 1e-9;

test.describe("wave", () => {
    test.it("runs from 0 to exactly the length", () => {
        const pts = Wave.points(100.7, 4, 28, 0, 2);
        assert.strictEqual(pts[0][0], 0);
        assert.strictEqual(pts[pts.length - 1][0], 100.7);
    });

    test.it("has one point per step plus the end", () => {
        assert.strictEqual(Wave.points(100.7, 4, 28, 0, 2).length, Math.ceil(100.7 / 2) + 1);
        assert.strictEqual(Wave.points(100, 4, 28, 0, 2).length, 51);
    });

    test.it("never swings past the amplitude", () => {
        for (const [, y] of Wave.points(300, 4, 28, 1.3, 1))
            assert.ok(Math.abs(y) <= 4 + 1e-9);
    });

    test.it("is fixed at the start, whatever the length", () => {
        const phase = 0.7;
        for (const length of [5, 28, 61.5, 300]) {
            const pts = Wave.points(length, 4, 28, phase, 2);
            assert.ok(close(pts[0][1], -4 * Math.sin(phase)), `length ${length}`);
        }
    });

    test.it("only uncovers more of the same wave as the length grows", () => {
        const short = Wave.points(40, 4, 28, 1.1, 2);
        const long = Wave.points(300, 4, 28, 1.1, 2);
        for (let i = 0; i < short.length - 1; i++) {
            assert.strictEqual(long[i][0], short[i][0]);
            assert.ok(close(long[i][1], short[i][1]), `point ${i}`);
        }
    });

    test.it("wraps after one full phase", () => {
        const a = Wave.points(120, 4, 28, 0, 2);
        const b = Wave.points(120, 4, 28, 2 * Math.PI, 2);
        assert.strictEqual(a.length, b.length);
        for (let i = 0; i < a.length; i++)
            assert.ok(close(a[i][1], b[i][1]), `point ${i}`);
    });

    test.it("is nothing when there is no length", () => {
        assert.deepStrictEqual(Wave.points(0, 4, 28, 0, 2), []);
        assert.deepStrictEqual(Wave.points(-3, 4, 28, 0, 2), []);
    });

    test.it("survives a wavelength or step of nothing", () => {
        assert.ok(Wave.points(10, 4, 0, 0, 2).length > 0);
        assert.ok(Wave.points(10, 4, 28, 0, 0).length > 0);
    });
});
