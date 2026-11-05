const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.join(__dirname, "..", "modules/sidebar/workspaces.js"), "utf8").replace(/^\.pragma .*$/m, "");
const W = new Function(`${src}\nreturn { stride, eased, settled, flickDirection, notchTarget, markRow, HIT_REACH };`)();

function flick(rate, pxPerSecond, ms) {
    const dt = 1000 / rate;
    const step = pxPerSecond / rate;
    let speed = 0;
    for (let t = 0; t < ms; t += dt)
        speed = W.eased(speed, step, dt);
    return speed;
}

test.describe("workspace column scrub", () => {
    test.it("reads a 500 px/s flick as a flick at 125 Hz and at 1000 Hz", () => {
        assert.strictEqual(W.flickDirection(flick(125, 500, 80)), 1);
        assert.strictEqual(W.flickDirection(flick(1000, 500, 80)), 1);
        assert.strictEqual(W.flickDirection(flick(1000, -500, 80)), -1);
    });

    test.it("does not read a slow drag as a flick at any report rate", () => {
        assert.strictEqual(W.flickDirection(flick(125, 80, 300)), 0);
        assert.strictEqual(W.flickDirection(flick(1000, 80, 300)), 0);
    });

    test.it("gives the same speed at 125 Hz and at 1000 Hz", () => {
        assert.ok(Math.abs(flick(125, 600, 150) - flick(1000, 600, 150)) < 0.02);
    });

    test.it("counts the speed as zero after a pause", () => {
        const fast = flick(1000, 800, 80);
        assert.strictEqual(W.flickDirection(W.settled(fast, 300)), 0);
        assert.strictEqual(W.flickDirection(W.settled(fast, 20)), 1);
    });

    test.it("keeps a gap of at least 24 px per workspace", () => {
        assert.strictEqual(W.stride(6, 6, W.HIT_REACH), 18);
        assert.strictEqual(W.stride(32, 12, W.HIT_REACH), 12);
        assert.strictEqual(W.stride(5, 12, W.HIT_REACH), 19);
    });
});

test.describe("workspace column wheel", () => {
    test.it("moves exactly one workspace per notch from the active one", () => {
        assert.strictEqual(W.notchTarget(3, null, 0, 1000, 1, 1, 5), 4);
        assert.strictEqual(W.notchTarget(3, null, 0, 1000, -1, 1, 5), 2);
    });

    test.it("adds a fast spin onto the pending target instead of the stale active one", () => {
        assert.strictEqual(W.notchTarget(3, 4, 1000, 1050, 1, 1, 8), 5);
        assert.strictEqual(W.notchTarget(3, 5, 1000, 1100, 1, 1, 8), 6);
    });

    test.it("forgets the pending target once the wheel has been idle", () => {
        assert.strictEqual(W.notchTarget(3, 7, 1000, 2000, 1, 1, 8), 4);
    });

    test.it("stops at the first and last workspace of the band", () => {
        assert.strictEqual(W.notchTarget(1, null, 0, 0, -1, 1, 5), 1);
        assert.strictEqual(W.notchTarget(5, null, 0, 0, 1, 1, 5), 5);
    });
});

test.describe("workspace plate marks", () => {
    test.it("finds the window row under the pointer", () => {
        assert.strictEqual(W.markRow(16, 32, 20, 2), 0);
        assert.strictEqual(W.markRow(40, 32, 20, 2), 1);
    });

    test.it("finds no row outside the marks", () => {
        assert.strictEqual(W.markRow(2, 32, 20, 2), -1);
        assert.strictEqual(W.markRow(70, 32, 20, 2), -1);
    });
});
