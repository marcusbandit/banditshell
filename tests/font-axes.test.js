const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/font-axes.js"), "utf8").replace(".pragma library", "");
const FontAxes = new Function(src + "\nreturn { weight, fill, opticalSize };")();

function distinct(values) {
    return new Set(values).size;
}

function frames(from, to, count) {
    const out = [];
    for (let i = 0; i <= count; i++)
        out.push(from + (to - from) * i / count);
    return out;
}

test("a lock clock digit flip asks for a handful of weights however many frames it draws", () => {
    const weights = frames(0, 1, 2000).map(turn => FontAxes.weight(Math.max(100, Math.min(900, 600 * (0.25 + 0.75 * turn)))));
    assert.ok(distinct(weights) <= 20, `${distinct(weights)} weights`);
    assert.strictEqual(Math.min(...weights), 150);
    assert.strictEqual(Math.max(...weights), 600);
});

test("a fixed weight stays the weight it was asked for", () => {
    for (const w of [300, 450, 500, 550, 600, 650])
        assert.strictEqual(FontAxes.weight(w), w);
});

test("an animated icon fill takes eleven values from empty to full", () => {
    const fills = frames(0, 1, 1000).map(FontAxes.fill);
    assert.strictEqual(distinct(fills), 11);
    assert.strictEqual(FontAxes.fill(0), 0);
    assert.strictEqual(FontAxes.fill(1), 1);
    assert.strictEqual(FontAxes.fill(1.4), 1);
});

test("an icon's optical size follows its size in whole points", () => {
    assert.strictEqual(distinct(frames(20, 48, 500).map(FontAxes.opticalSize)), 29);
});
