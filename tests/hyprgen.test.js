// services/hyprgen.js: the Hyprland config, scanned, composed, spliced.
//
// Everything tested here is the behaviour that breaks SILENTLY. A scanner
// that misreads a long-bracket string does not throw; it hands the editor a
// bind that is not there, and the editor writes garbage into the one file
// the user cannot afford to lose. A splice with the wrong bounds does not
// fail either; it eats a comment. Neither has a runtime error to catch,
// which is why they are caught here -- with the real shapes from a real
// binds.lua: multi-line binds, loops, submap functions, escapes.

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/hyprgen.js"), "utf8");
const HyprGen = new Function(src
    + "\nreturn { parseChord, luaString, luaUnescape, scanLua, composeBind, spliceLines };")();

// ------------------------------------------------------------------ chords

test("chords parse into modifiers and a key", () => {
    assert.deepStrictEqual(HyprGen.parseChord("SUPER + SHIFT + Slash"), {
        mods: ["SUPER", "SHIFT"], key: "Slash", mask: 65
    });
    assert.deepStrictEqual(HyprGen.parseChord("XF86Calculator"), {
        mods: [], key: "XF86Calculator", mask: 0
    });
    assert.deepStrictEqual(HyprGen.parseChord("SUPER + grave"), {
        mods: ["SUPER"], key: "grave", mask: 64
    });
    // A repeated modifier counts once.
    assert.strictEqual(HyprGen.parseChord("SUPER + SUPER + A").mask, 64);
    // No key means the chord does not parse, which the editor refuses.
    assert.strictEqual(HyprGen.parseChord("").key, "");
});

// ------------------------------------------------------------- lua strings

test("lua strings escape everything that could end the string", () => {
    assert.strictEqual(HyprGen.luaString('say "hi"'), 'say \\"hi\\"');
    assert.strictEqual(HyprGen.luaString("back\\slash"), "back\\\\slash");
    assert.strictEqual(HyprGen.luaString("one\ntwo"), "one\\ntwo");
    assert.strictEqual(HyprGen.luaString(undefined), "");
});

test("luaUnescape is luaString's inverse, both ways", () => {
    const nasty = 'quote " back\\ newline\ntab\tend';
    assert.strictEqual(HyprGen.luaUnescape(HyprGen.luaString(nasty)), nasty);
    assert.strictEqual(HyprGen.luaUnescape('a\\"b'), 'a"b');
});

// ---------------------------------------------------------------- scanning

test("a plain bind scans to chord, expression and options", () => {
    const r = HyprGen.scanLua('hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("banditshell launcher toggle"), { description = "Launcher" })');
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].chord, "SUPER + SPACE");
    assert.strictEqual(r.binds[0].expr, 'hl.dsp.exec_cmd("banditshell launcher toggle")');
    assert.strictEqual(r.binds[0].description, "Launcher");
    assert.strictEqual(r.binds[0].dynamic, false);
    assert.strictEqual(r.binds[0].startLine, 1);
    assert.strictEqual(r.binds[0].endLine, 1);
});

test("a bind wrapped across lines scans as one bind", () => {
    const r = HyprGen.scanLua('hl.bind("SUPER + D",\n  hl.dsp.exec_cmd("banditshell exec"),\n  { description = "deep" })');
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].startLine, 1);
    assert.strictEqual(r.binds[0].endLine, 3);
    assert.strictEqual(r.binds[0].description, "deep");
});

test("a long-bracket command with parentheses inside does not end the string", () => {
    // The OCR bind, verbatim in shape: parens INSIDE the [[ ]] must not
    // close the call early.
    const r = HyprGen.scanLua('hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd([[grim -g "$(slurp)" | tesseract /tmp/x.png stdout]]))');
    assert.strictEqual(r.binds.length, 1);
    assert.ok(r.binds[0].expr.includes("tesseract"), "the body was cut at the first paren");
    assert.strictEqual(r.binds[0].endLine, 1);
});

test("comments are skipped and never read as binds", () => {
    const r = HyprGen.scanLua([
        "-- hl.bind(\"SUPER + Q\", nothing) is a comment",
        "hl.bind(\"SUPER + A\", hl.dsp.exec_cmd(\"banditshell exec\"))"
    ].join("\n"));
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].chord, "SUPER + A");
});

test("escapes inside strings: a backslash-quote does not close it", () => {
    const r = HyprGen.scanLua('hl.bind("SUPER + Q", hl.dsp.exec_cmd("say \\"hi\\" now"))');
    assert.strictEqual(r.binds.length, 1);
    assert.ok(r.binds[0].expr.includes('say \\"hi\\" now'), "the escaped quotes survived the scan");
});

test("binds born in loops and functions are dynamic; block depth survives the loop", () => {
    const r = HyprGen.scanLua([
        "for i = 1, 9 do",
        "    hl.bind(\"SUPER + \" .. i, hl.dsp.focus({ workspace = i }))",
        "end",
        "hl.bind(\"SUPER + N\", hl.dsp.exec_cmd(\"banditshell notifications toggle\"))",
        "hl.define_submap(\"voice\", function()",
        "    hl.bind(\"J\", hl.dsp.exec_cmd(\"voice lang ja\"))",
        "end)"
    ].join("\n"));
    assert.strictEqual(r.binds.length, 3);
    // Loop bind: computed chord, read-only.
    assert.strictEqual(r.binds[0].dynamic, true);
    // The bind AFTER the loop: writable again.
    assert.strictEqual(r.binds[1].dynamic, false);
    // A bind inside a submap function: read-only, forever.
    assert.strictEqual(r.binds[2].dynamic, true);
});

test("requires are read, in order, and only at the top level", () => {
    const r = HyprGen.scanLua([
        "require(\"lua.env\")",
        "require(\"lua.look\")",
        "-- require(\"lua.ghost\")",
        "local x = function() require(\"lua.inside\") end",
        "require(\"lua.binds\")"
    ].join("\n"));
    assert.deepStrictEqual(r.requires, ["lua.env", "lua.look", "lua.binds"]);
});

test("other hl.* calls are counted, not parsed as binds", () => {
    const r = HyprGen.scanLua('hl.window_rule({ name = "x" })\nhl.bind("SUPER + A", hl.dsp.exec_cmd("x"))');
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.foreign.length, 1);
});

// ------------------------------------------------------- compose and splice

test("composeBind renders the same line the scanner reads back", () => {
    const line = HyprGen.composeBind("SUPER + X", 'hl.dsp.exec_cmd("banditshell exec")', {
        locked: true, repeating: false, description: 'the "whole" thing'
    });
    const r = HyprGen.scanLua(line);
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].chord, "SUPER + X");
    assert.strictEqual(r.binds[0].description, 'the "whole" thing');
    assert.strictEqual(r.binds[0].locked, true);
    assert.strictEqual(r.binds[0].repeating, false);
    assert.strictEqual(r.binds[0].dynamic, false);
});

test("composeBind without options takes the two-argument form", () => {
    const line = HyprGen.composeBind("SUPER + X", 'hl.dsp.exec_cmd("x")', {});
    assert.strictEqual(line, 'hl.bind("SUPER + X", hl.dsp.exec_cmd("x"))');
    // And an incomplete one renders as nothing, not as broken Lua.
    assert.strictEqual(HyprGen.composeBind("", "x", {}), null);
    assert.strictEqual(HyprGen.composeBind("SUPER + X", "", {}), null);
});

test("a splice replaces exactly its lines and nothing else", () => {
    const file = [
        "-- top comment",
        'hl.bind("SUPER + A", hl.dsp.exec_cmd("old"))',
        "-- a comment that must survive",
        'hl.bind("SUPER + B", hl.dsp.exec_cmd("keep"))'
    ].join("\n");

    const next = HyprGen.spliceLines(file, 2, 2, ['hl.bind("SUPER + A2", hl.dsp.exec_cmd("new"))']);
    const lines = next.split("\n");
    assert.strictEqual(lines.length, 4);
    assert.strictEqual(lines[0], "-- top comment");
    assert.strictEqual(lines[1], 'hl.bind("SUPER + A2", hl.dsp.exec_cmd("new"))');
    assert.strictEqual(lines[2], "-- a comment that must survive");
    assert.strictEqual(lines[3], 'hl.bind("SUPER + B", hl.dsp.exec_cmd("keep"))');
});

test("a multi-line bind is spliced by range, so its comment above survives", () => {
    const file = [
        "-- the ocr bind",
        'hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd(',
        "    [[long thing]]))",
        'hl.bind("SUPER + U", hl.dsp.exec_cmd("after"))'
    ].join("\n");

    const next = HyprGen.spliceLines(file, 2, 3, ['hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("replaced"))']);
    const lines = next.split("\n");
    assert.strictEqual(lines.length, 3);
    assert.strictEqual(lines[0], "-- the ocr bind");
    assert.strictEqual(lines[2], 'hl.bind("SUPER + U", hl.dsp.exec_cmd("after"))');
});

test("spliceLines refuses ranges outside the file", () => {
    assert.strictEqual(HyprGen.spliceLines("one\ntwo", 0, 1, ["x"]), null);
    assert.strictEqual(HyprGen.spliceLines("one\ntwo", 1, 3, ["x"]), null);
    assert.strictEqual(HyprGen.spliceLines("one\ntwo", 2, 1, ["x"]), null);
});

test("an edit round-trips: scan, edit, splice, rescan", () => {
    const file = [
        "-- Clipboard",
        'hl.bind("SUPER + V", hl.dsp.exec_cmd("banditshell clipboard toggle"), { description = "Clipboard history" })',
        'hl.bind("CTRL + ALT + V", hl.dsp.exec_cmd("type-clipboard"))'
    ].join("\n");

    const first = HyprGen.scanLua(file);
    const bind = first.binds[0];
    const edited = HyprGen.spliceLines(file, bind.startLine, bind.endLine, [
        HyprGen.composeBind("SUPER + B", bind.expr, { locked: false, repeating: false, description: "Clipboard" })
    ]);

    const second = HyprGen.scanLua(edited);
    assert.strictEqual(second.binds.length, 2);
    assert.strictEqual(second.binds[0].chord, "SUPER + B");
    assert.strictEqual(second.binds[0].description, "Clipboard");
    // The neighbour never moved.
    assert.strictEqual(second.binds[1].chord, "CTRL + ALT + V");
    assert.strictEqual(second.binds[1].description, "");
});
