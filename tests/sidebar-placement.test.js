const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/sidebar/placement.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { between } = new Function(src + "\nreturn { between };")();

test.describe("between", () => {
    test.it("centres the workspaces when nothing is in the way", () => {
        assert.deepStrictEqual(between(200, 1000, 100, 800), { y: 400, fits: true });
    });

    test.it("lifts them to sit just above the foot when the centre would touch it", () => {
        assert.deepStrictEqual(between(200, 1000, 100, 500), { y: 300, fits: true });
    });

    test.it("says they do not fit when the tray and the foot leave too little room", () => {
        assert.deepStrictEqual(between(200, 1000, 400, 500), { y: 400, fits: false });
    });

    test.it("pushes them down off the tray when the head is the crowded end", () => {
        assert.deepStrictEqual(between(200, 1000, 450, 900), { y: 450, fits: true });
    });
});
