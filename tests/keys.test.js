const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/files/keys.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Keys = new Function(src + "\nreturn { names, chordOf, NAMED };")();

const Qt = {
    ShiftModifier: 0x02000000,
    ControlModifier: 0x04000000,
    AltModifier: 0x08000000,
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
