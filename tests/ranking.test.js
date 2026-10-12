const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/ranking.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Ranking = new Function(src + "\nreturn { EXACT, PREFIX, WORD, ANYWHERE, NONE, escapeRegex, place, subsequence };")();

test.describe("place", () => {
    test.it("ranks exact over prefix over word start over anywhere", () => {
        assert.strictEqual(Ranking.place("firefox", "firefox"), Ranking.EXACT);
        assert.strictEqual(Ranking.place("firefox", "fire"), Ranking.PREFIX);
        assert.strictEqual(Ranking.place("mozilla firefox", "fire"), Ranking.WORD);
        assert.strictEqual(Ranking.place("libreoffice", "office"), Ranking.ANYWHERE);
        assert.strictEqual(Ranking.place("kitty", "fox"), Ranking.NONE);
        assert.ok(Ranking.EXACT > Ranking.PREFIX && Ranking.PREFIX > Ranking.WORD && Ranking.WORD > Ranking.ANYWHERE && Ranking.ANYWHERE > Ranking.NONE);
    });

    test.it("ignores case", () => {
        assert.strictEqual(Ranking.place("Firefox", "FIRE"), Ranking.PREFIX);
        assert.strictEqual(Ranking.place("GNU Image Manipulation", "image"), Ranking.WORD);
    });

    test.it("treats an empty needle as matching everything", () => {
        assert.strictEqual(Ranking.place("anything", ""), Ranking.EXACT);
        assert.strictEqual(Ranking.place("", undefined), Ranking.EXACT);
    });

    test.it("takes regex characters in the needle literally", () => {
        assert.strictEqual(Ranking.place("c++ compiler", "c++"), Ranking.PREFIX);
        assert.strictEqual(Ranking.place("price (usd)", "(usd)"), Ranking.ANYWHERE);
        assert.strictEqual(Ranking.place("a.b", "."), Ranking.WORD);
        assert.strictEqual(Ranking.place("abc", "."), Ranking.NONE);
        assert.strictEqual(Ranking.place("x [y]", "[y"), Ranking.ANYWHERE);
        assert.strictEqual(Ranking.place("path\\to", "\\to"), Ranking.WORD);
    });

    test.it("handles missing haystacks", () => {
        assert.strictEqual(Ranking.place(undefined, "x"), Ranking.NONE);
        assert.strictEqual(Ranking.place(null, "x"), Ranking.NONE);
    });
});

test.describe("escapeRegex", () => {
    test.it("escapes every metacharacter", () => {
        const special = ".*+?^${}()|[]\\";
        assert.ok(new RegExp(`^${Ranking.escapeRegex(special)}$`).test(special));
    });
});

test.describe("subsequence", () => {
    test.it("finds letters in order with gaps", () => {
        assert.ok(Ranking.subsequence("visual studio code", "vsc"));
        assert.ok(Ranking.subsequence("Thunderbird", "TBD"));
        assert.ok(!Ranking.subsequence("code", "vsc"));
        assert.ok(!Ranking.subsequence("ab", "abc"));
    });
});
