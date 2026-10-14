const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/keyboards.js"), "utf8");
const Keyboards = new Function(src + "\nreturn { TEMPLATE, TEMPLATE_VARIANT, templateSections, shapeNamed, parseVia, alignBoard, blockedMap, parseKeymap, keymapLegends, applyLegends };")();

const GALAXY = path.join(__dirname, "fixtures/Epomaker_Galaxy100.json");
const MINI_DEFINITION = path.join(__dirname, "fixtures/via_bandit_mini.json");
const MINI_KEYMAP = path.join(__dirname, "fixtures/via_bandit_mini.layout.json");

function via(keymap, name) {
    return Keyboards.parseVia(JSON.stringify({ name: name ?? "", layouts: { keymap } }));
}

function row(...widths) {
    const out = [];
    widths.forEach((w, i) => out.push({ w }, `r,${i}`));
    return out;
}

function board(keymap) {
    return Keyboards.alignBoard(via(keymap));
}

function byMatrix(aligned) {
    const out = {};
    for (const k of aligned.sections[0].keys)
        out[k.matrix] = k;
    return out;
}

function numbered(keymap) {
    return keymap.map((r, y) => {
        let n = 0;
        return r.map(item => typeof item === "string" && item.startsWith("r,") ? `${y},${n++}` : item);
    });
}

const ANSI_ROWS = [
    row(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2),
    row(1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5),
    row(1.75, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.25),
    row(2.25, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.75),
    row(1.25, 1.25, 1.25, 6.25, 1.25, 1.25, 1.25, 1.25)
];

const ANSI = numbered(ANSI_ROWS);

const ISO = numbered([
    row(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2),
    row(1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1).concat([{ x: 0.25, w: 1.25, h: 2, w2: 1.5, h2: 1, x2: -0.25 }, "enter"]),
    row(1.75, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
    row(1.25, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.75),
    row(1.25, 1.25, 1.25, 6.25, 1.25, 1.25, 1.25, 1.25)
]);

test("KLE x and y are offsets from the cursor, w and h are sizes", () => {
    const r = via([
        [{ x: 0 }, "0,0", { x: 1 }, "0,1", "0,2", { x: 0.25, w: 2 }, "0,3", "0,4"],
        [{ y: 0.5, w: 1.5 }, "1,0", { h: 2 }, "1,1", "1,2"]
    ], "Test Board");
    assert.strictEqual(r.error, undefined);
    assert.strictEqual(r.name, "Test Board");
    assert.deepStrictEqual(r.rows[0].map(c => c.x), [0, 2, 3, 4.25, 6.25]);
    assert.deepStrictEqual(r.rows[0].map(c => c.w), [1, 1, 1, 2, 1], "a width lasts one key");
    assert.deepStrictEqual(r.rows[1].map(c => c.y), [1.5, 1.5, 1.5]);
    assert.deepStrictEqual(r.rows[1].map(c => c.x), [0, 1.5, 2.5]);
    assert.deepStrictEqual(r.rows[1].map(c => c.h), [1, 2, 1]);
});

test("an ISO enter keeps its shape: the wide head on top, the narrow leg below it", () => {
    const enter = via(ISO).rows[1].find(c => c.matrix === "enter");
    assert.strictEqual(enter.x, 13.5);
    assert.strictEqual(enter.w, 1.5);
    assert.strictEqual(enter.h, 2);
    assert.strictEqual(enter.foot, 1.25);
});

test("layout options keep their default and skip the alternatives, without moving the rest", () => {
    const r = via([["0,0", "0,1\n\n\n0,0", "0,1\n\n\n0,1", "0,2"]]);
    assert.deepStrictEqual(r.rows[0].map(c => c.matrix), ["0,0", "0,1", "0,2"]);
    assert.deepStrictEqual(r.rows[0].map(c => c.x), [0, 1, 3]);
});

test("an encoder is marked and keeps its matrix spot", () => {
    const r = via([[{ x: 0 }, "5,3\n\n\n\n\n\n\n\n\n e0 "]]);
    assert.strictEqual(r.rows[0][0].encoder, true);
    assert.strictEqual(r.rows[0][0].matrix, "5,3");
});

test("garbage in, error out", () => {
    assert.ok(Keyboards.parseVia("nope").error);
    assert.ok(Keyboards.parseVia("{}").error);
    assert.ok(Keyboards.parseVia("{\"layouts\": {\"keymap\": []}}").error);
});

test("a two-row enter means ISO, a wide home-row enter under a 1.5u backslash means ANSI", () => {
    assert.strictEqual(board(ISO).variant, "iso");
    assert.strictEqual(board(ANSI).variant, "ansi");
});

test("ANSI legends land by position: backslash above, enter on the home row, one wide shift", () => {
    const keys = byMatrix(board(ANSI));
    assert.strictEqual(keys["0,13"].cap, "Back");
    assert.strictEqual(keys["1,13"].cap, "\\");
    assert.strictEqual(keys["2,12"].cap, "Enter");
    assert.deepStrictEqual(keys["2,12"].syms, ["Return"]);
    assert.strictEqual(keys["3,0"].mod, 1);
    assert.strictEqual(keys["3,1"].cap, "Z");
    assert.strictEqual(keys["3,11"].cap, "Shift");
    assert.strictEqual(keys["4,3"].syms[0], "space");
    assert.strictEqual(keys["4,7"].cap, "Ctrl");
});

test("ISO legends land by position: the key beside the shift and the one under the enter", () => {
    const keys = byMatrix(board(ISO));
    assert.strictEqual(keys.enter.cap, "Enter");
    assert.strictEqual(keys["2,12"].cap, "\\");
    assert.strictEqual(keys["3,0"].mod, 1);
    assert.strictEqual(keys["3,1"].cap, "<");
    assert.strictEqual(keys["3,2"].cap, "Z");
});

test("every key of a VIA board has an id, and a key no legend fits says its matrix spot", () => {
    const aligned = board(numbered([row(1, 1)].concat(ANSI_ROWS)));
    for (const k of aligned.sections[0].keys)
        assert.ok(k.id, `${k.matrix} has no id`);
    const keys = byMatrix(aligned);
    assert.strictEqual(keys["0,0"].cap, "Esc");
    assert.strictEqual(keys["0,1"].cap, "F1");
    const extra = byMatrix(board(numbered([row(1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, 1)].concat(ANSI_ROWS.slice(1)))));
    assert.strictEqual(extra["0,14"].cap, "0,14");
    assert.deepStrictEqual(extra["0,14"].syms, []);
});

test("the real Galaxy100: ANSI, arrows by shape, the numpad by x, the knob and the maker's keys honest", () => {
    assert.ok(fs.existsSync(GALAXY), "the Galaxy100 fixture is missing from tests/fixtures");
    const parsed = Keyboards.parseVia(fs.readFileSync(GALAXY, "utf8"));
    assert.strictEqual(parsed.error, undefined);
    assert.strictEqual(parsed.name, "Epomaker Galaxy100");
    assert.strictEqual(parsed.rows.length, 6);

    const aligned = Keyboards.alignBoard(parsed);
    assert.strictEqual(aligned.variant, "ansi");
    assert.strictEqual(aligned.sections[0].keys.length, 101);
    assert.strictEqual(aligned.sections[0].width, 20.5);
    assert.strictEqual(aligned.sections[0].height, 6);

    const keys = byMatrix(aligned);
    const caps = spots => spots.map(m => keys[m].cap);
    assert.deepStrictEqual(caps(["0,0", "0,1", "0,12"]), ["Esc", "F1", "F12"]);
    assert.strictEqual(keys["0,1"].x, 2, "F1 sits one gap after Esc");
    assert.deepStrictEqual(caps(["1,0", "1,13", "2,13", "3,13"]), ["`", "Back", "\\", "Enter"]);
    assert.deepStrictEqual(caps(["4,2", "4,11", "4,13"]), ["Z", "/", "Shift"]);
    assert.strictEqual(keys["4,0"].mod, 1);
    assert.deepStrictEqual(caps(["4,14", "5,13", "5,14", "5,15"]), ["↑", "←", "↓", "→"]);
    assert.deepStrictEqual(caps(["6,0", "6,3", "6,4", "6,10", "4,15", "6,15", "6,13", "6,14"]), ["Num", "-", "7", "+", "1", "Enter", "0", "."]);
    assert.deepStrictEqual(keys["6,15"].syms, ["KP_Enter"]);
    assert.strictEqual(keys["6,10"].h, 2);
    assert.strictEqual(keys["6,13"].w, 2);
    assert.strictEqual(keys["5,3"].encoder, true);
    assert.strictEqual(keys["5,3"].cap, "Knob");
    assert.deepStrictEqual(caps(["0,13", "0,14", "0,15", "3,15", "5,4"]), ["0,13", "0,14", "0,15", "3,15", "5,4"]);
});

test("the template's numpad is one block: every row starts at its left edge", () => {
    const pad = Keyboards.TEMPLATE.find(s => s.id === "numpad");
    assert.strictEqual(pad.width, 4);
    assert.strictEqual(pad.height, 5);
    const lefts = {};
    for (const k of pad.keys)
        lefts[k.y] = Math.min(lefts[k.y] ?? Infinity, k.x);
    assert.deepStrictEqual(Object.values(lefts), [0, 0, 0, 0, 0]);
    const zero = pad.keys.find(k => k.id === "KP0");
    const dot = pad.keys.find(k => k.id === "KPDL");
    assert.deepStrictEqual([zero.x, zero.w, dot.x], [0, 2, 2]);
    assert.strictEqual(Keyboards.TEMPLATE_VARIANT, "iso");
});

test("blocked keys come from a list or a map, and carry their why", () => {
    assert.deepStrictEqual(Keyboards.blockedMap(["p", "KP_5"]), { "p": "", "kp_5": "" });
    assert.deepStrictEqual(Keyboards.blockedMap({ "p": "firmware owns it", " 0,4 ": "" }), { "p": "firmware owns it", "0,4": "" });
    assert.deepStrictEqual(Keyboards.blockedMap(undefined), {});
    assert.deepStrictEqual(Keyboards.blockedMap(""), {});
});

function mainOf(shape) {
    return Keyboards.templateSections(shape).find(s => s.id === "main");
}

test("the template draws the shape it is given, and an unknown shape is iso", () => {
    assert.deepStrictEqual(Keyboards.shapeNamed("split"), "split");
    assert.deepStrictEqual(Keyboards.shapeNamed("ansi"), "ansi");
    assert.deepStrictEqual(Keyboards.shapeNamed("dvorak"), "iso");
    assert.deepStrictEqual(Keyboards.shapeNamed(undefined), "iso");
    assert.ok(mainOf("iso").keys.some(k => k.id === "LSGT"));
    assert.ok(!mainOf("ansi").keys.some(k => k.id === "LSGT"));
    assert.strictEqual(mainOf("iso").keys.find(k => k.id === "RTRN").h, 2);
    assert.strictEqual(mainOf("ansi").keys.find(k => k.id === "RTRN").h, 1);
});

test("the split board leaves a gap down the middle of every row", () => {
    const main = mainOf("split");
    const edges = [["AE06", "AE07"], ["AD05", "AD06"], ["AC05", "AC06"], ["AB05", "AB06"]];
    for (const [left, right] of edges) {
        const a = main.keys.find(k => k.id === left);
        const b = main.keys.find(k => k.id === right);
        assert.strictEqual(b.x - (a.x + a.w), 1, `${left} to ${right}`);
    }
    const spaces = main.keys.filter(k => k.syms.includes("space"));
    assert.deepStrictEqual(spaces.map(k => k.w), [3.25, 2.75]);
    assert.strictEqual(spaces[1].x - (spaces[0].x + spaces[0].w), 1);
    const ansi = mainOf("ansi");
    assert.strictEqual(main.keys.length, ansi.keys.length + 1);
    assert.strictEqual(main.height, ansi.height);
});

test("the split board keeps the arrows in one cluster", () => {
    const main = mainOf("split");
    const at = id => main.keys.find(k => k.id === id);
    assert.strictEqual(at("UP").x, at("DOWN").x);
    assert.strictEqual(at("LEFT").x + 1, at("DOWN").x);
    assert.strictEqual(at("DOWN").x + 1, at("RGHT").x);
    assert.strictEqual(at("UP").y + 1, at("DOWN").y);
    for (const k of main.keys)
        for (const other of main.keys)
            if (k !== other && k.y === other.y)
                assert.ok(k.x + k.w <= other.x || other.x + other.w <= k.x, `${k.id} overlaps ${other.id}`);
});

function mini() {
    const definition = Keyboards.parseVia(fs.readFileSync(MINI_DEFINITION, "utf8"));
    const keymap = Keyboards.parseKeymap(fs.readFileSync(MINI_KEYMAP, "utf8"));
    return { definition, keymap };
}

test("a VIA definition carries its board id and matrix size", () => {
    const { definition } = mini();
    assert.strictEqual(definition.error, undefined);
    assert.strictEqual(definition.vendorProductId, 3033595905);
    assert.deepStrictEqual(definition.matrix, { rows: 4, cols: 6 });
    const galaxy = Keyboards.parseVia(fs.readFileSync(GALAXY, "utf8"));
    assert.strictEqual(galaxy.vendorProductId, 0x36B0 * 65536 + 0x30D4);
    assert.deepStrictEqual(galaxy.matrix, { rows: 7, cols: 16 });
    assert.strictEqual(via([["0,0"]]).vendorProductId, null);
});

test("a saved VIA keymap is read down to its first layer, and a wrong file says why", () => {
    const { keymap } = mini();
    assert.strictEqual(keymap.error, undefined);
    assert.strictEqual(keymap.name, "Bandit Mini");
    assert.strictEqual(keymap.layer.length, 24);
    assert.strictEqual(keymap.layer[0], "KC_ESC");
    assert.match(Keyboards.parseKeymap("nope").error, /not JSON/);
    assert.match(Keyboards.parseKeymap("{}").error, /no layers/);
    assert.match(Keyboards.parseKeymap(JSON.stringify({ layers: [] })).error, /no layers/);
    assert.match(Keyboards.parseKeymap(JSON.stringify({ layers: [["KC_A"]] })).error, /no vendorProductId/);
    assert.match(Keyboards.parseKeymap(fs.readFileSync(MINI_DEFINITION, "utf8")).error, /definition, not a keymap/);
    assert.match(Keyboards.parseVia(fs.readFileSync(MINI_KEYMAP, "utf8")).error, /saved keymap, not a definition/);
});

test("a keymap lands on matrix positions and names the keys Hyprland binds", () => {
    const { definition, keymap } = mini();
    const made = Keyboards.keymapLegends(definition, keymap);
    assert.strictEqual(made.error, undefined);
    const legends = made.legends;
    assert.deepStrictEqual(Object.keys(legends).length, 24);
    assert.deepStrictEqual(legends["0,0"].syms, ["Escape"]);
    assert.deepStrictEqual(legends["0,1"].syms, ["q"]);
    assert.deepStrictEqual(legends["1,5"].syms, ["Return"]);
    assert.strictEqual(legends["0,5"].role, "BKSP");
    assert.strictEqual(legends["2,0"].mod, 1);
    assert.strictEqual(legends["2,0"].label, "shift");
    assert.strictEqual(legends["3,0"].mod, 4);
    assert.strictEqual(legends["3,1"].mod, 64);
    assert.strictEqual(legends["3,1"].label, "super");
    assert.deepStrictEqual(legends["3,2"].syms, ["a"], "a mod-tap acts as its tap key");
    assert.deepStrictEqual(legends["3,3"].syms, ["space"], "a layer-tap acts as its tap key");
    assert.strictEqual(legends["3,4"].cap, "Fn1");
    assert.deepStrictEqual(legends["3,4"].syms, []);
    assert.deepStrictEqual(legends["2,5"].syms, [], "KC_NO binds nothing");
    assert.deepStrictEqual(legends["3,5"].syms, [], "a keycode the sheet cannot name binds nothing");
});

test("a keymap for another board is refused", () => {
    const { definition, keymap } = mini();
    const other = Object.assign({}, keymap, { vendorProductId: keymap.vendorProductId + 1 });
    assert.match(Keyboards.keymapLegends(definition, other).error, /Bandit Mini, not the imported definition/);
    const galaxy = Keyboards.parseVia(fs.readFileSync(GALAXY, "utf8"));
    assert.ok(Keyboards.keymapLegends(galaxy, keymap).error);
    const short = Object.assign({}, keymap, { layer: keymap.layer.slice(0, 10) });
    assert.match(Keyboards.keymapLegends(definition, short).error, /10 keys, the definition's matrix holds 24/);
    const unsized = Object.assign({}, definition, { matrix: { rows: 0, cols: 0 } });
    assert.match(Keyboards.keymapLegends(unsized, keymap).error, /no matrix size/);
});

test("a keymap relabels the imported board, and keys it does not name keep their position", () => {
    const { definition, keymap } = mini();
    const aligned = Keyboards.alignBoard(definition);
    const dressed = Keyboards.applyLegends(aligned, Keyboards.keymapLegends(definition, keymap).legends);
    const keys = byMatrix(dressed);
    assert.deepStrictEqual(keys["1,2"].syms, ["s"]);
    assert.strictEqual(keys["0,5"].cap, "Back");
    assert.strictEqual(keys["3,1"].mod, 64);
    assert.strictEqual(keys["3,5"].cap, "3,5", "a blank legend falls back to the matrix spot");
    assert.strictEqual(keys["2,0"].mod, 1);
    assert.strictEqual(keys["3,1"].cap, "", "a modifier is drawn as its glyph alone");
    assert.strictEqual(keys["3,3"].cap, "", "space has no legend of its own");
    assert.strictEqual(dressed.sections[0].keys.length, aligned.sections[0].keys.length);
    assert.strictEqual(keys["0,0"].x, byMatrix(aligned)["0,0"].x);
    const partial = Keyboards.applyLegends(aligned, { "0,1": { cap: "Q", syms: ["q"], mod: 0, role: "AD01" } });
    assert.deepStrictEqual(byMatrix(partial)["1,1"].syms, byMatrix(aligned)["1,1"].syms);
    assert.deepStrictEqual(byMatrix(partial)["0,1"].syms, ["q"]);
});

test("keyboards.js uses nothing Quickshell's engine lacks", () => {
    for (const api of ["matchAll", "replaceAll", "flatMap", ".flat(", "trimEnd", "trimStart", "fromEntries", "findLast", ".at(", "(?<"])
        assert.ok(!src.includes(api), `keyboards.js uses ${api}, which Quickshell's JavaScript engine does not have`);
});
