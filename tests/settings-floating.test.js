const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Floating = lib("modules/settings/floating.js", ["place", "spotOf", "dragged", "drawn"]);

test("a floating panel starts in the middle of its room", () => {
    const room = { x: 100, y: 20, w: 1000, h: 800 };
    assert.deepStrictEqual(Floating.place(room, 400, 200, null), { x: 400, y: 320 });
    assert.deepStrictEqual(Floating.place(room, 400, 200, { x: -50, y: 30 }), { x: 350, y: 350 });
});

test("a floating panel never leaves its room", () => {
    const room = { x: 100, y: 20, w: 1000, h: 800 };
    assert.deepStrictEqual(Floating.place(room, 400, 200, { x: -5000, y: 5000 }), { x: 100, y: 620 });
    assert.deepStrictEqual(Floating.place(room, 1400, 900, { x: 300, y: 0 }), { x: 100, y: 20 });
});

test("a drag past the edge keeps the spot it stopped at", () => {
    const room = { x: 0, y: 0, w: 1000, h: 1000 };
    const spot = Floating.dragged(room, 400, 400, { x: 0, y: 0 }, 900, -20);
    assert.deepStrictEqual(spot, { x: 300, y: -20 });
    assert.deepStrictEqual(Floating.place(room, 400, 400, spot), { x: 600, y: 280 });
    assert.deepStrictEqual(Floating.spotOf(room, 400, 400, 300, 300), { x: 0, y: 0 });
});

test("a drag starts from where the window is drawn, not from a spot left over from a bigger screen", () => {
    const room = { x: 0, y: 0, w: 1000, h: 1000 };
    const stored = { x: 4000, y: 0 };
    const start = Floating.drawn(room, 400, 400, stored);
    assert.deepStrictEqual(start, { x: 300, y: 0 });
    const moved = Floating.dragged(room, 400, 400, start, -50, 0);
    assert.strictEqual(Floating.place(room, 400, 400, moved).x, 550);
});

test("growing a window keeps its top edge where the shorter window had it", () => {
    const room = { x: 0, y: 0, w: 1000, h: 1000 };
    const short = Floating.place(room, 400, 600, null);
    const tall = Floating.place(room, 400, 800, null, 600);
    assert.strictEqual(tall.y, short.y);
    assert.strictEqual(tall.x, short.x);
});

test("a window that cannot grow down any further moves up just enough", () => {
    const room = { x: 0, y: 0, w: 1000, h: 1000 };
    assert.strictEqual(Floating.place(room, 400, 900, { x: 0, y: 150 }, 600).y, 100);
});

test("a drag of a grown window stays 1:1 and round-trips through its spot", () => {
    const room = { x: 0, y: 0, w: 1000, h: 1000 };
    const start = Floating.drawn(room, 400, 700, null, 600);
    const spot = Floating.dragged(room, 400, 700, start, 0, 40, 600);
    assert.strictEqual(Floating.place(room, 400, 700, spot, 600).y, Floating.place(room, 400, 700, null, 600).y + 40);
});
