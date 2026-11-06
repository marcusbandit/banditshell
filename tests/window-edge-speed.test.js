const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.join(__dirname, "..", "modules/windows/edge-speed.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { settled } = new Function(`${src}\nreturn { settled };`)();

test.describe("window lift speed", () => {
    test.it("keeps the measured speed while the finger is still moving", () => {
        assert.strictEqual(settled(1.4, 30), 1.4);
    });

    test.it("counts the speed as zero once the last touch update is older than 100 ms", () => {
        assert.strictEqual(settled(1.4, 101), 0);
        assert.strictEqual(settled(1.4, 1000), 0);
    });
});
