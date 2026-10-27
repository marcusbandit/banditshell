const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/clipboard-shelf.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Shelf = new Function(src + "\nreturn { identity, shelve, kept, restored, salvage, survivors };")();

const entry = (id, text, extra) => Object.assign({ id, recorded: Number(id), text, pinned: false }, extra);

test.describe("clipboard clear and undo", () => {
    const history = [entry("5", "five"), entry("4", "four", { pinned: true }), entry("3", "three"), entry("2", "two", { pinned: true }), entry("1", "one")];

    test.it("shelves every unpinned entry and keeps the pinned ones", () => {
        const shelf = Shelf.shelve(history);
        assert.deepStrictEqual(shelf.entries.map(e => e.id), ["5", "3", "1"]);
        assert.deepStrictEqual(Shelf.kept(history).map(e => e.id), ["4", "2"]);
    });

    test.it("puts cleared entries back exactly where they were", () => {
        const shelf = Shelf.shelve(history);
        assert.deepStrictEqual(Shelf.restored(Shelf.kept(history), shelf).map(e => e.id), ["5", "4", "3", "2", "1"]);
    });

    test.it("keeps copies made during the undo window on top", () => {
        const shelf = Shelf.shelve(history);
        const now = [entry("9", "new"), ...Shelf.kept(history)];
        assert.deepStrictEqual(Shelf.restored(now, shelf).map(e => e.id), ["9", "5", "4", "3", "2", "1"]);
    });

    test.it("brings back one copy of an entry copied again during the window", () => {
        const shelf = Shelf.shelve(history);
        const now = [entry("9", "three"), ...Shelf.kept(history)];
        assert.deepStrictEqual(Shelf.restored(now, shelf).map(e => e.id), ["9", "5", "4", "2", "1"]);
    });

    test.it("leaves out a pinned entry deleted during the window", () => {
        const shelf = Shelf.shelve(history);
        assert.deepStrictEqual(Shelf.restored([history[1]], shelf).map(e => e.id), ["5", "4", "3", "1"]);
    });
});

test.describe("clipboard salvage from an unreadable history file", () => {
    const good = { version: 1, entries: [entry("3", "pinned {brace} \"quote\"", { pinned: true }), entry("2", "loose"), { id: "1", file: "/s/a.png", pinned: true, recorded: 1 }] };

    test.it("reads every whole entry from a file cut off mid-write", () => {
        const text = JSON.stringify(good);
        const cut = text.slice(0, text.indexOf('"/s/a.png"'));
        assert.deepStrictEqual(Shelf.salvage(cut).map(e => e.id), ["3", "2"]);
    });

    test.it("skips an entry garbled in the middle and keeps reading", () => {
        const text = JSON.stringify(good).replace('"loose"', '"loose" broken:');
        assert.deepStrictEqual(Shelf.salvage(text).map(e => e.id), ["3", "1"]);
    });

    test.it("finds nothing in a file that is not a history at all", () => {
        assert.deepStrictEqual(Shelf.salvage("\u0000\u0001garbage"), []);
        assert.deepStrictEqual(Shelf.salvage(""), []);
    });

    test.it("keeps only salvaged pinned entries the shell does not already hold", () => {
        const salvaged = Shelf.salvage(JSON.stringify(good));
        const memory = [entry("7", "pinned {brace} \"quote\"", { pinned: true })];
        assert.deepStrictEqual(Shelf.survivors(memory, salvaged).map(e => e.id), ["7", "1"]);
    });
});
