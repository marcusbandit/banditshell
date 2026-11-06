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
    Key_A: 0x41,
    ControlModifier: 0x04000000,
    ShiftModifier: 0x02000000,
    AltModifier: 0x08000000,
    MetaModifier: 0x10000000
};

const src = fs.readFileSync(path.join(ROOT, "modules/launcher/search.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Search = new Function("Qt", `${src}\nreturn { stepTarget, shiftTarget, caretKey, opensSheet, nextPickable };`)(Qt);

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
});
