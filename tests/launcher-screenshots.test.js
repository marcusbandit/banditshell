const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Shots = lib("services/screenshots.js", ["ask", "readListing", "matching"]);

test.describe("screenshots in the launcher", () => {
    test.it("answers to the ways of asking, with words to narrow by", () => {
        assert.strictEqual(Shots.ask("screenshots"), "");
        assert.strictEqual(Shots.ask("Screenshot"), "");
        assert.strictEqual(Shots.ask("last screenshot"), "");
        assert.strictEqual(Shots.ask("screenshots Banditshell"), "banditshell");
        assert.strictEqual(Shots.ask("screen"), null);
        assert.strictEqual(Shots.ask("take screenshot"), null);
    });

    test.it("reads find's listing, newest first as given, and narrows by name", () => {
        const shots = Shots.readListing("1792150000.5\t/home/u/Pictures/Screenshots/b.png\n1792140000\t/home/u/Pictures/Screenshots/a 1.png\n\nbroken\n");
        assert.deepStrictEqual(shots.map(s => s.name), ["b.png", "a 1.png"]);
        assert.strictEqual(shots[0].modified, 1792150000500);
        assert.deepStrictEqual(Shots.matching(shots, "a 1", 5).map(s => s.name), ["a 1.png"]);
        assert.strictEqual(Shots.matching(shots, "", 1).length, 1);
    });
});
