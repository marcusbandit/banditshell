const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/picker/picker-place.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { clampRect, span, readoutAt } = new Function(src + "\nreturn { clampRect, span, readoutAt };")();

const W = 2560;
const H = 1440;

test.describe("selection stays on its screen", () => {
    test.it("cuts a window that hangs off the screen", () => {
        assert.deepStrictEqual(clampRect(-40, 1300, 800, 600, W, H), { x: 0, y: 1300, width: 760, height: 140 });
    });

    test.it("leaves a window inside the screen alone", () => {
        assert.deepStrictEqual(clampRect(100, 200, 300, 400, W, H), { x: 100, y: 200, width: 300, height: 400 });
    });

    test.it("stops a drag at the edge of the screen it started on", () => {
        assert.deepStrictEqual(span(2400, 100, 3100, -50, W, H), { x: 2400, y: 0, width: 160, height: 100 });
        assert.deepStrictEqual(span(300, 300, 100, 200, W, H), { x: 100, y: 200, width: 200, height: 100 });
    });
});

test.describe("readout placement", () => {
    test.it("sits below a selection with room under it", () => {
        assert.deepStrictEqual(readoutAt({ x: 1000, y: 400, width: 400, height: 300 }, 200, 40, W, H, 12), { x: 1100, y: 712 });
    });

    test.it("goes above when the bottom is full", () => {
        assert.deepStrictEqual(readoutAt({ x: 1000, y: 800, width: 400, height: 620 }, 200, 40, W, H, 12), { x: 1100, y: 748 });
    });

    test.it("stays on screen inside a selection that fills the screen", () => {
        const at = readoutAt({ x: 0, y: 0, width: W, height: H }, 200, 40, W, H, 12);
        assert.deepStrictEqual(at, { x: 1180, y: H - 40 - 24 });
    });

    test.it("never leaves the screen sideways", () => {
        assert.strictEqual(readoutAt({ x: 0, y: 400, width: 10, height: 10 }, 200, 40, W, H, 12).x, 12);
        assert.strictEqual(readoutAt({ x: W - 10, y: 400, width: 10, height: 10 }, 200, 40, W, H, 12).x, W - 212);
    });
});
