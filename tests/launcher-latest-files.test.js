const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Latest = lib("services/latest-files.js", ["ask", "readListing", "matching"]);

test.describe("latest screenshots and downloads", () => {
    test.it("answers to the ways of asking, with words to narrow by", () => {
        assert.deepStrictEqual([Latest.ask("screenshots").shelf.key, Latest.ask("screenshots").words], ["screenshots", ""]);
        assert.strictEqual(Latest.ask("last screenshot").shelf.key, "screenshots");
        assert.strictEqual(Latest.ask("screenshots Banditshell").words, "banditshell");
        assert.strictEqual(Latest.ask("downloads").shelf.key, "downloads");
        assert.strictEqual(Latest.ask("last download pdf").words, "pdf");
        assert.strictEqual(Latest.ask("screen"), null);
        assert.strictEqual(Latest.ask("take screenshot"), null);
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
