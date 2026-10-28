const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/clipboard-shelf.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Shelf = new Function(src + "\nreturn { identity, shelve, kept, restored, salvage, stamp, backupCommand };")();

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

});

test.describe("clipboard backup of a damaged history file", () => {
    const when = new Date(2026, 9, 28, 14, 5, 9);

    function backUp(file) {
        const [bin, ...args] = Shelf.backupCommand(file, when);
        return spawnSync(bin, args, { encoding: "utf8" });
    }

    function folder() {
        return fs.mkdtempSync(path.join(os.tmpdir(), "clipboard-backup-"));
    }

    test.it("names the copy after the moment it was made", () => {
        assert.strictEqual(Shelf.stamp(when), "20261028-140509");
    });

    test.it("copies the damaged file beside it and leaves the original as it was", () => {
        const dir = folder();
        try {
            const file = path.join(dir, "clipboard.json");
            const damaged = '{"version":1,"entries":[{"id":"1","text":"a pass with a \'quote\' in it"},{"id":"2","te';
            fs.writeFileSync(file, damaged, { mode: 0o644 });
            const done = backUp(file);
            assert.strictEqual(done.status, 0, done.stderr);
            const copy = `${file}.damaged-20261028-140509`;
            assert.strictEqual(done.stdout.trim(), copy);
            assert.strictEqual(fs.readFileSync(copy, "utf8"), damaged);
            assert.strictEqual(fs.readFileSync(file, "utf8"), damaged);
            assert.strictEqual(fs.statSync(copy).mode & 0o077, 0);
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
        }
    });

    test.it("never writes over an earlier copy", () => {
        const dir = folder();
        try {
            const file = path.join(dir, "clip board.json");
            fs.writeFileSync(file, "second");
            fs.writeFileSync(`${file}.damaged-20261028-140509`, "first");
            const done = backUp(file);
            assert.strictEqual(done.status, 0, done.stderr);
            assert.strictEqual(fs.readFileSync(`${file}.damaged-20261028-140509`, "utf8"), "first");
            assert.strictEqual(fs.readFileSync(`${file}.damaged-20261028-140509-2`, "utf8"), "second");
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
        }
    });

    test.it("fails when no copy could be made", () => {
        const dir = folder();
        try {
            const done = backUp(path.join(dir, "missing.json"));
            assert.notStrictEqual(done.status, 0);
            assert.deepStrictEqual(fs.readdirSync(dir), []);
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
        }
    });
});
