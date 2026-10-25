const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notification-shelf.js"), "utf8");
const Shelf = new Function(src + "\nreturn { shelve, restored };")();

const at = time => ({ time });

test("undo puts cards back where they were, newest first", () => {
    const [a, b, c, d] = [at(40), at(30), at(20), at(10)];
    assert.deepStrictEqual(Shelf.restored([a, d], [c, b]), [a, b, c, d]);
});

test("undo leaves cards that arrived meanwhile in their place", () => {
    const [fresh, old, older] = [at(50), at(20), at(10)];
    assert.deepStrictEqual(Shelf.restored([fresh, older], [old]), [fresh, old, older]);
});

test("a card already back is not doubled", () => {
    const a = at(10);
    assert.deepStrictEqual(Shelf.restored([a], [a]), [a]);
});

test("a second dismiss inside the window joins the first", () => {
    const [a, b] = [at(2), at(1)];
    const shelf = Shelf.shelve(Shelf.shelve([], [{ entry: a }]), [{ entry: b }, { entry: a }]);
    assert.deepStrictEqual(shelf.map(r => r.entry), [a, b]);
});
