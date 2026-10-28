const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/focus-chain.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Chain = new Function(src + "\nreturn { readingOrder, step, page, group, reveal, cut, nearest, last };")();

const LINE = 40;
const box = (x, y, w, h) => ({ x, y, w, h });

test.describe("readingOrder", () => {
    test.it("reads top to bottom, then left to right, a container before what it holds", () => {
        const rects = [box(200, 40, 40, 20), box(0, 40, 300, 40), box(0, 0, 300, 40), box(0, 40, 100, 40)];
        assert.deepStrictEqual(Chain.readingOrder(rects), [2, 1, 3, 0]);
    });
});

test.describe("step", () => {
    const list = [box(0, 0, 300, 40), box(0, 44, 300, 40), box(0, 88, 300, 40)];

    test.it("moves down and up a list of rows", () => {
        assert.strictEqual(Chain.step(list, 0, "down", LINE), 1);
        assert.strictEqual(Chain.step(list, 1, "down", LINE), 2);
        assert.strictEqual(Chain.step(list, 2, "up", LINE), 1);
    });

    test.it("stops at the ends instead of wrapping", () => {
        assert.strictEqual(Chain.step(list, 2, "down", LINE), -1);
        assert.strictEqual(Chain.step(list, 0, "up", LINE), -1);
    });

    test.it("finds nothing sideways in a plain list", () => {
        assert.strictEqual(Chain.step(list, 1, "right", LINE), -1);
        assert.strictEqual(Chain.step(list, 1, "left", LINE), -1);
    });

    test.it("reaches a switch inside a row sideways, and leaves it downwards", () => {
        const rects = [box(0, 0, 300, 40), box(240, 10, 48, 20), box(0, 44, 300, 40)];
        assert.strictEqual(Chain.step(rects, 0, "right", LINE), 1);
        assert.strictEqual(Chain.step(rects, 1, "left", LINE), 0);
        assert.strictEqual(Chain.step(rects, 0, "down", LINE), 2);
        assert.strictEqual(Chain.step(rects, 1, "down", LINE), 2);
        assert.strictEqual(Chain.step(rects, 2, "up", LINE), 0);
    });

    test.it("goes up from a switch to the row above, not to its own row", () => {
        const rects = [box(0, 0, 300, 40), box(0, 44, 300, 40), box(240, 54, 48, 20)];
        assert.strictEqual(Chain.step(rects, 2, "up", LINE), 0);
    });

    test.it("enters what an open card holds below its first line, and comes back up to it", () => {
        const rects = [box(0, 0, 300, 200), box(240, 10, 48, 20), box(10, 60, 50, 40), box(100, 60, 50, 40), box(0, 210, 300, 40)];
        assert.strictEqual(Chain.step(rects, 0, "down", LINE), 2);
        assert.strictEqual(Chain.step(rects, 2, "up", LINE), 0);
        assert.strictEqual(Chain.step(rects, 0, "right", LINE), 1);
        assert.strictEqual(Chain.step(rects, 2, "left", LINE), -1);
    });

    test.it("picks the button under the one it leaves", () => {
        const rects = [box(0, 0, 50, 40), box(60, 0, 50, 40), box(200, 4, 100, 36), box(0, 50, 70, 36), box(76, 50, 70, 36), box(152, 50, 70, 36), box(228, 50, 70, 36)];
        assert.strictEqual(Chain.step(rects, 2, "down", LINE), 6);
        assert.strictEqual(Chain.step(rects, 0, "down", LINE), 3);
        assert.strictEqual(Chain.step(rects, 1, "right", LINE), 2);
        assert.strictEqual(Chain.step(rects, 2, "left", LINE), 1);
        assert.strictEqual(Chain.step(rects, 4, "right", LINE), 5);
    });

    test.it("lands on the first of several buttons below a full width row", () => {
        const rects = [box(0, 0, 300, 40), box(0, 44, 140, 36), box(160, 44, 140, 36)];
        assert.strictEqual(Chain.step(rects, 0, "down", LINE), 1);
        assert.strictEqual(Chain.step(rects, 2, "up", LINE), 0);
    });

    test.it("never moves sideways onto something on another line", () => {
        const rects = [box(200, 0, 40, 40), box(0, 50, 300, 40)];
        assert.strictEqual(Chain.step(rects, 1, "right", LINE), -1);
    });

    test.it("does nothing from a position that is not in the list", () => {
        assert.strictEqual(Chain.step(list, -1, "down", LINE), -1);
        assert.strictEqual(Chain.step(list, 7, "down", LINE), -1);
    });
});

test.describe("page", () => {
    const rows = [];
    for (let i = 0; i < 20; i++)
        rows.push(box(0, i * 40, 300, 40));

    test.it("goes as far as a page reaches", () => {
        assert.strictEqual(Chain.page(rows, 0, true, 200), 5);
        assert.strictEqual(Chain.page(rows, 10, false, 200), 5);
    });

    test.it("still moves one when the next row is more than a page away", () => {
        const sparse = [box(0, 0, 300, 40), box(0, 500, 300, 40)];
        assert.strictEqual(Chain.page(sparse, 0, true, 200), 1);
    });

    test.it("stays put at the end", () => {
        assert.strictEqual(Chain.page(rows, 19, true, 200), -1);
    });
});

test.describe("group", () => {
    const groups = ["output", "output", "input", "input", "devices", "devices", "devices"];

    test.it("tabs to the first item of the next group and wraps", () => {
        assert.strictEqual(Chain.group(groups, 0, true), 2);
        assert.strictEqual(Chain.group(groups, 3, true), 4);
        assert.strictEqual(Chain.group(groups, 6, true), 0);
    });

    test.it("shift tabs to the first item of the previous group and wraps", () => {
        assert.strictEqual(Chain.group(groups, 5, false), 2);
        assert.strictEqual(Chain.group(groups, 3, false), 0);
        assert.strictEqual(Chain.group(groups, 1, false), 4);
    });

    test.it("starts at the first or last group when nothing has focus", () => {
        assert.strictEqual(Chain.group(groups, -1, true), 0);
        assert.strictEqual(Chain.group(groups, -1, false), 4);
    });

    test.it("treats every ungrouped item as a group of its own", () => {
        const loose = ["", "", "list", "list", ""];
        assert.strictEqual(Chain.group(loose, 0, true), 1);
        assert.strictEqual(Chain.group(loose, 1, true), 2);
        assert.strictEqual(Chain.group(loose, 2, true), 4);
        assert.strictEqual(Chain.group(loose, 4, true), 0);
    });

    test.it("finds nothing in an empty menu", () => {
        assert.strictEqual(Chain.group([], -1, true), -1);
    });
});

test.describe("reveal", () => {
    test.it("leaves the view alone while the item is inside it", () => {
        assert.strictEqual(Chain.reveal(100, 300, 150, 190, 8), 100);
    });

    test.it("scrolls up just enough to show an item above", () => {
        assert.strictEqual(Chain.reveal(100, 300, 60, 100, 8), 52);
    });

    test.it("scrolls down just enough to show an item below", () => {
        assert.strictEqual(Chain.reveal(100, 300, 380, 420, 8), 128);
    });

    test.it("shows the top of an item taller than the view", () => {
        assert.strictEqual(Chain.reveal(0, 300, 200, 700, 8), 192);
    });
});

test.describe("cut", () => {
    test.it("keeps the part of a control a clipping parent still shows", () => {
        assert.deepStrictEqual(Chain.cut(box(0, 0, 300, 100), box(0, 80, 300, 44)), box(0, 80, 300, 20));
    });

    test.it("leaves nothing of a control inside a folded layer", () => {
        const left = Chain.cut(box(0, 120, 300, 0), box(10, 120, 290, 44));
        assert.strictEqual(left.w * left.h, 0);
    });

    test.it("passes a control through when nothing clips it", () => {
        assert.deepStrictEqual(Chain.cut(null, box(1, 2, 3, 4)), box(1, 2, 3, 4));
    });
});

test.describe("nearest", () => {
    test.it("finds the control that took the place of one rebuilt under the keys", () => {
        const rects = [box(0, 0, 300, 40), box(0, 44, 300, 80), box(0, 128, 300, 40)];
        assert.strictEqual(Chain.nearest(rects, box(0, 46, 300, 80)), 1);
    });

    test.it("falls back to a neighbour when the control is gone for good", () => {
        const rects = [box(0, 0, 300, 40), box(250, 44, 50, 40), box(0, 140, 300, 40)];
        assert.strictEqual(Chain.nearest(rects, box(0, 100, 300, 40)), 2);
        assert.strictEqual(Chain.nearest([], box(0, 0, 1, 1)), -1);
    });
});

test.describe("last", () => {
    test.it("ends on the last row, not on the button inside it", () => {
        const rects = [box(0, 0, 300, 40), box(0, 44, 300, 40), box(250, 48, 36, 36)];
        assert.strictEqual(Chain.last(rects), 1);
    });

    test.it("ends on the first of the buttons that share the last line", () => {
        const rects = [box(0, 0, 300, 40), box(0, 44, 140, 36), box(160, 46, 140, 36)];
        assert.strictEqual(Chain.last(rects), 1);
        assert.strictEqual(Chain.last([box(0, 0, 10, 10)]), 0);
    });
});
