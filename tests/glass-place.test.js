const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/glass-place.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { windowOffset, placeOf, originOn } = new Function(src + "\nreturn { windowOffset, placeOf, originOn };")();

const IGNORE = 2;
const screen = { width: 2560, height: 1440 };

function layer(anchors, margins, width, height, mode = IGNORE) {
    return {
        anchors: Object.assign({ left: false, right: false, top: false, bottom: false }, anchors),
        margins: Object.assign({ left: 0, right: 0, top: 0, bottom: 0 }, margins),
        width,
        height,
        screen,
        exclusionMode: mode
    };
}

test.describe("where a window sits on its screen", () => {
    test.it("puts a full-screen layer at the corner", () => {
        assert.deepStrictEqual(windowOffset(layer({ left: true, right: true, top: true, bottom: true }, {}, 2560, 1440), IGNORE), { x: 0, y: 0 });
    });

    test.it("reads a top-left layer from its margins, the way the island sits", () => {
        assert.deepStrictEqual(windowOffset(layer({ left: true, top: true }, { left: 900, top: 12 }, 760, 300), IGNORE), { x: 900, y: 12 });
    });

    test.it("measures a right or bottom layer from the far edge", () => {
        assert.deepStrictEqual(windowOffset(layer({ right: true, bottom: true }, { right: 20, bottom: 30 }, 400, 200), IGNORE), { x: 2140, y: 1210 });
    });

    test.it("centres a layer anchored to neither side", () => {
        assert.deepStrictEqual(windowOffset(layer({}, {}, 560, 440), IGNORE), { x: 1000, y: 500 });
    });

    test.it("gives up on a layer that other layers can push aside", () => {
        assert.strictEqual(windowOffset(layer({ left: true, top: true }, {}, 100, 100, 0), IGNORE), null);
    });

    test.it("gives up on a floating window, which has no anchors", () => {
        assert.strictEqual(windowOffset({ width: 800, height: 600, screen }, IGNORE), null);
        assert.strictEqual(windowOffset(null, IGNORE), null);
    });
});

test.describe("where an item sits in its window", () => {
    test.it("adds every parent's position, scrolled content included", () => {
        const content = { x: 0, y: 0, parent: null };
        const list = { x: 40, y: 100, parent: content };
        const scrolled = { x: 0, y: -250, parent: list };
        const card = { x: 8, y: 300, parent: scrolled };
        assert.deepStrictEqual(placeOf(card), { x: 48, y: 150, beneath: false });
    });

    test.it("notices glass under it from any parent but not from itself", () => {
        const content = { x: 0, y: 0, parent: null };
        const panel = { x: 10, y: 10, parent: content, glassBeneath: true };
        const sheet = { x: 5, y: 5, parent: panel };
        assert.strictEqual(placeOf(sheet).beneath, true);
        assert.strictEqual(placeOf({ x: 0, y: 0, parent: content, glassBeneath: true }).beneath, false);
        assert.strictEqual(placeOf({ x: 0, y: 0, parent: { x: 0, y: 0, parent: null, glassBeneath: false } }).beneath, false);
    });
});

test.describe("where an item reads the backdrop", () => {
    test.it("subtracts the backdrop's own window and place", () => {
        assert.deepStrictEqual(originOn({ x: 900, y: 12 }, { x: 30, y: 40 }, { x: 0, y: 0 }, { x: 0, y: 0 }), { x: 930, y: 52 });
        assert.deepStrictEqual(originOn({ x: 0, y: 0 }, { x: 300, y: 200 }, { x: 0, y: 0 }, { x: 100, y: 50 }), { x: 200, y: 150 });
    });

    test.it("has no answer when either window cannot be placed", () => {
        assert.strictEqual(originOn(null, { x: 0, y: 0 }, { x: 0, y: 0 }, { x: 0, y: 0 }), null);
        assert.strictEqual(originOn({ x: 0, y: 0 }, { x: 0, y: 0 }, null, { x: 0, y: 0 }), null);
    });
});
