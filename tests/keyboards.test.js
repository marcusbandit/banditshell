const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/keyboards.js"), "utf8");
const Keyboards = new Function(src + "\nreturn { TEMPLATE, TEMPLATE_VARIANT, parseVia, alignBoard, blockedMap };")();

const GALAXY = path.join(__dirname, "fixtures/Epomaker_Galaxy100.json");

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

test("keyboards.js uses nothing Quickshell's engine lacks", () => {
    for (const api of ["matchAll", "replaceAll", "flatMap", ".flat(", "trimEnd", "trimStart", "fromEntries", "findLast", ".at(", "(?<"])
        assert.ok(!src.includes(api), `keyboards.js uses ${api}, which Quickshell's JavaScript engine does not have`);
});
