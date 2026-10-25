const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/ranking.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Ranking = new Function(src + "\nreturn { EXACT, PREFIX, WORD, ANYWHERE, NONE, escapeRegex, place, subsequence, typos, closest };")();

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

test.describe("typos", () => {
    test.it("counts a wrong, missing, extra or swapped letter as one", () => {
        assert.strictEqual(Ranking.typos("firefox", "firefox"), 0);
        assert.strictEqual(Ranking.typos("firefox", "firefax"), 1);
        assert.strictEqual(Ranking.typos("firefox", "firfox"), 1);
        assert.strictEqual(Ranking.typos("firefox", "fireefox"), 1);
        assert.strictEqual(Ranking.typos("firefox", "fierfox"), 1);
    });

    test.it("measures the whole name, so a started word is not a typo", () => {
        assert.strictEqual(Ranking.typos("thunderbird", "thunder"), 4);
    });
});

test.describe("closest", () => {
    const names = ["Firefox", "Lock screen", "Files", "Kitty", "Night light"];

    test.it("finds the name one typo away", () => {
        assert.strictEqual(names[Ranking.closest("lok screen", names)], "Lock screen");
        assert.strictEqual(names[Ranking.closest("firefxo", names)], "Firefox");
        assert.strictEqual(names[Ranking.closest("nigth light", names)], "Night light");
    });

    test.it("takes the right letters in the wrong order", () => {
        assert.strictEqual(names[Ranking.closest("frefiox", names)], "Firefox");
    });

    test.it("matches the end of a name from a word start", () => {
        assert.strictEqual(names[Ranking.closest("screne", names)], "Lock screen");
        assert.strictEqual(Ranking.closest("übersciht", ["Neue Übersicht"]), 0);
        assert.strictEqual(Ranking.closest("ndern zeiit", ["Ändern Zeit"]), -1);
    });

    test.it("guesses nothing under five letters or past the typo limit", () => {
        assert.strictEqual(Ranking.closest("kity", names), -1);
        assert.strictEqual(Ranking.closest("pikachu", names), -1);
        assert.strictEqual(Ranking.closest("xyzzyq", names), -1);
    });

    test.it("leaves ordinary words for the web search", () => {
        const labels = ["Suspend", "Variable refresh", "Mail", "Sleep displays", "Airplane mode"];
        for (const word of ["suspended", "maria", "email", "gmail", "sleepy", "airplay"])
            assert.strictEqual(Ranking.closest(word, labels), -1, word);
    });

    test.it("prefers fewer typos, then a match at the start of the name", () => {
        assert.strictEqual(Ranking.closest("filex", ["Firefox", "Files"]), 1);
        assert.strictEqual(Ranking.closest("lighst", ["Night lights", "Lights"]), 1);
    });
});
