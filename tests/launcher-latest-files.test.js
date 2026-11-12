const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Latest = lib("services/latest-files.js", ["ask", "readListing", "matching", "dateWindow", "needText"]);

test.describe("latest screenshots and downloads", () => {
    test.it("answers to the ways of asking, with words to narrow by", () => {
        assert.deepStrictEqual([Latest.ask("screenshots").shelf.key, Latest.ask("screenshots").words], ["screenshots", ""]);
        assert.strictEqual(Latest.ask("last screenshot").shelf.key, "screenshots");
        assert.strictEqual(Latest.ask("screenshots Banditshell").words, "banditshell");
        assert.strictEqual(Latest.ask("downloads").shelf.key, "downloads");
        assert.strictEqual(Latest.ask("last download pdf").words, "pdf");
        assert.strictEqual(Latest.ask("screen"), null);
        assert.strictEqual(Latest.ask("take screenshot"), null);
        assert.strictEqual(Latest.ask("screenshot"), null);
        assert.strictEqual(Latest.ask("download video"), null);
    });

    test.it("reads find's listing, skips hidden and unfinished files, and narrows by name", () => {
        const files = Latest.readListing("1792150000.5\tf\t/d/b.png\n1792149000\td\t/d/folder one\n1792148000\tf\t/d/.hidden\n1792147000\tf\t/d/big.iso.part\n1792140000\tf\t/d/a 1.png\n\nbroken\n");
        assert.deepStrictEqual(files.map(f => f.name), ["b.png", "folder one", "a 1.png"]);
        assert.strictEqual(files[0].modified, 1792150000500);
        assert.strictEqual(files[1].dir, true);
        assert.deepStrictEqual(Latest.matching(files, "a 1", 5).map(f => f.name), ["a 1.png"]);
        assert.strictEqual(Latest.matching(files, "", 1).length, 1);
    });
});

const NOW = new Date(2026, 10, 12, 10, 0);
const at = (m, d, h) => new Date(2026, m, d, h === undefined ? 12 : h).getTime();
const shots = [
    { path: "/s/new.png", name: "new.png", modified: at(10, 12, 9) },
    { path: "/s/eve.png", name: "eve.png", modified: at(10, 11, 20) },
    { path: "/s/old.png", name: "old.png", modified: at(9, 12, 12) }
];

test.describe("searching screenshots by date and text", () => {
    test.it("reads a day, a week or a month out of the words and keeps the rest", () => {
        const day = Latest.dateWindow("terminal yesterday", NOW);
        assert.deepStrictEqual([day.from, day.to, day.rest], [at(10, 11, 0), at(10, 12, 0), "terminal"]);
        assert.strictEqual(Latest.dateWindow("last week", NOW).from, at(10, 2, 0));
        assert.strictEqual(Latest.dateWindow("oct 12", NOW).from, at(9, 12, 0));
        assert.strictEqual(Latest.dateWindow("2026-10-12", NOW).to, at(9, 13, 0));
        assert.strictEqual(Latest.dateWindow("last thursday", NOW).from, at(10, 5, 0));
        assert.strictEqual(Latest.dateWindow("thursday", NOW).from, at(10, 12, 0));
        assert.strictEqual(Latest.dateWindow("hello world", NOW), null);
        assert.strictEqual(Latest.dateWindow("may", NOW), null);
    });

    test.it("lists only the files inside the date phrase", () => {
        assert.deepStrictEqual(Latest.matching(shots, "yesterday", 9, {}, NOW).map(f => f.name), ["eve.png"]);
        assert.deepStrictEqual(Latest.matching(shots, "oct 12", 9, {}, NOW).map(f => f.name), ["old.png"]);
    });

    test.it("finds a screenshot by the words read from it and shows where", () => {
        const texts = { "/s/old.png": { m: shots[2].modified, t: "Dear team, the invoice total is 40 euros" } };
        const got = Latest.matching(shots, "invoice", 9, texts, NOW);
        assert.deepStrictEqual(got.map(f => f.name), ["old.png"]);
        assert.match(got[0].snippet, /invoice total/);
    });

    test.it("ignores text read from an older version of a file", () => {
        const texts = { "/s/old.png": { m: 1, t: "invoice" } };
        assert.strictEqual(Latest.matching(shots, "invoice", 9, texts, NOW).length, 0);
    });

    test.it("asks to read only files the words could still be in", () => {
        assert.deepStrictEqual(Latest.needText(shots, "yesterday invoice", {}, NOW, 9).map(f => f.name), ["eve.png"]);
        assert.deepStrictEqual(Latest.needText(shots, "new", {}, NOW, 9).map(f => f.name), ["eve.png", "old.png"]);
        assert.deepStrictEqual(Latest.needText(shots, "yesterday", {}, NOW, 9), []);
    });
});
