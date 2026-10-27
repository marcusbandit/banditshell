const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");

test.describe("colour drift", () => {
    const fresh = () => new Function(read("components/colour-drift.js") + "\nreturn { phaseAt };")();

    test.it("goes on from where it stopped instead of jumping ahead by the pause", () => {
        const Drift = fresh();
        let t = 1000000;
        let phase = 0;
        for (let i = 0; i < 60; i++)
            phase = Drift.phaseAt(t += 16, 40000);
        const resumed = Drift.phaseAt(t + 90000, 40000);
        assert.ok(Math.abs(resumed - phase) < 1e-9, `${phase} then ${resumed}`);
        assert.ok(Drift.phaseAt(t + 90016, 40000) > resumed);
    });

    test.it("keeps two fields that move at once on the same phase", () => {
        const Drift = fresh();
        Drift.phaseAt(5000, 40000);
        const one = Drift.phaseAt(5016, 40000);
        const two = Drift.phaseAt(5016, 40000);
        assert.strictEqual(one, two);
    });
});
