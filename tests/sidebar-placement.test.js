const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/sidebar/placement.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { between, rail } = new Function(src + "\nreturn { between, rail };")();

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

test.describe("rail", () => {
    test.it("centres the pips and hands the marks everything a gap below them", () => {
        assert.deepStrictEqual(rail(100, 1000, 50, 900, 132, 32), { y: 450, room: 318 });
    });

    test.it("lifts the pips to keep the reserved slots and the gap above the foot", () => {
        assert.deepStrictEqual(rail(100, 600, 50, 400, 132, 32), { y: 136, room: 132 });
    });

    test.it("keeps the pips under the head on a rail too short for the reserve", () => {
        assert.deepStrictEqual(rail(120, 400, 40, 250, 132, 32), { y: 40, room: 58 });
    });

    test.it("never gives the marks less than the reserve while it fits", () => {
        for (let foot = 324; foot <= 900; foot += 7)
            assert.ok(rail(120, 1000, 40, foot, 132, 32).room >= 132, String(foot));
    });
});
