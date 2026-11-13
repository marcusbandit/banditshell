const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/files/keys.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Keys = new Function(src + "\nreturn { names, chordOf, NAMED, windowOwns, previewScroll, holder, moved, sameKeys, gridStep };")();

const Qt = {
    ShiftModifier: 0x02000000,
    ControlModifier: 0x04000000,
    AltModifier: 0x08000000,
    MetaModifier: 0x10000000,
    Key_Escape: 0x01000000,
    Key_Tab: 0x01000001,
    Key_Backspace: 0x01000003,
    Key_Return: 0x01000004,
    Key_Enter: 0x01000005,
    Key_Delete: 0x01000007,
    Key_Home: 0x01000010,
    Key_End: 0x01000011,
    Key_Left: 0x01000012,
    Key_Up: 0x01000013,
    Key_Right: 0x01000014,
    Key_Down: 0x01000015,
    Key_PageUp: 0x01000016,
    Key_PageDown: 0x01000017,
    Key_F1: 0x01000030,
    Key_F2: 0x01000031,
    Key_F3: 0x01000032,
    Key_F4: 0x01000033,
    Key_F5: 0x01000034,
    Key_F6: 0x01000035,
    Key_Space: 0x20,
    Key_Apostrophe: 0x27,
    Key_Plus: 0x2b,
    Key_Comma: 0x2c,
    Key_Minus: 0x2d,
    Key_Period: 0x2e,
    Key_Slash: 0x2f,
    Key_0: 0x30,
    Key_9: 0x39,
    Key_Semicolon: 0x3b,
    Key_Equal: 0x3d,
    Key_A: 0x41,
    Key_Z: 0x5a,
    Key_BracketLeft: 0x5b,
    Key_BracketRight: 0x5d,
    Key_Underscore: 0x5f,
    Key_Question: 0x3f,
    Key_Control: 0x01000021
};

const table = Keys.names(Qt);
const chord = (key, modifiers, text) => Keys.chordOf(Qt, table, key, modifiers || 0, text || "");

test.describe("keys: one reading of a key press for the router and the recorder", () => {
    test.it("names every key it lists from the enum it is handed", () => {
        for (const [name, label] of Keys.NAMED)
            assert.strictEqual(table[Qt[name]], label, name);
    });

    test.it("records the punctuation chords the settings copy used to drop", () => {
        assert.strictEqual(chord(Qt.Key_Comma, Qt.ControlModifier), "Ctrl+,");
        assert.strictEqual(chord(Qt.Key_Semicolon, Qt.ControlModifier), "Ctrl+;");
        assert.strictEqual(chord(Qt.Key_Apostrophe, Qt.AltModifier), "Alt+'");
        assert.strictEqual(chord(Qt.Key_BracketLeft, Qt.ControlModifier), "Ctrl+[");
        assert.strictEqual(chord(Qt.Key_BracketRight, Qt.ControlModifier), "Ctrl+]");
    });

    test.it("orders modifiers Ctrl, Alt, Shift", () => {
        const all = Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier;
        assert.strictEqual(chord(Qt.Key_Left, all), "Ctrl+Alt+Shift+Left");
    });

    test.it("spells letters and digits by their key, not their text", () => {
        assert.strictEqual(chord(0x4a, Qt.ControlModifier, "\n"), "Ctrl+J");
        assert.strictEqual(chord(0x34, Qt.ControlModifier), "Ctrl+4");
        assert.strictEqual(chord(0x4e, Qt.ControlModifier | Qt.ShiftModifier), "Ctrl+Shift+N");
    });

    test.it("falls back to the typed character only for a bare printable key", () => {
        assert.strictEqual(chord(Qt.Key_Question, 0, "?"), "?");
        assert.strictEqual(chord(Qt.Key_Question, Qt.ShiftModifier, "?"), "");
        assert.strictEqual(chord(0x01001234, 0, "\x7f"), "");
        assert.strictEqual(chord(0x01001234, 0, "\x1b"), "");
    });

    test.it("gives nothing for a lone modifier", () => {
        assert.strictEqual(chord(Qt.Key_Control, Qt.ControlModifier), "");
    });
});

test.describe("keys: what the window keeps while the terminal has focus", () => {
    test.it("keeps Ctrl plus a digit and the terminal toggle", () => {
        for (const digit of "0123456789")
            assert.ok(Keys.windowOwns(`Ctrl+${digit}`, "focus:grid"), digit);
        assert.ok(Keys.windowOwns("Ctrl+J", "terminal"));
    });

    test.it("keeps a chord the user rebound to move focus, whatever its keys", () => {
        assert.ok(Keys.windowOwns("Ctrl+K", "focus:grid"));
        assert.ok(Keys.windowOwns("Alt+P", "focus:preview"));
    });

    test.it("hands everything else to the shell inside, tmux prefix and word jumps included", () => {
        for (const [key, action] of [["Ctrl+B", "sidebar"], ["Alt+Left", "back"], ["Alt+Right", "forward"], ["Alt+Up", "parent"], ["Alt+Home", "home"], ["Ctrl+,", "settings"], ["Ctrl+A", "all"]])
            assert.ok(!Keys.windowOwns(key, action), key);
    });
});

test.describe("keys: scrolling the preview from the keyboard", () => {
    const scroll = (key, modifiers, action) => Keys.previewScroll(Qt, key, modifiers || 0, action || "", 300, 20);

    test.it("moves a line on the arrows and a page on the page keys", () => {
        assert.strictEqual(scroll(Qt.Key_Down), 20);
        assert.strictEqual(scroll(Qt.Key_Up), -20);
        assert.strictEqual(scroll(Qt.Key_PageDown), 300);
        assert.strictEqual(scroll(Qt.Key_PageUp), -300);
    });

    test.it("jumps to either end on Home and End", () => {
        assert.strictEqual(scroll(Qt.Key_Home), -Infinity);
        assert.strictEqual(scroll(Qt.Key_End), Infinity);
    });

    test.it("pages on Space and back on Shift+Space", () => {
        assert.strictEqual(scroll(Qt.Key_Space), 300);
        assert.strictEqual(scroll(Qt.Key_Space, Qt.ShiftModifier), -300);
    });

    test.it("follows the vim letters of the grid map", () => {
        assert.strictEqual(scroll(0x6a, 0, "down"), 20);
        assert.strictEqual(scroll(0x6b, 0, "up"), -20);
        assert.strictEqual(scroll(0x67, 0, "first"), -Infinity);
        assert.strictEqual(scroll(0x47, 0, "last"), Infinity);
    });

    test.it("ignores chords and keys it has no scroll for", () => {
        assert.strictEqual(scroll(Qt.Key_Down, Qt.ControlModifier), null);
        assert.strictEqual(scroll(Qt.Key_Left), null);
        assert.strictEqual(scroll(Qt.Key_Return), null);
    });
});

test.describe("rebinding file browser keys", () => {
    const map = {j: "down", k: "up", "Ctrl+F": "search", "/": "search"};

    test.it("names the action that already holds the chord", () => {
        assert.strictEqual(Keys.holder(map, "k", "j"), "down");
        assert.strictEqual(Keys.holder(map, "k", "x"), "");
        assert.strictEqual(Keys.holder(map, "k", "k"), "");
    });

    test.it("does not count a chord of the same action as taken", () => {
        assert.strictEqual(Keys.holder(map, "/", "Ctrl+F"), "");
    });

    test.it("moves the action to the new chord and drops the one that held it", () => {
        assert.deepStrictEqual(Keys.moved(map, "k", "j"), {"Ctrl+F": "search", "/": "search", j: "up"});
        assert.deepStrictEqual(map, {j: "down", k: "up", "Ctrl+F": "search", "/": "search"});
    });

    test.it("compares a keymap to its defaults whatever the key order", () => {
        assert.strictEqual(Keys.sameKeys({a: "x", b: "y"}, {b: "y", a: "x"}), true);
        assert.strictEqual(Keys.sameKeys({a: "x"}, {a: "z"}), false);
        assert.strictEqual(Keys.sameKeys({a: "x"}, {a: "x", b: "y"}), false);
    });
});

test.describe("stepping rows in the file grid", () => {
    test.it("moves a whole row and keeps the column", () => {
        assert.deepStrictEqual(Keys.gridStep(1, 10, 4, 1, -1), { to: 5, goal: 1 });
        assert.deepStrictEqual(Keys.gridStep(5, 10, 4, -1, -1), { to: 1, goal: 1 });
    });

    test.it("lands on the last file when the row below is shorter", () => {
        assert.deepStrictEqual(Keys.gridStep(7, 10, 4, 1, -1), { to: 9, goal: 3 });
    });

    test.it("goes back to the column it started in on the way up", () => {
        assert.strictEqual(Keys.gridStep(9, 10, 4, -1, 3).to, 7);
    });

    test.it("stops at the first and last file and forgets the column", () => {
        assert.deepStrictEqual(Keys.gridStep(2, 10, 4, -1, -1), { to: 0, goal: -1 });
        assert.deepStrictEqual(Keys.gridStep(8, 10, 4, 1, -1), { to: 9, goal: -1 });
    });

    test.it("keeps the column when the key has nowhere further to go", () => {
        assert.deepStrictEqual(Keys.gridStep(9, 10, 4, 1, 3), { to: 9, goal: 3 });
    });

    test.it("starts at the first file when nothing is selected", () => {
        assert.deepStrictEqual(Keys.gridStep(-1, 10, 4, 1, -1), { to: 0, goal: -1 });
    });

    test.it("has nowhere to go in an empty folder", () => {
        assert.strictEqual(Keys.gridStep(-1, 0, 4, 1, -1).to, -1);
    });
});
