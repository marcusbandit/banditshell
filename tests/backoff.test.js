const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
const Backoff = new Function(read("components/backoff.js") + "\nreturn { grow };")();

function checks(base, cap, span) {
    const at = [];
    let t = 0;
    let step = base;
    while (t + step <= span) {
        t += step;
        at.push(t);
        step = Backoff.grow(step, base, cap);
    }
    return at;
}

const RETRIES = {
    dictation: [2000, 30000],
    obs: [3000, 30000],
    hyprpicker: [3000, 30000],
    portal: [8000, 120000],
    chargeLimit: [30000, 600000],
    stuckPlayer: [2500, 60000]
};

test.describe("backoff", () => {
    test.it("doubles from the base and stops at the cap", () => {
        const steps = [2000];
        while (steps.length < 6)
            steps.push(Backoff.grow(steps[steps.length - 1], 2000, 30000));
        assert.deepStrictEqual(steps, [2000, 4000, 8000, 16000, 30000, 30000]);
    });

    test.it("starts again at the base from a step it does not recognise", () => {
        for (const junk of [0, -5, NaN, undefined, 500])
            assert.strictEqual(Backoff.grow(junk, 2000, 30000), 2000);
    });

    test.it("notices a thing that comes back within the cap, whenever it comes back", () => {
        for (const [name, [base, cap]] of Object.entries(RETRIES)) {
            const hour = 3600000;
            const times = checks(base, cap, hour + cap);
            for (let back = 0; back <= hour; back += 977) {
                const seen = times.find(t => t >= back);
                assert.ok(seen !== undefined && seen - back <= cap, `${name}: back at ${back} ms, seen at ${seen}`);
            }
        }
    });

    test.it("wakes the dictation retry fewer than 130 times in an hour down, not 1800", () => {
        assert.ok(checks(2000, 30000, 3600000).length < 130);
    });
});
