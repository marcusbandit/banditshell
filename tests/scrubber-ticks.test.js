const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/media/scrubber-ticks.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { nextTick, pixelOf } = new Function(src + "\nreturn { nextTick, pixelOf };")();

test("a long track ticks on the next whole second, just after it", () => {
    assert.strictEqual(nextTick(61.25, 1440, 1, 400), 770);
});

test("a short track ticks when the pip reaches the next pixel", () => {
    assert.strictEqual(nextTick(10.05, 40, 1, 400), 70);
});

test("every elapsed second gets its own tick on a three minute song", () => {
    let t = 0;
    const seconds = new Set();
    while (t < 30) {
        t += nextTick(t, 185, 1, 437) / 1000;
        seconds.add(Math.floor(t));
    }
    for (let s = 1; s < 30; s++)
        assert.ok(seconds.has(s), `second ${s} was skipped`);
});

test("double speed halves the wait", () => {
    assert.strictEqual(nextTick(61.5, 1440, 2, 400), 270);
});

test("no length or no room falls back to once a second", () => {
    assert.strictEqual(nextTick(5, 0, 1, 400), 1000);
    assert.strictEqual(nextTick(5, 200, 1, 0), 1000);
});

test("the wait never drops below 50 ms", () => {
    assert.strictEqual(nextTick(9.9999, 1000, 1, 10), 50);
});

test("the pip lands on whole device pixels", () => {
    assert.strictEqual(pixelOf(0.5, 301, 1), 150);
    assert.strictEqual(pixelOf(0.5, 301, 2), 150.5);
    assert.strictEqual(pixelOf(1, 301, 2), 301);
});
