const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

const Qt = {
    Key_Home: 0x01000010,
    Key_End: 0x01000011,
    Key_Left: 0x01000012,
    Key_Right: 0x01000014,
    Key_Menu: 0x01000055,
    Key_F10: 0x01000039,
    Key_K: 0x4b,
    Key_Return: 0x01000004,
    Key_Enter: 0x01000005,
    Key_A: 0x41,
    ControlModifier: 0x04000000,
    ShiftModifier: 0x02000000,
    AltModifier: 0x08000000,
    MetaModifier: 0x10000000
};

const src = fs.readFileSync(path.join(ROOT, "modules/launcher/search.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Search = new Function("Qt", `${src}\nreturn { stepTarget, shiftTarget, caretKey, opensSheet, nextPickable, foldedActions, gridSpot, nearestTile, draggedSlot };`)(Qt);

const ROWS = [{ label: "answer" }, { label: "one" }, { label: "two" }, { label: "three" }];

test.describe("stepping away from a held answer", () => {
    test.it("selects the first result with the first Down", () => {
        assert.strictEqual(Search.stepTarget(ROWS, 0, 1, true), 0);
    });

    test.it("keeps the answer on the first Up instead of wrapping to the last row", () => {
        assert.strictEqual(Search.stepTarget(ROWS, 0, -1, true), -1);
    });

    test.it("moves a row at a time once the answer is let go", () => {
        assert.strictEqual(Search.stepTarget(ROWS, 0, 1, false), 1);
        assert.strictEqual(Search.stepTarget(ROWS, 0, -1, false), 3);
    });

    test.it("skips a header when stepping off the answer", () => {
        const rows = [{ header: true }, { label: "one" }, { label: "two" }];
        assert.strictEqual(Search.stepTarget(rows, 0, 1, true), 1);
    });
});

test.describe("moving a pinned tile", () => {
    test.it("stays inside the visible pins", () => {
        assert.strictEqual(Search.shiftTarget(11, 1, 12), -1);
        assert.strictEqual(Search.shiftTarget(0, -1, 12), -1);
        assert.strictEqual(Search.shiftTarget(3, 1, 12), 4);
        assert.strictEqual(Search.shiftTarget(3, -1, 12), 2);
    });

    test.it("ignores a tile that is not pinned", () => {
        assert.strictEqual(Search.shiftTarget(-1, 1, 12), -1);
    });
});

test.describe("keys that belong to the query text", () => {
    test.it("leaves Home, End, Left and Right to the caret while the query has text", () => {
        for (const key of [Qt.Key_Home, Qt.Key_End, Qt.Key_Left, Qt.Key_Right])
            assert.strictEqual(Search.caretKey(key, true, false), true, String(key));
    });

    test.it("hands them to the list when the field is empty or the list was entered", () => {
        for (const key of [Qt.Key_Home, Qt.Key_End, Qt.Key_Left, Qt.Key_Right]) {
            assert.strictEqual(Search.caretKey(key, false, false), false, String(key));
            assert.strictEqual(Search.caretKey(key, true, true), false, String(key));
        }
    });

    test.it("does not touch other keys", () => {
        assert.strictEqual(Search.caretKey(Qt.Key_A, true, false), false);
    });
});

test.describe("opening the actions sheet", () => {
    test.it("answers to Menu, Ctrl+K and Shift+F10", () => {
        assert.strictEqual(Search.opensSheet(Qt.Key_Menu, 0), true);
        assert.strictEqual(Search.opensSheet(Qt.Key_K, Qt.ControlModifier), true);
        assert.strictEqual(Search.opensSheet(Qt.Key_F10, Qt.ShiftModifier), true);
    });

    test.it("leaves a bare K and other chords alone", () => {
        assert.strictEqual(Search.opensSheet(Qt.Key_K, 0), false);
        assert.strictEqual(Search.opensSheet(Qt.Key_K, Qt.ControlModifier | Qt.ShiftModifier), false);
        assert.strictEqual(Search.opensSheet(Qt.Key_F10, 0), false);
        assert.strictEqual(Search.opensSheet(Qt.Key_K, Qt.AltModifier), false);
    });

    test.it("answers to Ctrl+Enter on the app grid, where Enter alone opens the app", () => {
        assert.strictEqual(Search.opensSheet(Qt.Key_Return, Qt.ControlModifier, true), true);
        assert.strictEqual(Search.opensSheet(Qt.Key_Enter, Qt.ControlModifier, true), true);
        assert.strictEqual(Search.opensSheet(Qt.Key_Return, 0, true), false);
        assert.strictEqual(Search.opensSheet(Qt.Key_Return, Qt.ControlModifier, false), false);
    });
});

test.describe("folding an app's own actions", () => {
    const own = n => Array.from({ length: n }, (_, i) => ({ label: `action ${i}` }));

    test.it("keeps a short list inline", () => {
        assert.deepStrictEqual(Search.foldedActions(own(4), "Steam actions", 4), own(4));
        assert.deepStrictEqual(Search.foldedActions(undefined, "Steam actions", 4), []);
    });

    test.it("puts a long list under one row named for the app", () => {
        const folded = Search.foldedActions(own(9), "Steam actions", 4);
        assert.strictEqual(folded.length, 1);
        assert.strictEqual(folded[0].label, "Steam actions");
        assert.deepStrictEqual(folded[0].children, own(9));
    });
});

test.describe("dragging a pinned app to a new place", () => {
    test.it("centres a short last row under the full one", () => {
        assert.deepStrictEqual(Search.gridSpot(0, 11, 6), { row: 0, slot: -2.5 });
        assert.deepStrictEqual(Search.gridSpot(6, 11, 6), { row: 1, slot: -2 });
        assert.deepStrictEqual(Search.gridSpot(10, 11, 6), { row: 1, slot: 2 });
    });

    test.it("drops on the tile nearest the pointer", () => {
        const cell = 100;
        const middle = 300;
        assert.strictEqual(Search.nearestTile(50, 50, 11, 6, cell, middle), 0);
        assert.strictEqual(Search.nearestTile(560, 40, 11, 6, cell, middle), 5);
        assert.strictEqual(Search.nearestTile(300, 150, 11, 6, cell, middle), 8);
        assert.strictEqual(Search.nearestTile(-400, 900, 11, 6, cell, middle), 6);
    });

    test.it("slides the tiles between the old and new place over by one", () => {
        const order = (from, to) => [0, 1, 2, 3, 4].map(i => Search.draggedSlot(i, from, to));
        assert.deepStrictEqual(order(1, 3), [0, 3, 1, 2, 4]);
        assert.deepStrictEqual(order(3, 0), [1, 2, 3, 0, 4]);
        assert.deepStrictEqual(order(2, 2), [0, 1, 2, 3, 4]);
        assert.deepStrictEqual(order(-1, -1), [0, 1, 2, 3, 4]);
    });
});
