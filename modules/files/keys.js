.pragma library

var NAMED = [
    ["Key_Left", "Left"],
    ["Key_Right", "Right"],
    ["Key_Up", "Up"],
    ["Key_Down", "Down"],
    ["Key_Home", "Home"],
    ["Key_End", "End"],
    ["Key_PageUp", "PageUp"],
    ["Key_PageDown", "PageDown"],
    ["Key_Space", "Space"],
    ["Key_Tab", "Tab"],
    ["Key_Return", "Return"],
    ["Key_Enter", "Return"],
    ["Key_Backspace", "Backspace"],
    ["Key_Delete", "Delete"],
    ["Key_Escape", "Escape"],
    ["Key_F1", "F1"],
    ["Key_F2", "F2"],
    ["Key_F3", "F3"],
    ["Key_F4", "F4"],
    ["Key_F5", "F5"],
    ["Key_F6", "F6"],
    ["Key_Plus", "+"],
    ["Key_Equal", "="],
    ["Key_Minus", "-"],
    ["Key_Underscore", "_"],
    ["Key_Comma", ","],
    ["Key_Period", "."],
    ["Key_Slash", "/"],
    ["Key_Semicolon", ";"],
    ["Key_Apostrophe", "'"],
    ["Key_BracketLeft", "["],
    ["Key_BracketRight", "]"]
];

function names(qt) {
    var out = {};
    for (var i = 0; i < NAMED.length; i++)
        out[qt[NAMED[i][0]]] = NAMED[i][1];
    return out;
}

function chordOf(qt, table, key, modifiers, text) {
    var parts = [];
    if (modifiers & qt.ControlModifier)
        parts.push("Ctrl");
    if (modifiers & qt.AltModifier)
        parts.push("Alt");
    if (modifiers & qt.ShiftModifier)
        parts.push("Shift");

    var label = table[key] || "";
    if (!label && (key >= qt.Key_A && key <= qt.Key_Z || key >= qt.Key_0 && key <= qt.Key_9))
        label = String.fromCharCode(key);

    if (!label && parts.length === 0 && text && text.length === 1 && text.charCodeAt(0) >= 0x20 && text.charCodeAt(0) !== 0x7f)
        label = text;

    if (!label)
        return "";
    parts.push(label);
    return parts.join("+");
}
