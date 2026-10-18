const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/spring.js"), "utf8").replace(".pragma library", "");
const S = new Function(src + "\nreturn { step, rest, heldSpeed };")();
const config = fs.readFileSync(path.join(ROOT, "config/Config.qml"), "utf8");
const block = config.match(/spring:\s*\{([^}]*)\}/)[1];
const tuned = name => Number(block.match(new RegExp(`${name}:\\s*([\\d.]+)`))[1]);
const K = tuned("stiffness");
const C = tuned("damping");
const M = tuned("mass");

function run(x, v, k, c, m, seconds, dt) {
    let s = { x, v };
    let low = x;
    let high = x;
    for (let t = 0; t < seconds; t += dt) {
        s = S.step(s.x, s.v, k, c, m, dt);
        low = Math.min(low, s.x);
        high = Math.max(high, s.x);
    }
    return { end: s, low, high };
}

test.describe("spring step", () => {
    test.it("comes back to rest from a pull, whatever the damping", () => {
        for (const c of [5, C, 2 * Math.sqrt(K * M), 80]) {
            const out = run(100, 0, K, c, M, 6, 1 / 60);
            assert.ok(Math.abs(out.end.x) < 0.25, `damping ${c} ended at ${out.end.x}`);
        }
    });

    test.it("the shipped spring bounces a little, a few percent past the middle", () => {
        const out = run(100, 0, K, C, M, 2, 1 / 240);
        const overshoot = -out.low;
        assert.ok(overshoot > 1 && overshoot < 8, `overshoot ${overshoot}%`);
    });

    test.it("the shipped spring settles in about a third of a second", () => {
        let s = { x: 100, v: 0 };
        let t = 0;
        while (!S.rest(s.x, s.v, K, M, 0.5) && t < 3) {
            s = S.step(s.x, s.v, K, C, M, 1 / 120);
            t += 1 / 120;
        }
        assert.ok(t > 0.2 && t < 0.8, `settled after ${t.toFixed(3)} s`);
    });

    test.it("critical and heavier damping never cross the middle", () => {
        for (const c of [2 * Math.sqrt(K * M), 80]) {
            const out = run(100, 0, K, c, M, 3, 1 / 120);
            assert.ok(out.low > -1e-9, `damping ${c} crossed to ${out.low}`);
        }
    });

    test.it("is exact: two short frames land where one long frame does", () => {
        for (const c of [C, 2 * Math.sqrt(K * M), 80]) {
            const a = S.step(80, -300, K, c, M, 0.05);
            const half = S.step(80, -300, K, c, M, 0.02);
            const b = S.step(half.x, half.v, K, c, M, 0.03);
            assert.ok(Math.abs(a.x - b.x) < 1e-6 && Math.abs(a.v - b.v) < 1e-6, `damping ${c}`);
        }
    });

    test.it("a throw keeps going the way it was thrown before it turns", () => {
        const s = S.step(0, 2000, K, C, M, 1 / 60);
        assert.ok(s.x > 0 && s.v > 0);
    });
});

test.describe("held speed", () => {
    test.it("follows a steady drag and forgets a stale one", () => {
        let speed = 0;
        for (let i = 0; i < 30; i++)
            speed = S.heldSpeed(speed, 8, 0.008);
        assert.ok(Math.abs(speed - 1000) < 10, `speed ${speed}`);
        speed = S.heldSpeed(speed, 0, 0.2);
        assert.ok(speed < 50, `after a still finger ${speed}`);
    });
});
