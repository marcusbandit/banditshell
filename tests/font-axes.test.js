const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/font-axes.js"), "utf8").replace(".pragma library", "");
const FontAxes = new Function(src + "\nreturn { between, opticalSize };")();

function distinct(values) {
    return new Set(values).size;
}

function frames(count) {
    const out = [];
    for (let i = 0; i <= count; i++)
        out.push(i / count);
    return out;
}

function clockWeight(presence) {
    return FontAxes.between(220, 620, presence);
}

function digitWeight(presence, turn) {
    const weight = clockWeight(presence);
    return FontAxes.between(Math.max(100, weight * 0.25), weight, turn);
}

test("a value at rest is exactly the end it rests at", () => {
    assert.strictEqual(FontAxes.between(220, 620, 0), 220);
    assert.strictEqual(FontAxes.between(220, 620, 1), 620);
    assert.strictEqual(FontAxes.between(300, 460, 1), 460);
    assert.strictEqual(FontAxes.between(0, 1, 1.4), 1);
    assert.strictEqual(FontAxes.between(0, 1, -0.2), 0);
});

test("a fade drawn over any number of frames takes seventeen values", () => {
    assert.strictEqual(distinct(frames(5000).map(p => FontAxes.between(300, 460, p))), 17);
    assert.strictEqual(distinct(frames(5000).map(p => FontAxes.between(0, 1, p))), 17);
});

test("the lock clock's digits rest at the clock's weight, asleep or awake", () => {
    assert.strictEqual(digitWeight(0, 1), 220);
    assert.strictEqual(digitWeight(1, 1), 620);
    assert.strictEqual(digitWeight(1, 0), 155);
    assert.strictEqual(digitWeight(0, 0), 100);
});

test("a digit flip during a slow wake still asks for a bounded set of weights", () => {
    const weights = [];
    for (const presence of frames(3000))
        for (const turn of frames(60))
            weights.push(digitWeight(presence, turn));
    assert.ok(distinct(weights) <= 17 * 17, `${distinct(weights)} weights`);
    assert.ok(weights.every(w => w >= 100 && w <= 620));
});

test("an icon's optical size follows its size in whole points", () => {
    assert.strictEqual(distinct(frames(500).map(p => FontAxes.opticalSize(20 + 28 * p))), 29);
});
