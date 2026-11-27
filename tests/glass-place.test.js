const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/glass-place.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { placeOf, sourceIn } = new Function(src + "\nreturn { placeOf, sourceIn };")();

test.describe("where an item sits in its window", () => {
    test.it("adds every parent's position, scrolled content included", () => {
        const content = { x: 0, y: 0, parent: null };
        const list = { x: 40, y: 100, parent: content };
        const scrolled = { x: 0, y: -250, parent: list };
        const card = { x: 8, y: 300, parent: scrolled };
        assert.deepStrictEqual(placeOf(card), { x: 48, y: 150, scale: 1, beneath: false });
    });

    test.it("notices glass under it from any parent but not from itself", () => {
        const content = { x: 0, y: 0, parent: null };
        const panel = { x: 10, y: 10, parent: content, glassBeneath: true };
        const sheet = { x: 5, y: 5, parent: panel };
        assert.strictEqual(placeOf(sheet).beneath, true);
        assert.strictEqual(placeOf({ x: 0, y: 0, parent: content, glassBeneath: true }).beneath, false);
        assert.strictEqual(placeOf({ x: 0, y: 0, parent: { x: 0, y: 0, parent: null, glassBeneath: false } }).beneath, false);
    });
});

test.describe("how an item is scaled", () => {
    test.it("multiplies the scale of every parent", () => {
        const content = { x: 0, y: 0, parent: null, scale: 1 };
        const peek = { x: 0, y: 0, parent: content, scale: 0.96 };
        assert.strictEqual(placeOf({ x: 0, y: 0, parent: peek, scale: 0.5 }).scale, 0.48);
    });
});

test.describe("which backdrop a window has", () => {
    test.it("finds the source offered by the same window and nothing for another", () => {
        const shell = {};
        const picker = {};
        const behind = {};
        const entries = [{ window: shell, source: behind }];
        assert.strictEqual(sourceIn(entries, shell), behind);
        assert.strictEqual(sourceIn(entries, picker), null);
        assert.strictEqual(sourceIn([], shell), null);
    });

    test.it("prefers the newest of two backdrops in one window and falls back when it goes", () => {
        const shell = {};
        const first = {};
        const second = {};
        assert.strictEqual(sourceIn([{ window: shell, source: first }, { window: shell, source: second }], shell), second);
        assert.strictEqual(sourceIn([{ window: shell, source: first }], shell), first);
    });
});
