const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/terminal-wheel.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Wheel = new Function(`${src}\nreturn { rows };`)();

function drag(events, cell) {
    let carry = 0;
    let total = 0;
    for (const pixels of events) {
        const moved = Wheel.rows(carry, pixels, 0, cell);
        carry = moved.carry;
        total += moved.step;
    }
    return total;
}

test.describe("terminal wheel", () => {
    test.it("adds small touchpad events up until whole rows pass", () => {
        assert.strictEqual(drag(new Array(100).fill(1), 24), 4);
        assert.strictEqual(drag(new Array(10).fill(10), 24), 4);
    });

    test.it("scrolls the other way with the same remainder", () => {
        assert.strictEqual(drag(new Array(100).fill(-1), 24), -4);
    });

    test.it("keeps a mouse notch at three rows", () => {
        assert.strictEqual(Wheel.rows(0, 0, 120, 24).step, 3);
        assert.strictEqual(Wheel.rows(0, 0, -120, 24).step, -3);
    });

    test.it("does not scroll on a first event smaller than a row", () => {
        const moved = Wheel.rows(0, 5, 0, 24);
        assert.strictEqual(moved.step, 0);
        assert.ok(moved.carry > 0);
    });
});
