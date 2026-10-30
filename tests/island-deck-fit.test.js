const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/island/deck-fit.js"), "utf8").replace(/^\.pragma .*$/m, "");
const DeckFit = new Function(`${src}\nreturn { wholeCards, clippedEntries };`)();

test("keeps only the cards that fit whole", () => {
    const tops = [0, 100, 200, 300];
    assert.strictEqual(DeckFit.wholeCards(tops, 250, 3), 2);
    assert.strictEqual(DeckFit.wholeCards(tops, 300, 3), 3);
    assert.strictEqual(DeckFit.wholeCards(tops, 1000, 3), 3);
});

test("always keeps the front card, even when it alone is too tall", () => {
    assert.strictEqual(DeckFit.wholeCards([0, 400, 500], 250, 2), 1);
});

test("never counts more cards than the deck holds", () => {
    assert.strictEqual(DeckFit.wholeCards([0, 100, 200, 300], 1000, 2), 2);
    assert.strictEqual(DeckFit.wholeCards([0], 1000, 0), 0);
});

test("a cut group adds every entry still standing, an open group only its hidden ones", () => {
    const a1 = {}, b1 = {}, b2 = {}, b3 = { leaving: true }, c1 = {}, c2 = {};
    const groups = [{ entries: [a1] }, { entries: [b1, b2, b3] }, { entries: [c1, c2] }];
    assert.strictEqual(DeckFit.clippedEntries(groups, [b1]), 2);
    assert.strictEqual(DeckFit.clippedEntries(groups, [c2]), 1);
    assert.strictEqual(DeckFit.clippedEntries(groups, []), 0);
});
