const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/scrolling-gaps.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Gaps = new Function(src + "\nreturn { batch, readOptions, readVersion, check, describe };")();

const BATCH = [
    '{"option": "general:layout", "str": "scrolling", "set": true }',
    '{"option": "scrolling:direction", "str": "right", "set": false }',
    '{"option": "general:gaps_in", "css": "5 5 5 5", "set": true }',
    '{"option": "general:gaps_out", "css": "10 10 10 10", "set": true }'
].join("\n\n\n");

const even = n => ({ top: n, right: n, bottom: n, left: n });
const state = extra => Object.assign({ version: [0, 57, 1] }, Gaps.readOptions(BATCH), extra);

test("reads a real hyprctl batch and its version", () => {
    assert.deepStrictEqual(Gaps.readOptions(BATCH), { layout: "scrolling", direction: "right", gapsIn: even(5), gapsOut: even(10) });
    assert.deepStrictEqual(Gaps.readVersion('{\n    "branch": "v0.57.1",\n    "version": "0.57.1"\n}'), [0, 57, 1]);
    assert.strictEqual(Gaps.readVersion("not json"), null);
    assert.deepStrictEqual(Gaps.batch().split(" ; ").length, 4);
});

test("an even gaps_out on 0.57 scrolling sideways is uneven at the sides", () => {
    const found = Gaps.check(state());
    assert.deepStrictEqual(found.want, { top: 10, right: 5, bottom: 10, left: 5 });
    assert.strictEqual(Gaps.describe(found), "Windows sit 15px from the frame at the sides and 10px at the top and bottom, because Hyprland's scrolling layout adds gaps_in there.");
});

test("scrolling down moves the fix to the top and bottom", () => {
    assert.deepStrictEqual(Gaps.check(state({ direction: "down" })).want, { top: 5, right: 10, bottom: 5, left: 10 });
});

test("nothing is flagged where the edges are already even or chosen", () => {
    assert.strictEqual(Gaps.check(state({ version: [0, 56, 2] })), null, "before 0.57 the ends had no gaps_in");
    assert.strictEqual(Gaps.check(state({ layout: "dwindle" })), null);
    assert.strictEqual(Gaps.check(state({ gapsOut: { top: 10, right: 5, bottom: 10, left: 5 } })), null, "already fixed");
    assert.strictEqual(Gaps.check(state({ gapsIn: even(0) })), null);
    assert.strictEqual(Gaps.check(state({ gapsIn: even(15) })), null, "gaps_out too small to take gaps_in off");
    assert.strictEqual(Gaps.check(state({ version: null })), null);
});
