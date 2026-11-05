const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.join(__dirname, "..", "services/workspace-span.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { span } = new Function(`${src}\nreturn { span };`)();

test.describe("workspace span", () => {
    test.it("is the persistent count when nothing is past it", () => {
        assert.strictEqual(span(5, 1, Infinity, [1, 2, 3], 2), 5);
    });

    test.it("grows a slot for a busy workspace past the persistent count", () => {
        assert.strictEqual(span(5, 1, Infinity, [1, 6], 1), 6);
    });

    test.it("grows a slot for the workspace being viewed", () => {
        assert.strictEqual(span(5, 1, Infinity, [], 6), 6);
    });

    test.it("shrinks back once the extra workspace is empty and left", () => {
        assert.strictEqual(span(5, 1, Infinity, [1], 2), 5);
    });

    test.it("keeps a gap of empty workspaces between the busy one and the column", () => {
        assert.strictEqual(span(5, 1, Infinity, [8], 1), 8);
    });

    test.it("counts from the first id of a band", () => {
        assert.strictEqual(span(5, 11, Infinity, [16], 11), 6);
        assert.strictEqual(span(5, 11, Infinity, [3, 4], 11), 5);
    });

    test.it("stops at the band's last workspace", () => {
        assert.strictEqual(span(3, 1, 4, [4], 1), 4);
        assert.strictEqual(span(3, 1, 4, [9], 1), 3);
    });

    test.it("ignores workspaces more than ten past the first", () => {
        assert.strictEqual(span(5, 1, Infinity, [10], 1), 10);
        assert.strictEqual(span(5, 1, Infinity, [40], 1), 5);
    });

    test.it("ignores special workspaces and the next band", () => {
        assert.strictEqual(span(5, 1, 10, [-98, 12], -98), 5);
    });
});
