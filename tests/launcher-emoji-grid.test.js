const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const ROOT = path.resolve(__dirname, "..");
function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}
const Grid = lib("services/emoji-grid.js", ["recent", "sections", "layout", "rowOf", "step", "pinned"]);

const e = (char, group) => ({ char, group, name: char });
const run = (group, n, prefix) => Array.from({ length: n }, (_, i) => e(prefix + i, group));
const chars = (list) => list.map((x) => x.char);
const titles = (list) => list.map((s) => s.title);
const shape = (rows) => rows.map((r) => (r.header ? "header" : r.cells.length));
const solo = (items, columns) => Grid.layout([{ title: "Smileys", items }], columns).rows;
const GROUPS = ["Smileys", "People", "Flags"];
const A = e("a", "Smileys"), B = e("b", "People"), C = e("c", "Smileys"), D = e("d", "Flags");
const all = [A, B, C, D];
const byChar = { a: A, b: B, c: C };
const used = { a: { last: 1 }, b: { last: 5 }, c: { last: 3 } };
const one = solo(run("Smileys", 7, "s"), 3);
const six = solo(run("Smileys", 6, "s"), 3);
const ten = solo(run("Smileys", 10, "s"), 3);
const two = Grid.layout([
    { title: "Smileys", items: run("Smileys", 3, "a") },
    { title: "Flags", items: run("Flags", 4, "f") }
], 3).rows;

test("Recently used lists the newest emoji first", () => assert.deepStrictEqual(chars(Grid.recent(used, byChar, 10)), ["b", "c", "a"]));
test("Recently used leaves out an emoji that is no longer in the catalogue", () => assert.deepStrictEqual(chars(Grid.recent({ a: { last: 1 }, ghost: { last: 9 } }, { a: A }, 10)), ["a"]));
test("Recently used stops at the limit and keeps the newest", () => assert.deepStrictEqual(chars(Grid.recent(used, byChar, 2)), ["b", "c"]));
test("With nothing typed or chosen, Recently used comes first, then each group", () => {
    const s = Grid.sections(all, GROUPS, null, null, [D]);
    assert.deepStrictEqual(titles(s), ["Recently used", "Smileys", "People", "Flags"]);
    assert.deepStrictEqual(chars(s[0].items), ["d"]);
});
test("Groups appear in the order they were given", () => assert.deepStrictEqual(titles(Grid.sections(all, ["Flags", "People", "Smileys"], null, null, [])), ["Flags", "People", "Smileys"]));
test("A group with no emoji gets no section", () => assert.deepStrictEqual(titles(Grid.sections(all, ["Smileys", "Animals", "People", "Flags"], null, null, [])), ["Smileys", "People", "Flags"]));
test("Choosing a group shows only that group and leaves out Recently used", () => {
    const s = Grid.sections(all, GROUPS, "People", null, [D]);
    assert.deepStrictEqual(titles(s), ["People"]);
    assert.deepStrictEqual(chars(s[0].items), ["b"]);
});
test("A search shows one section with the match count and no Recently used", () => {
    const found = [A, B, C];
    const s = Grid.sections(all, GROUPS, null, found, [D]);
    assert.deepStrictEqual(titles(s), ["3 matches"]);
    assert.deepStrictEqual(s[0].items, found);
});
test("A single search match is titled in the singular", () => assert.deepStrictEqual(titles(Grid.sections(all, GROUPS, null, [B], [])), ["1 match"]));
test("A search narrowed to a group keeps only that group's matches and counts only those", () => {
    const narrowed = Grid.sections(all, GROUPS, "Smileys", [A, B, C], []);
    assert.deepStrictEqual(chars(narrowed[0].items), ["a", "c"]);
    assert.deepStrictEqual(titles(narrowed), ["2 matches"]);
});
test("Three columns lay a seven-emoji section out as a header and rows of 3, 3 and 1", () => assert.deepStrictEqual(shape(one), ["header", 3, 3, 1]));
test("Row start counts across sections", () => {
    const rows = Grid.layout([{ title: "Smileys", items: run("Smileys", 2, "s") }, { title: "Flags", items: run("Flags", 4, "f") }], 3).rows;
    assert.deepStrictEqual(shape(rows), ["header", 2, "header", 3, 1]);
    assert.deepStrictEqual(rows.filter((r) => !r.header).map((r) => r.start), [0, 2, 5]);
});
test("items is the flat list of every emoji in display order", () => {
    const a = run("Smileys", 2, "s"), b = run("Flags", 4, "f");
    assert.deepStrictEqual(Grid.layout([{ title: "Smileys", items: a }, { title: "Flags", items: b }], 3).items, a.concat(b));
});
test("An empty section gets no header", () => {
    const rows = Grid.layout([{ title: "Smileys", items: [] }, { title: "Flags", items: run("Flags", 1, "f") }], 3).rows;
    assert.deepStrictEqual(rows.filter((r) => r.header).map((r) => r.title), ["Flags"]);
});
test("rowOf finds the row holding an index", () => {
    assert.strictEqual(Grid.rowOf(one, 4), 2);
    assert.strictEqual(Grid.rowOf(one, 6), 3);
});
test("rowOf returns -1 for an index past the end", () => assert.strictEqual(Grid.rowOf(one, 7), -1));
test("Right moves one tile and stops at the last tile", () => {
    assert.strictEqual(Grid.step(one, 7, 2, 1, 0), 3);
    assert.strictEqual(Grid.step(one, 7, 6, 1, 0), 6);
});
test("Left moves one tile and stops at the first tile", () => {
    assert.strictEqual(Grid.step(one, 7, 3, -1, 0), 2);
    assert.strictEqual(Grid.step(one, 7, 0, -1, 0), 0);
});
test("Down keeps the column and skips the header between sections", () => assert.strictEqual(Grid.step(two, 7, 1, 0, 1), 4));
test("Down from the last column of a full row lands on the last tile of a shorter row", () => assert.strictEqual(Grid.step(one, 7, 5, 0, 1), 6));
test("Up from the first row goes to the first tile", () => assert.strictEqual(Grid.step(one, 7, 1, 0, -1), 0));
test("Down from the last row goes to the last tile", () => assert.strictEqual(Grid.step(six, 6, 4, 0, 1), 5));
test("Three presses down move three rows", () => assert.strictEqual(Grid.step(ten, 10, 0, 0, 3), 9));
test("An empty grid has nowhere to go", () => assert.strictEqual(Grid.step(one, 0, 0, 0, 1), -1));
test("With no tile selected, a move starts at the first tile", () => assert.strictEqual(Grid.step(one, 7, -1, 0, 1), 0));

test("Pinned emoji get their own section above the recent ones", () => assert.deepStrictEqual(titles(Grid.sections(all, GROUPS, null, null, [A], Grid.pinned(["d"], { d: D })).slice(0, 2)), ["Pinned", "Recently used"]));
test("Pins that left the catalogue are dropped", () => assert.deepStrictEqual(chars(Grid.pinned(["ghost", "a"], byChar)), ["a"]));
