const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/hyprland-lua.js"), "utf8");
const HyprlandLua = new Function(src
    + "\nreturn { parseChord, luaString, luaUnescape, scanLua, composeBind, composeEntry, parseBandSpec, spliceLines, appendSplice, configFromCommandLine, confSources };")();

test("chords parse into modifiers and a key", () => {
    assert.deepStrictEqual(HyprlandLua.parseChord("SUPER + SHIFT + Slash"), {
        mods: ["SUPER", "SHIFT"], key: "Slash", mask: 65
    });
    assert.deepStrictEqual(HyprlandLua.parseChord("XF86Calculator"), {
        mods: [], key: "XF86Calculator", mask: 0
    });
    assert.deepStrictEqual(HyprlandLua.parseChord("SUPER + grave"), {
        mods: ["SUPER"], key: "grave", mask: 64
    });

    assert.strictEqual(HyprlandLua.parseChord("SUPER + SUPER + A").mask, 64);

    assert.strictEqual(HyprlandLua.parseChord("").key, "");
});

test("lua strings escape everything that could end the string", () => {
    assert.strictEqual(HyprlandLua.luaString('say "hi"'), 'say \\"hi\\"');
    assert.strictEqual(HyprlandLua.luaString("back\\slash"), "back\\\\slash");
    assert.strictEqual(HyprlandLua.luaString("one\ntwo"), "one\\ntwo");
    assert.strictEqual(HyprlandLua.luaString(undefined), "");
});

test("luaUnescape is luaString's inverse, both ways", () => {
    const nasty = 'quote " back\\ newline\ntab\tend';
    assert.strictEqual(HyprlandLua.luaUnescape(HyprlandLua.luaString(nasty)), nasty);
    assert.strictEqual(HyprlandLua.luaUnescape('a\\"b'), 'a"b');
});

test("a plain bind scans to chord, expression and options", () => {
    const r = HyprlandLua.scanLua('hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("banditshell launcher toggle"), { description = "Launcher" })');
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].chord, "SUPER + SPACE");
    assert.strictEqual(r.binds[0].expr, 'hl.dsp.exec_cmd("banditshell launcher toggle")');
    assert.strictEqual(r.binds[0].description, "Launcher");
    assert.strictEqual(r.binds[0].dynamic, false);
    assert.strictEqual(r.binds[0].startLine, 1);
    assert.strictEqual(r.binds[0].endLine, 1);
});

test("a bind wrapped across lines scans as one bind", () => {
    const r = HyprlandLua.scanLua('hl.bind("SUPER + D",\n  hl.dsp.exec_cmd("banditshell exec"),\n  { description = "deep" })');
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].startLine, 1);
    assert.strictEqual(r.binds[0].endLine, 3);
    assert.strictEqual(r.binds[0].description, "deep");
});

test("a long-bracket command with parentheses inside does not end the string", () => {

    const r = HyprlandLua.scanLua('hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd([[grim -g "$(slurp)" | tesseract /tmp/x.png stdout]]))');
    assert.strictEqual(r.binds.length, 1);
    assert.ok(r.binds[0].expr.includes("tesseract"), "the body was cut at the first paren");
    assert.strictEqual(r.binds[0].endLine, 1);
});

test("comments are skipped and never read as binds", () => {
    const r = HyprlandLua.scanLua([
        "-- hl.bind(\"SUPER + Q\", nothing) is a comment",
        "hl.bind(\"SUPER + A\", hl.dsp.exec_cmd(\"banditshell exec\"))"
    ].join("\n"));
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].chord, "SUPER + A");
});

test("escapes inside strings: a backslash-quote does not close it", () => {
    const r = HyprlandLua.scanLua('hl.bind("SUPER + Q", hl.dsp.exec_cmd("say \\"hi\\" now"))');
    assert.strictEqual(r.binds.length, 1);
    assert.ok(r.binds[0].expr.includes('say \\"hi\\" now'), "the escaped quotes survived the scan");
});

test("binds born in loops and functions are dynamic; block depth survives the loop", () => {
    const r = HyprlandLua.scanLua([
        "for i = 1, 9 do",
        "    hl.bind(\"SUPER + \" .. i, hl.dsp.focus({ workspace = i }))",
        "end",
        "hl.bind(\"SUPER + N\", hl.dsp.exec_cmd(\"banditshell notifications toggle\"))",
        "hl.define_submap(\"voice\", function()",
        "    hl.bind(\"J\", hl.dsp.exec_cmd(\"voice lang ja\"))",
        "end)",
        "hl.bind(\"SUPER + W\", hl.dsp.exec_cmd(\"banditshell wallpaper toggle\"))"
    ].join("\n"));
    assert.strictEqual(r.binds.length, 4);

    assert.strictEqual(r.binds[0].dynamic, true);

    assert.strictEqual(r.binds[1].dynamic, false);

    assert.strictEqual(r.binds[2].dynamic, true);

    assert.strictEqual(r.binds[1].submap, "");
    assert.strictEqual(r.binds[2].submap, "voice");
    assert.strictEqual(r.binds[3].submap, "");
});

test("a submap without a name contributes no submap", () => {
    const r = HyprlandLua.scanLua([
        "hl.define_submap(function()",
        "    hl.bind(\"J\", hl.dsp.exec_cmd(\"x\"))",
        "end)"
    ].join("\n"));
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].submap, "");
});

test("a chord built with .. is woven: the source stays the chord, the second argument the expression", () => {
    const r = HyprlandLua.scanLua('hl.bind("SUPER + " .. key, hl.dsp.exec_cmd("banditshell output toggle"))');
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].chordLiteral, false);
    assert.strictEqual(r.binds[0].chord, '"SUPER + " .. key');
    assert.strictEqual(r.binds[0].expr, 'hl.dsp.exec_cmd("banditshell output toggle")');
    assert.strictEqual(r.binds[0].dynamic, true);
    assert.deepStrictEqual(r.binds[0].chords, []);
});

test("a literal chord is its own and only chord", () => {
    const r = HyprlandLua.scanLua('hl.bind("SUPER + W", hl.dsp.exec_cmd("x"))');
    assert.deepStrictEqual(r.binds[0].chords, ["SUPER + W"]);
});

test("loop keys reach only the binds that use the loop variable", () => {
    const r = HyprlandLua.scanLua([
        "for _, key in ipairs({ \"KP_0\", \"KP_Insert\" }) do",
        "    hl.bind(\"SUPER + \" .. key, hl.dsp.exec_cmd(\"banditshell output toggle\"))",
        "    hl.bind(\"SUPER + \" .. other, hl.dsp.exec_cmd(\"y\"))",
        "    hl.bind(\"SUPER + W\", hl.dsp.exec_cmd(\"x\"))",
        "end",
        "hl.bind(\"SUPER + \" .. key, hl.dsp.exec_cmd(\"z\"))"
    ].join("\n"));
    assert.deepStrictEqual(r.binds[0].chords, ["SUPER + KP_0", "SUPER + KP_Insert"]);
    assert.deepStrictEqual(r.binds[1].chords, []);
    assert.deepStrictEqual(r.binds[2].chords, ["SUPER + W"]);
    assert.deepStrictEqual(r.binds[3].chords, [], "the loop's scope ended at its end");
});

test("numeric loops carry no literal keys", () => {
    const r = HyprlandLua.scanLua("for i = 1, 10 do\n    hl.bind(\"SUPER + \" .. i, x)\nend");
    assert.deepStrictEqual(r.binds[0].chords, []);
});

test("nested key tables flatten through the field or slot the bind reads", () => {
    const r = HyprlandLua.scanLua([
        "local directions = {",
        "    { key = \"LEFT\", msg = \"l\" },",
        "    { key = \"RIGHT\", msg = \"r\" },",
        "}",
        "local pairs_of = { { \"SUPER + F\", hl.dsp.layout(\"fit active\") }, { \"SUPER + SHIFT + F\", x } }",
        "for _, d in ipairs(directions) do",
        "    hl.bind(\"SUPER + \" .. d.key, hl.dsp.layout(\"focus \" .. d.msg))",
        "end",
        "for _, b in ipairs(pairs_of) do",
        "    hl.bind(b[1], b[2])",
        "end",
        "for _, g in ipairs({ { \"A\", \"B\" }, { \"C\" } }) do",
        "    hl.bind(\"ALT + \" .. g[1], y)",
        "    hl.bind(\"ALT + \" .. g, y)",
        "end"
    ].join("\n"));
    assert.deepStrictEqual(r.binds[0].chords, ["SUPER + LEFT", "SUPER + RIGHT"]);
    assert.deepStrictEqual(r.binds[1].chords, ["SUPER + F", "SUPER + SHIFT + F"]);
    assert.deepStrictEqual(r.binds[2].chords, ["ALT + A", "ALT + C"]);
    assert.deepStrictEqual(r.binds[3].chords, [], "a table is not a key name");
});

test("nested loops expand over every loop the chord names", () => {
    const r = HyprlandLua.scanLua([
        "for _, m in ipairs({ \"SUPER\", \"ALT\" }) do",
        "    for _, k in ipairs({ \"1\", \"2\" }) do",
        "        hl.bind(m .. \" + \" .. k, y)",
        "    end",
        "end"
    ].join("\n"));
    assert.deepStrictEqual(r.binds[0].chords, ["SUPER + 1", "SUPER + 2", "ALT + 1", "ALT + 2"]);
});

test("a chord glued from top-level strings resolves through the aliases", () => {
    const r = HyprlandLua.scanLua([
        "local tablet_switch = \"Lid Switch\"",
        "hl.bind(\"switch:on:\" .. tablet_switch, hl.dsp.exec_cmd(\"x\"), { locked = true })",
        "hl.bind(\"SUPER + \" .. tostring(i % 10), y)"
    ].join("\n"));
    assert.strictEqual(r.binds[0].chordLiteral, false);
    assert.deepStrictEqual(r.binds[0].chords, ["switch:on:Lid Switch"]);
    assert.strictEqual(r.binds[0].locked, true);
    assert.deepStrictEqual(r.binds[1].chords, []);
});

test("elseif closes the branch before it: depth and scopes do not leak", () => {
    const r = HyprlandLua.scanLua([
        "if a then",
        "    x()",
        "elseif b then",
        "    y()",
        "else",
        "    z()",
        "end",
        "hl.bind(\"SUPER + A\", hl.dsp.exec_cmd(\"a\"))",
        "hl.define_submap(\"voice\", function()",
        "    if a then",
        "        hl.bind(\"J\", hl.dsp.exec_cmd(\"j\"))",
        "    elseif b then",
        "        hl.bind(\"K\", hl.dsp.exec_cmd(\"k\"))",
        "    end",
        "end)",
        "hl.bind(\"SUPER + B\", hl.dsp.exec_cmd(\"b\"))"
    ].join("\n"));
    assert.strictEqual(r.binds[0].dynamic, false, "the elseif left the top level one block deep");
    assert.strictEqual(r.binds[1].submap, "voice");
    assert.strictEqual(r.binds[2].submap, "voice");
    assert.strictEqual(r.binds[3].submap, "");
    assert.strictEqual(r.binds[3].dynamic, false);
});

test("define_submap opens a scope only around an inline function", () => {
    const r = HyprlandLua.scanLua([
        "hl.define_submap(\"resize\")",
        "hl.bind(\"SUPER + A\", hl.dsp.exec_cmd(\"a\"))",
        "for i = 1, 2 do x() end",
        "hl.define_submap(\"move\", \"reset\", function()",
        "    hl.bind(\"H\", hl.dsp.exec_cmd(\"h\"))",
        "end)",
        "hl.define_submap(\"named\", build_it)",
        "hl.bind(\"SUPER + B\", hl.dsp.exec_cmd(\"b\"))"
    ].join("\n"));
    assert.strictEqual(r.binds[0].submap, "");
    assert.strictEqual(r.binds[1].submap, "move");
    assert.strictEqual(r.binds[2].submap, "");
});

test("modifier aliases count as modifiers", () => {
    assert.deepStrictEqual(HyprlandLua.parseChord("SUPER + SHIFT + CONTROL + RIGHT"), {
        mods: ["SUPER", "SHIFT", "CTRL"], key: "RIGHT", mask: 69
    });
    assert.strictEqual(HyprlandLua.parseChord("WIN + A").mask, 64);
});

test("options the editor cannot write keep the bind out of its hands", () => {
    const r = HyprlandLua.scanLua([
        "hl.bind(\"SUPER + A\", hl.dsp.exec_cmd(\"a\"), { release = true })",
        "hl.bind(\"SUPER + B\", hl.dsp.exec_cmd(\"b\"), { description = \"Both, of them\", repeating = true })"
    ].join("\n"));
    assert.strictEqual(r.binds[0].dynamic, true);
    assert.strictEqual(r.binds[1].dynamic, false);
    assert.strictEqual(r.binds[1].description, "Both, of them");
    assert.strictEqual(r.binds[1].repeating, true);
});

test("hyprland-lua.js uses nothing Quickshell's engine lacks", () => {
    for (const api of ["matchAll", "replaceAll", "flatMap", ".flat(", "trimEnd", "trimStart", "fromEntries", "findLast", ".at(", "(?<"])
        assert.ok(!src.includes(api), `hyprland-lua.js uses ${api}, which Quickshell's JavaScript engine does not have`);
});

test("define_submap is a known call, not a foreign one", () => {
    const r = HyprlandLua.scanLua('hl.define_submap("voice", function() end)');
    assert.strictEqual(r.binds.length, 0);
    assert.strictEqual(r.foreign.length, 0);
});

test("requires are read, in order, and only at the top level", () => {
    const r = HyprlandLua.scanLua([
        "require(\"lua.env\")",
        "require(\"lua.look\")",
        "-- require(\"lua.ghost\")",
        "local x = function() require(\"lua.inside\") end",
        "require(\"lua.binds\")"
    ].join("\n"));
    assert.deepStrictEqual(r.requires, ["lua.env", "lua.look", "lua.binds"]);
});

test("other hl.* calls are counted, not parsed as binds", () => {
    const r = HyprlandLua.scanLua('hl.window_rule({ name = "x" })\nhl.bind("SUPER + A", hl.dsp.exec_cmd("x"))');
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.foreign.length, 1);
});

test("composeBind renders the same line the scanner reads back", () => {
    const line = HyprlandLua.composeBind("SUPER + X", 'hl.dsp.exec_cmd("banditshell exec")', {
        locked: true, repeating: false, description: 'the "whole" thing'
    });
    const r = HyprlandLua.scanLua(line);
    assert.strictEqual(r.binds.length, 1);
    assert.strictEqual(r.binds[0].chord, "SUPER + X");
    assert.strictEqual(r.binds[0].description, 'the "whole" thing');
    assert.strictEqual(r.binds[0].locked, true);
    assert.strictEqual(r.binds[0].repeating, false);
    assert.strictEqual(r.binds[0].dynamic, false);
});

test("composeBind without options takes the two-argument form", () => {
    const line = HyprlandLua.composeBind("SUPER + X", 'hl.dsp.exec_cmd("x")', {});
    assert.strictEqual(line, 'hl.bind("SUPER + X", hl.dsp.exec_cmd("x"))');

    assert.strictEqual(HyprlandLua.composeBind("", "x", {}), null);
    assert.strictEqual(HyprlandLua.composeBind("SUPER + X", "", {}), null);
});

test("a splice replaces exactly its lines and nothing else", () => {
    const file = [
        "-- top comment",
        'hl.bind("SUPER + A", hl.dsp.exec_cmd("old"))',
        "-- a comment that must survive",
        'hl.bind("SUPER + B", hl.dsp.exec_cmd("keep"))'
    ].join("\n");

    const next = HyprlandLua.spliceLines(file, 2, 2, ['hl.bind("SUPER + A2", hl.dsp.exec_cmd("new"))']);
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

    const next = HyprlandLua.spliceLines(file, 2, 3, ['hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("replaced"))']);
    const lines = next.split("\n");
    assert.strictEqual(lines.length, 3);
    assert.strictEqual(lines[0], "-- the ocr bind");
    assert.strictEqual(lines[2], 'hl.bind("SUPER + U", hl.dsp.exec_cmd("after"))');
});

test("spliceLines refuses ranges outside the file", () => {
    assert.strictEqual(HyprlandLua.spliceLines("one\ntwo", 0, 1, ["x"]), null);
    assert.strictEqual(HyprlandLua.spliceLines("one\ntwo", 1, 3, ["x"]), null);
    assert.strictEqual(HyprlandLua.spliceLines("one\ntwo", 2, 1, ["x"]), null);
});

test("an edit round-trips: scan, edit, splice, rescan", () => {
    const file = [
        "-- Clipboard",
        'hl.bind("SUPER + V", hl.dsp.exec_cmd("banditshell clipboard toggle"), { description = "Clipboard history" })',
        'hl.bind("CTRL + ALT + V", hl.dsp.exec_cmd("type-clipboard"))'
    ].join("\n");

    const first = HyprlandLua.scanLua(file);
    const bind = first.binds[0];
    const edited = HyprlandLua.spliceLines(file, bind.startLine, bind.endLine, [
        HyprlandLua.composeBind("SUPER + B", bind.expr, { locked: false, repeating: false, description: "Clipboard" })
    ]);

    const second = HyprlandLua.scanLua(edited);
    assert.strictEqual(second.binds.length, 2);
    assert.strictEqual(second.binds[0].chord, "SUPER + B");
    assert.strictEqual(second.binds[0].description, "Clipboard");

    assert.strictEqual(second.binds[1].chord, "CTRL + ALT + V");
    assert.strictEqual(second.binds[1].description, "");
});

const MONITORS_LUA = [
    "-- MONITORS AND WORKSPACE ASSIGNMENT",
    "local host = require(\"lua.host\")",
    "",
    "local ultrawide     = \"HDMI-A-1\"",
    "local vertical_side = \"DP-1\"",
    "",
    "local ultrawide_scale = 1",
    "",
    "local hosts = {",
    "    banditbox = {",
    "        outputs = {",
    "            { output = vertical_side, mode = \"1920x1200@60\", position = \"0x0\",",
    "              scale = 1, transform = 1 },",
    "",
    "            -- The ultrawide, default (SDR) mode.",
    "            { output = ultrawide, mode = \"5120x1440@144\", position = \"1200x240\",",
    "              scale = ultrawide_scale, transform = 0, bitdepth = 8, vrr = 1 },",
    "",
    "            -- HDR mode for that same panel. SWAP it for the line above.",
    "            -- { output = ultrawide, mode = \"5120x1440@144\", position = \"1200x240\",",
    "            --   scale = 1, transform = 0, bitdepth = 10, vrr = 1,",
    "            --   cm = \"hdr\", sdrbrightness = 1.2, sdrsaturation = 0.98 },",
    "        },",
    "        bands = {",
    "            { monitor = ultrawide,     first = 1, last = 5 },",
    "            { monitor = vertical_side, first = 6, last = 10 },",
    "        },",
    "    },",
    "}",
    "",
    "local layout = hosts[host.name] or {}",
    "",
    "hl.monitor({ output = \"\", mode = \"preferred\", position = \"auto\", scale = 1 })",
    "",
    "for _, monitor in ipairs(layout.outputs or {}) do",
    "    hl.monitor(monitor)",
    "end"
].join("\n");

test("host-table entries are monitor entries, resolved through the file's own locals", () => {
    const r = HyprlandLua.scanLua(MONITORS_LUA);

    const side = r.monitors.find(m => m.output === "DP-1");
    assert.ok(side, "vertical_side resolved to DP-1");
    assert.strictEqual(side.mode, "1920x1200@60");
    assert.strictEqual(side.scale, 1);
    assert.strictEqual(side.transform, 1);
    assert.strictEqual(side.dynamic, false);
    assert.ok(!side.raws.some(f => f.key === "vrr"), "absent vrr stays absent");

    const wide = r.monitors.find(m => m.output === "HDMI-A-1");
    assert.ok(wide, "ultrawide resolved to HDMI-A-1");
    assert.strictEqual(wide.scale, 1, "ultrawide_scale resolved through its local");
    assert.strictEqual(wide.vrr, 1);
    assert.strictEqual(wide.dynamic, false);
});

test("the commented-out HDR entry stays a comment, and the loop's call stays foreign", () => {
    const r = HyprlandLua.scanLua(MONITORS_LUA);

    assert.strictEqual(r.monitors.filter(m => m.output === "HDMI-A-1").length, 1);

    assert.ok(r.monitors.some(m => m.output === ""), "catch-all collected");

    assert.ok(r.foreign.some(f => f.text === "hl.monitor(...)"));
    assert.strictEqual(r.monitors.length, 3);
});

test("the outputs table is reported for appends, with its host path", () => {
    const r = HyprlandLua.scanLua(MONITORS_LUA);

    assert.strictEqual(r.outputTables.length, 1);
    assert.deepStrictEqual(r.outputTables[0].path, ["hosts", "banditbox", "outputs"]);
});

test("an entry is never collected from inside a function", () => {
    const file = [
        "local function setup()",
        "    local mons = { { output = \"DP-1\", mode = \"preferred\", position = \"auto\", scale = 1 } }",
        "    for _, m in ipairs(mons) do",
        "        hl.monitor(m)",
        "    end",
        "end"
    ].join("\n");

    const r = HyprlandLua.scanLua(file);

    assert.strictEqual(r.monitors.length, 1);
    assert.strictEqual(r.monitors[0].dynamic, true);
});

test("composing an edit rewrites the changed field and preserves the rest verbatim", () => {
    const r = HyprlandLua.scanLua(MONITORS_LUA);
    const wide = r.monitors.find(m => m.output === "HDMI-A-1");

    const line = HyprlandLua.composeEntry(wide, { position: "1200x172" });
    assert.ok(line.includes("output = ultrawide"), "the file's own alias survives");
    assert.ok(line.includes("scale = ultrawide_scale"), "the named constant survives");
    assert.ok(line.includes("bitdepth = 8"), "an unmanaged field survives");
    assert.ok(line.includes("position = \"1200x172\""), "the changed field is written");
    assert.ok(line.includes("mode = \"5120x1440@144\""), "an unchanged managed field is written as it was read");
    assert.ok(line.includes("vrr = 1"));
});

test("a full-spec apply that changes nothing rewrites nothing to a literal", () => {
    const r = HyprlandLua.scanLua(MONITORS_LUA);
    const side = r.monitors.find(m => m.output === "DP-1");

    const line = HyprlandLua.composeEntry(side, {
        mode: "1920x1200@60",
        position: "0x0",
        scale: 1,
        transform: 1,
        vrr: 0
    });
    assert.ok(line.includes("output = vertical_side"));
    assert.ok(line.includes("vrr = 0"), "a field the entry lacked is appended");
});

test("an appended entry is one literal line a rescan can read back", () => {
    const r = HyprlandLua.scanLua(MONITORS_LUA);
    const table = r.outputTables[0];

    const line = HyprlandLua.composeEntry(null, {
        output: "DP-2",
        mode: "2560x1440@60",
        position: "3840x0",
        scale: 1,
        transform: 0,
        vrr: 0
    });
    const edited = HyprlandLua.spliceLines(MONITORS_LUA, table.endLine, table.endLine, [
        "            " + line + ",",
        ...MONITORS_LUA.split("\n").slice(table.endLine - 1, table.endLine)
    ]);

    const second = HyprlandLua.scanLua(edited);
    const added = second.monitors.find(m => m.output === "DP-2");
    assert.ok(added, "the appended entry is a monitor entry");
    assert.strictEqual(added.mode, "2560x1440@60");
    assert.strictEqual(second.outputTables.length, 1, "still one outputs table");
});

test("an entry carries the indent it was written under, and an edit keeps it", () => {
    const r = HyprlandLua.scanLua(MONITORS_LUA);
    const side = r.monitors.find(m => m.output === "DP-1");

    assert.strictEqual(side.indent, "            ");

    assert.strictEqual(side.trailing, ",");
    const line = HyprlandLua.composeEntry(side, { position: "480x0" });
    assert.ok(line.includes("output = vertical_side"));
    const edited = HyprlandLua.spliceLines(MONITORS_LUA, side.startLine, side.endLine, [side.indent + line + side.trailing]);
    const second = HyprlandLua.scanLua(edited);
    assert.strictEqual(second.monitors.find(m => m.output === "DP-1").startLine, side.startLine, "the entry is one line now, at the indent it wore");

    assert.ok(/transform = 1 \},/.test(edited), "the separator survived the splice");
});

test("an edit round-trips: scan, edit, splice, rescan", () => {
    const first = HyprlandLua.scanLua(MONITORS_LUA);
    const wide = first.monitors.find(m => m.output === "HDMI-A-1");

    const edited = HyprlandLua.spliceLines(MONITORS_LUA, wide.startLine, wide.endLine, [
        "            " + HyprlandLua.composeEntry(wide, { position: "1200x172" }) + wide.trailing
    ]);

    const second = HyprlandLua.scanLua(edited);
    assert.strictEqual(second.monitors.length, first.monitors.length, "no entry gained or lost");
    const wide2 = second.monitors.find(m => m.output === "HDMI-A-1");
    assert.strictEqual(wide2.position, "1200x172");
    assert.strictEqual(wide2.scale, 1);
    assert.strictEqual(second.monitors.find(m => m.output === "DP-1").position, "0x0", "the neighbour never moved");

    assert.ok(edited.includes("-- The ultrawide, default (SDR) mode."));
});

const BANDS_LUA = [
    "local host = require(\"lua.host\")",
    "",
    "local ultrawide     = \"HDMI-A-1\"",
    "local vertical_side = \"DP-1\"",
    "",
    "-- >>> MANAGED BY BANDITSHELL >>>",
    "-- The workspace bands, one list per host. The shell's to write.",
    "local bs_bands = {",
    "    banditbox = {",
    "        { monitor = ultrawide,     workspaces = \"1-5\" },",
    "        { monitor = vertical_side, workspaces = \"6-10\" },",
    "    },",
    "",
    "    kangaeru = {",
    "        { monitor = \"eDP-1\", workspaces = \"1-5\" },",
    "    },",
    "}",
    "-- <<< MANAGED BY BANDITSHELL <<<",
    "",
    "-- The user's own emission, consuming the managed data.",
    "for _, band in ipairs(bs_bands[host.name] or {}) do",
    "    for _, ws in ipairs(bs_expand(band.workspaces)) do",
    "        hl.workspace_rule({ workspace = tostring(ws), monitor = band.monitor })",
    "    end",
    "end"
].join("\n");

test("band entries are read out of the managed section, hosts apart", () => {
    const r = HyprlandLua.scanLua(BANDS_LUA);

    assert.strictEqual(r.bands.length, 3);
    const wide = r.bands.find(b => b.monitor === "HDMI-A-1");
    assert.ok(wide, "the alias resolved");
    assert.strictEqual(wide.first, 1, "first is derived from the spec text");
    assert.strictEqual(wide.last, 5);
    assert.strictEqual(wide.workspaces, "1-5", "the spec is kept verbatim");
    assert.deepStrictEqual(wide.path, ["bs_bands", "banditbox"]);
    assert.strictEqual(r.bands.find(b => b.monitor === "eDP-1").path[1], "kangaeru", "the other host's bands are its own");
    assert.ok(r.bands.every(b => !b.dynamic));
});

test("the host's band table is reported for appends", () => {
    const r = HyprlandLua.scanLua(BANDS_LUA);

    assert.strictEqual(r.bandTables.length, 2);
    const mine = r.bandTables.find(t => t.path[1] === "banditbox");
    assert.deepStrictEqual(mine.path, ["bs_bands", "banditbox"]);
});

test("the emission loop's hl.workspace_rule stays foreign, and the loop's tables are not bands", () => {
    const r = HyprlandLua.scanLua(BANDS_LUA);

    assert.ok(r.foreign.some(f => f.text === "hl.workspace_rule(...)"));
    assert.strictEqual(r.bands.length, 3, "the rule table inside the loop is not a band: no monitor/first/last of its own");
});

test("a band edit rewrites the spec and keeps the file's own name for the monitor", () => {
    const r = HyprlandLua.scanLua(BANDS_LUA);
    const side = r.bands.find(b => b.monitor === "DP-1");

    const line = HyprlandLua.composeEntry(side, { workspaces: "6-15" });
    assert.ok(line.includes("monitor = vertical_side"), "the alias survives");
    assert.ok(line.includes(`workspaces = "6-15"`), "the spec is written");
    assert.ok(!line.includes("first") && !line.includes("last"), "the old shape is gone, not half-carried");
});

test("a band append lands inside its host's list and reads back", () => {
    const r = HyprlandLua.scanLua(BANDS_LUA);
    const mine = r.bandTables.find(t => t.path[1] === "banditbox");
    const lines = BANDS_LUA.split("\n");
    const closer = lines[mine.endLine - 1];
    const indent = "            ";

    const entry = HyprlandLua.composeEntry(null, { monitor: "DP-3", workspaces: "11-15" });
    const edited = HyprlandLua.spliceLines(BANDS_LUA, mine.endLine, mine.endLine, [indent + entry + ",", closer]);

    const second = HyprlandLua.scanLua(edited);
    const added = second.bands.find(b => b.monitor === "DP-3");
    assert.ok(added, "the appended band is a band entry");
    assert.deepStrictEqual(added.path, ["bs_bands", "banditbox"]);
    assert.strictEqual(second.bands.find(b => b.monitor === "HDMI-A-1").last, 5, "the neighbour never moved");
});

test("a band round-trip: scan, edit, splice, rescan", () => {
    const first = HyprlandLua.scanLua(BANDS_LUA);
    const side = first.bands.find(b => b.monitor === "DP-1");

    const edited = HyprlandLua.spliceLines(BANDS_LUA, side.startLine, side.endLine, [
        "        " + HyprlandLua.composeEntry(side, { workspaces: "6-15" }) + side.trailing
    ]);

    const second = HyprlandLua.scanLua(edited);
    assert.strictEqual(second.bands.length, first.bands.length);
    const side2 = second.bands.find(b => b.monitor === "DP-1");
    assert.strictEqual(side2.first, 6);
    assert.strictEqual(side2.last, 15);
    assert.strictEqual(second.bands.find(b => b.monitor === "HDMI-A-1").first, 1, "the neighbour never moved");
});

test("the workspaces grammar: lists, ranges, both, any order", () => {
    assert.deepStrictEqual(HyprlandLua.parseBandSpec("1,2,3,4,5,6,7").ids, [1, 2, 3, 4, 5, 6, 7]);
    assert.deepStrictEqual(HyprlandLua.parseBandSpec("1-10").ids, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    assert.deepStrictEqual(HyprlandLua.parseBandSpec("1-6, 8-10").ids, [1, 2, 3, 4, 5, 6, 8, 9, 10], "a gap is a real gap");
    assert.deepStrictEqual(HyprlandLua.parseBandSpec("3, 2, 1").ids, [1, 2, 3], "the order of the typing is not the order of the numbers");

    assert.deepStrictEqual(HyprlandLua.parseBandSpec("1-3, 3, 5").ids, [1, 2, 3, 5]);
    assert.deepStrictEqual(HyprlandLua.parseBandSpec("1,").ids, [1], "a trailing comma is a residue, not a refusal");
    assert.deepStrictEqual(HyprlandLua.parseBandSpec("1,,2").ids, [1, 2], "an empty part is skipped, matching bs_expand's gmatch");
    const run = HyprlandLua.parseBandSpec("6-10");
    assert.strictEqual(run.first, 6);
    assert.strictEqual(run.last, 10);
});

test("the workspaces grammar: what it refuses", () => {
    assert.strictEqual(HyprlandLua.parseBandSpec("monitors").ok, false, "text is not a workspace");
    assert.strictEqual(HyprlandLua.parseBandSpec("1- 10").ok, false, "a space inside a range is a typo, not airy typing");
    assert.strictEqual(HyprlandLua.parseBandSpec("1 -10").ok, false);
    assert.strictEqual(HyprlandLua.parseBandSpec("").ok, false);
    assert.strictEqual(HyprlandLua.parseBandSpec("10-8").ok, false, "a backwards range is a typo");
    assert.strictEqual(HyprlandLua.parseBandSpec("1-99999999").ok, false, "a range that cannot be a desktop");
});

test("an invalid band in the file is shown and editable, but feeds no model", () => {
    const file = [
        "local bs_bands = {",
        "    banditbox = {",
        "        { monitor = \"DP-1\", workspaces = \"1- 5\" },",
        "    },",
        "}"
    ].join("\n");
    const r = HyprlandLua.scanLua(file);

    assert.strictEqual(r.bands.length, 1);
    assert.strictEqual(r.bands[0].invalid, true);
    assert.strictEqual(r.bands[0].first, undefined);
    assert.strictEqual(r.bands[0].dynamic, false, "invalid is not dynamic: the field shows it so it can be fixed");
});

test("the compositor's -c resolves absolute, home and relative paths", () => {
    const home = "/home/u";
    assert.strictEqual(HyprlandLua.configFromCommandLine("cwd=/tmp\nHyprland\n--watchdog-fd\n4", home), "");
    assert.strictEqual(HyprlandLua.configFromCommandLine("cwd=/tmp\nHyprland\n-c\n/etc/hypr/h.lua", home), "/etc/hypr/h.lua");
    assert.strictEqual(HyprlandLua.configFromCommandLine("cwd=/tmp\nHyprland\n--config\n~/dots/h.lua", home), "/home/u/dots/h.lua");
    assert.strictEqual(HyprlandLua.configFromCommandLine("cwd=/srv/x\nHyprland\n--config=./conf/h.conf", home), "/srv/x/conf/h.conf");
    assert.strictEqual(HyprlandLua.configFromCommandLine("cwd=\nHyprland\n-c\nh.lua", home), "", "a relative path with no cwd is no answer");
});

test(".conf source lines are followed, globs and comments left alone", () => {
    const found = HyprlandLua.confSources([
        "source = ~/.config/hypr/binds.conf",
        "  source=extra.conf # trailing",
        "# source = commented.conf",
        "source = $HOME/x.conf",
        "source = ./parts/*.conf",
        "bind = SUPER, Q, exec, foot"
    ].join("\n"), "/home/u/.config/hypr", "/home/u");
    assert.deepStrictEqual(found, ["/home/u/.config/hypr/binds.conf", "/home/u/.config/hypr/extra.conf", "/home/u/x.conf"]);
});

test("appending lands after the last line, by line count, keeping the file's final newline", () => {
    const add = (src, line) => {
        const at = HyprlandLua.appendSplice(src, [line]);
        return HyprlandLua.spliceLines(src, at.startLine, at.endLine, at.replacement);
    };
    const src = "hl.bind(\"SUPER + A\", x)\nhl.bind(\"SUPER + B\", y)\n";
    assert.strictEqual(add(src, "NEW"), "hl.bind(\"SUPER + A\", x)\nhl.bind(\"SUPER + B\", y)\nNEW\n");
    assert.strictEqual(add("a\nb", "NEW"), "a\nb\nNEW");
    assert.strictEqual(add("", "NEW"), "NEW\n");
    assert.strictEqual(HyprlandLua.appendSplice(src, ["NEW"]).startLine, 3, "a line number, not a character count");
    assert.strictEqual(HyprlandLua.spliceLines(src, src.length + 1, src.length + 1, ["NEW"]), null, "the old character-count call never worked");
});

const Options = new Function(src
    + "\nreturn { optionSegments, luaOptionValue, scanOptions, planOption, optionBlocked, lineDiff, spliceLines };")();

const INPUT_LUA = [
    "hl.config({",
    "    input = {",
    "        kb_layout  = \"us,dk\",",
    "        kb_options = \"caps:backspace, grp:switch\",",
    "",
    "        follow_mouse = 1,",
    "        sensitivity  = 0,",
    "",
    "        touchpad = {",
    "            natural_scroll = true,",
    "        },",
    "    },",
    "})",
    "",
    "if host.is(\"banditbox\") then",
    "    hl.config({ cursor = { no_hardware_cursors = true } })",
    "end",
    ""
].join("\n");

function written(files, request) {
    const plan = Options.planOption(files, request);
    assert.ok(plan.ok, plan.reason);
    if (plan.unchanged)
        return null;
    const file = files.find(f => f.name === plan.file);
    return { name: plan.file, text: Options.spliceLines(file.text, plan.startLine, plan.endLine, plan.replacement) };
}

function change(text, request) {
    const out = written([{ name: "a.lua", text }], request);
    return out ? out.text : text;
}

test("option paths turn into the keys Lua spells", () => {
    assert.deepStrictEqual(Options.optionSegments("input:touchpad:tap-to-click"), ["input", "touchpad", "tap_to_click"]);
    assert.deepStrictEqual(Options.optionSegments("input.kb_layout"), ["input", "kb_layout"]);
    assert.deepStrictEqual(Options.optionSegments(""), []);
});

test("option values compose as Lua literals", () => {
    assert.strictEqual(Options.luaOptionValue(true), "true");
    assert.strictEqual(Options.luaOptionValue(false), "false");
    assert.strictEqual(Options.luaOptionValue(300), "300");
    assert.strictEqual(Options.luaOptionValue(0.1 + 0.2), "0.3");
    assert.strictEqual(Options.luaOptionValue(-0.25), "-0.25");
    assert.strictEqual(Options.luaOptionValue('dk,"us"'), '"dk,\\"us\\""');
    assert.strictEqual(Options.luaOptionValue(NaN), null);
    assert.strictEqual(Options.luaOptionValue(undefined), null);
    assert.strictEqual(Options.luaOptionValue({}), null);
});

test("an option already set is rewritten in place and nothing else moves", () => {
    const out = change(INPUT_LUA, { path: "input:kb_layout", value: "dk,us" });
    assert.strictEqual(out, INPUT_LUA.replace('kb_layout  = "us,dk"', 'kb_layout  = "dk,us"'));
    assert.strictEqual(change(INPUT_LUA, { path: "input:sensitivity", value: 0.35 }), INPUT_LUA.replace("sensitivity  = 0,", "sensitivity  = 0.35,"));
});

test("a nested option is found by its path", () => {
    const out = change(INPUT_LUA, { path: "input:touchpad:natural_scroll", value: false });
    assert.strictEqual(out, INPUT_LUA.replace("natural_scroll = true", "natural_scroll = false"));
});

test("writing the value that is already there asks for no write", () => {
    assert.deepStrictEqual(Options.planOption([{ name: "a.lua", text: INPUT_LUA }], { path: "input:follow_mouse", value: 1 }), { ok: true, unchanged: true });
});

test("a trailing comment and the value's own spacing survive a rewrite", () => {
    const text = "hl.config({ input = {\n    repeat_rate   =   25 , -- keys per second\n} })\n";
    assert.strictEqual(change(text, { path: "input:repeat_rate", value: 40 }), "hl.config({ input = {\n    repeat_rate   =   40 , -- keys per second\n} })\n");
});

test("an option missing from a table lands at the end of that table, in its style", () => {
    const out = change(INPUT_LUA, { path: "input:repeat_delay", value: 250 });
    assert.strictEqual(out, INPUT_LUA.replace("        },\n    },", "        },\n        repeat_delay = 250,\n    },"));
    const inner = change(INPUT_LUA, { path: "input:touchpad:tap-to-click", value: true });
    assert.strictEqual(inner, INPUT_LUA.replace("            natural_scroll = true,\n", "            natural_scroll = true,\n            tap_to_click = true,\n"));
});

test("a table whose last field has no trailing comma gets one, and the new field follows suit", () => {
    const text = "hl.config({\n    input = {\n        kb_layout = \"us\" -- lead\n    }\n})\n";
    assert.strictEqual(change(text, { path: "input:repeat_rate", value: 30 }), "hl.config({\n    input = {\n        kb_layout = \"us\", -- lead\n        repeat_rate = 30\n    }\n})\n");
});

test("a table on one line grows on that line", () => {
    assert.strictEqual(change('hl.config({ input = { kb_layout = "us" } })\n', { path: "input:repeat_rate", value: 30 }), 'hl.config({ input = { kb_layout = "us", repeat_rate = 30 } })\n');
    assert.strictEqual(change('hl.config({ input = { kb_layout = "us", } })\n', { path: "input:repeat_rate", value: 30 }), 'hl.config({ input = { kb_layout = "us", repeat_rate = 30, } })\n');
    assert.strictEqual(change("hl.config({ input = {} })\n", { path: "input:repeat_rate", value: 30 }), "hl.config({ input = { repeat_rate = 30 } })\n");
});

test("an empty table that spans lines gets its first field on a line of its own", () => {
    assert.strictEqual(change("hl.config({\n    input = {\n    },\n})\n", { path: "input:repeat_rate", value: 30 }), "hl.config({\n    input = {\n        repeat_rate = 30,\n    },\n})\n");
    assert.strictEqual(change("hl.config({\n\tinput = {\n\t},\n})\n", { path: "input:repeat_rate", value: 30 }), "hl.config({\n\tinput = {\n\t\trepeat_rate = 30,\n\t},\n})\n");
});

test("a missing sub-table is written inside the nearest table that exists", () => {
    const text = "hl.config({\n    input = {\n        kb_layout = \"us\",\n    },\n})\n";
    assert.strictEqual(change(text, { path: "input:touchpad:tap-to-click", value: true }), "hl.config({\n    input = {\n        kb_layout = \"us\",\n        touchpad = { tap_to_click = true },\n    },\n})\n");
});

test("an option with no table anywhere is a new hl.config call after a blank line", () => {
    const text = "hl.bind(\"SUPER + A\", x)\n";
    assert.strictEqual(change(text, { path: "general:layout", value: "dwindle" }), "hl.bind(\"SUPER + A\", x)\n\nhl.config({\n    general = {\n        layout = \"dwindle\",\n    },\n})\n");
    assert.strictEqual(change(text, { path: "input:touchpad:tap-to-click", value: false }), "hl.bind(\"SUPER + A\", x)\n\nhl.config({\n    input = {\n        touchpad = {\n            tap_to_click = false,\n        },\n    },\n})\n");
    assert.strictEqual(change("", { path: "general:layout", value: "master" }), "hl.config({\n    general = {\n        layout = \"master\",\n    },\n})\n");
    assert.strictEqual(change("hl.bind(\"SUPER + A\", x)", { path: "general:layout", value: "master" }), "hl.bind(\"SUPER + A\", x)\n\nhl.config({\n    general = {\n        layout = \"master\",\n    },\n})");
});

test("a new option goes to the file asked for, else the first", () => {
    const files = [{ name: "root.lua", text: "require(\"x\")\n" }, { name: "x.lua", text: "local a = 1\n" }];
    assert.strictEqual(Options.planOption(files, { path: "misc:vfr", value: true }).file, "root.lua");
    assert.strictEqual(Options.planOption(files, { path: "misc:vfr", value: true, appendTo: "x.lua" }).file, "x.lua");
    assert.strictEqual(Options.planOption([], { path: "misc:vfr", value: true }).ok, false);
});

test("an option is found in whichever file sets it", () => {
    const files = [{ name: "root.lua", text: "require(\"lua.input\")\n" }, { name: "lua/input.lua", text: INPUT_LUA }];
    const out = written(files, { path: "input:kb_layout", value: "de" });
    assert.strictEqual(out.name, "lua/input.lua");
    assert.ok(out.text.includes('kb_layout  = "de"'));
});

test("a value built by code is refused, and so is one set under a condition", () => {
    const dynamic = "local stage = require(\"lua.stage\")\nhl.config({ general = { layout = stage.name } })\n";
    const refused = Options.planOption([{ name: "look.lua", text: dynamic }], { path: "general:layout", value: "dwindle" });
    assert.strictEqual(refused.ok, false);
    assert.match(refused.reason, /general:layout is generated by code \(look\.lua, line 2\)/);

    const conditional = Options.planOption([{ name: "a.lua", text: INPUT_LUA }], { path: "cursor:no_hardware_cursors", value: false });
    assert.strictEqual(conditional.ok, false);
    assert.match(conditional.reason, /under a condition or inside a function \(a\.lua, line 16\)/);

    for (const wrapped of ["function f()", "for i = 1, 2 do", "while x do", "repeat"])
        assert.strictEqual(Options.optionBlocked([{ name: "a.lua", text: `${wrapped}\n hl.config({ input = { kb_layout = "us" } })\n${wrapped === "repeat" ? "until x" : "end"}\n` }], "input:kb_layout"), `input:kb_layout is set under a condition or inside a function (a.lua, line 2); edit the source.`, wrapped);
});

test("a category handed over as a variable might hold the option, so it is refused", () => {
    const text = "local settings = {}\nhl.config({ input = settings })\n";
    assert.match(Options.optionBlocked([{ name: "a.lua", text }], "input:kb_layout"), /may be generated by code \(a\.lua, line 2\)/);
    assert.strictEqual(Options.optionBlocked([{ name: "a.lua", text }], "general:layout"), "");
});

test("an option set in two places is refused rather than guessed at", () => {
    const files = [{ name: "a.lua", text: 'hl.config({ input = { kb_layout = "us" } })\n' }, { name: "b.lua", text: 'hl.config({ input = { kb_layout = "dk" } })\n' }];
    const reason = Options.optionBlocked(files, "input:kb_layout");
    assert.match(reason, /set in 2 places \(a\.lua, line 1; b\.lua, line 1\)/);
});

test("the flat dotted spelling of a key is the same option", () => {
    const text = 'hl.config({ ["input.kb_layout"] = "us", ["input:repeat_rate"] = 20 })\n';
    assert.strictEqual(change(text, { path: "input:kb_layout", value: "dk" }), 'hl.config({ ["input.kb_layout"] = "dk", ["input:repeat_rate"] = 20 })\n');
    assert.strictEqual(change(text, { path: "input:repeat_rate", value: 30 }), 'hl.config({ ["input.kb_layout"] = "us", ["input:repeat_rate"] = 30 })\n');
});

test("strings, comments and long brackets that look like calls are not options", () => {
    const text = [
        "-- hl.config({ input = { kb_layout = \"commented\" } })",
        "local note = \"hl.config({ input = { kb_layout = 'quoted' } })\"",
        "--[[ hl.config({ input = { kb_layout = \"block\" } }) ]]",
        "local long = [[ hl.config({ input = { kb_layout = 'long' } }) ]]",
        "hl.config({ input = { kb_layout = \"real\" } })",
        ""
    ].join("\n");
    assert.strictEqual(change(text, { path: "input:kb_layout", value: "dk" }), text.replace('"real"', '"dk"'));
});

test("a call that is not a table literal is left alone", () => {
    const text = "hl.config(build())\nhl.config({ input = { repeat_rate = 25 } })\n";
    assert.strictEqual(change(text, { path: "input:repeat_rate", value: 30 }), text.replace("25", "30"));
});

test("a device block is found by its name and edited", () => {
    const text = 'hl.device({ name = "pad", sensitivity = 0.1, natural_scroll = true })\nhl.device({ name = "other", sensitivity = 0.9 })\n';
    assert.strictEqual(change(text, { path: "input:sensitivity", device: "pad", value: 0.4 }), text.replace("sensitivity = 0.1", "sensitivity = 0.4"));
    assert.strictEqual(change(text, { path: "sensitivity", device: "other", value: -0.5 }), text.replace("sensitivity = 0.9", "sensitivity = -0.5"));
});

test("a device block without the key gets it, and an unknown device gets a block", () => {
    const text = 'hl.device({ name = "pad", natural_scroll = true })\n';
    assert.strictEqual(change(text, { path: "input:sensitivity", device: "pad", value: 0.4 }), 'hl.device({ name = "pad", natural_scroll = true, sensitivity = 0.4 })\n');
    assert.strictEqual(change(text, { path: "input:sensitivity", device: "mouse", value: 0.2 }), `${text}\nhl.device({ name = "mouse", sensitivity = 0.2 })\n`);
});

test("a device set under a condition is refused for a key it sets, and ignored for one it does not", () => {
    const text = 'if host.is("a") then\n    hl.device({ name = "pad", output = "DP-1" })\nend\n';
    assert.match(Options.optionBlocked([{ name: "a.lua", text }], "output", "pad"), /under a condition/);
    assert.strictEqual(Options.optionBlocked([{ name: "a.lua", text }], "sensitivity", "pad"), "");
    assert.strictEqual(change(text, { path: "sensitivity", device: "pad", value: 0.3 }), `${text}\nhl.device({ name = "pad", sensitivity = 0.3 })\n`);
});

test("a device whose name is built by code is never matched", () => {
    const text = 'hl.device({ name = prefix .. "pad", sensitivity = 0.1 })\n';
    assert.strictEqual(change(text, { path: "sensitivity", device: "pad", value: 0.3 }), `${text}\nhl.device({ name = "pad", sensitivity = 0.3 })\n`);
});

test("a value that cannot be written is refused", () => {
    assert.strictEqual(Options.planOption([{ name: "a.lua", text: INPUT_LUA }], { path: "input:kb_layout", value: NaN }).ok, false);
});

test("the line splice an option write hands back reproduces the whole edit", () => {
    const before = "a\nb\nc\n";
    for (const after of ["a\nb\nc\nd\n", "x\na\nb\nc\n", "a\nb\nB\nc\n", "a\nc\n", "a\nb\nc\n\n\n"]) {
        const d = Options.lineDiff(before, after);
        assert.strictEqual(Options.spliceLines(before, d.startLine, d.endLine, d.replacement), after, JSON.stringify(after));
    }
    assert.strictEqual(Options.lineDiff(before, before), null);
});

test("writing the same option twice settles, and the file still scans as before", () => {
    const text = `hl.bind("SUPER + A", hl.dsp.window.close())\n${INPUT_LUA}`;
    for (const [path, value] of [["input:repeat_delay", 280], ["input:touchpad:tap-to-click", true], ["general:layout", "master"], ["input:kb_layout", "dk"]]) {
        const once = change(text, { path, value });
        assert.notStrictEqual(once, text, path);
        assert.deepStrictEqual(Options.planOption([{ name: "a.lua", text: once }], { path, value }), { ok: true, unchanged: true }, path);
        assert.strictEqual(HyprlandLua.scanLua(once).binds.length, 1, path);
    }
});

test("a real-world input module takes every option the panel writes", () => {
    let text = INPUT_LUA;
    const writes = [["input:kb_layout", "dk,us"], ["input:repeat_delay", 300], ["input:repeat_rate", 30], ["input:sensitivity", -0.2], ["input:touchpad:natural_scroll", false], ["input:touchpad:tap-to-click", true]];
    for (const [path, value] of writes)
        text = change(text, { path, value });
    for (const [path, value] of writes)
        assert.deepStrictEqual(Options.planOption([{ name: "a.lua", text }], { path, value }), { ok: true, unchanged: true }, path);
    assert.ok(text.includes("hl.config({ cursor = { no_hardware_cursors = true } })"));
});
