const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.resolve(__dirname, "../services/trace.js"), "utf8").replace(".pragma library", "");
const Trace = new Function(`${src}; return { heartbeatStall };`)();

test.describe("heartbeat stalls", () => {
    test.it("counts only the time past the heartbeat's own interval", () => {
        assert.strictEqual(Trace.heartbeatStall(16e6, 16e6, 1e9), 0);
        assert.strictEqual(Trace.heartbeatStall(66e6, 16e6, 1e9), 50e6);
    });

    test.it("never goes below zero for an early beat", () => {
        assert.strictEqual(Trace.heartbeatStall(10e6, 16e6, 1e9), 0);
    });

    test.it("ignores the build before a span's first frame", () => {
        assert.strictEqual(Trace.heartbeatStall(900e6, 16e6, -1), 0);
        assert.strictEqual(Trace.heartbeatStall(900e6, 16e6, 40e6), 24e6);
    });
});
