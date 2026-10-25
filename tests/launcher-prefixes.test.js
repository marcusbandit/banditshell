const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Prefixes = lib("modules/launcher/prefixes.js", ["SECTIONS", "PREFIXES", "asked", "guess", "completion", "detail"]);
const Ranking = lib("services/ranking.js", ["closest"]);

test.describe("the ? page", () => {
    test.it("opens on a lone question mark and nothing else", () => {
        assert.strictEqual(Prefixes.asked("?"), true);
        for (const text of ["", "??", "? ssh", "what?", "ssh"])
            assert.strictEqual(Prefixes.asked(text), false, text);
    });

    test.it("lists each prefix once, under a titled section", () => {
        const seen = new Set();
        for (const section of Prefixes.SECTIONS) {
            assert.ok(section.title && section.prefixes.length, section.title);
            for (const p of section.prefixes) {
                assert.ok(!seen.has(p.word), `${p.word} listed twice`);
                seen.add(p.word);
                assert.ok(p.about && p.icon, p.word);
            }
        }
        assert.strictEqual(seen.size, Prefixes.PREFIXES.length);
    });

    test.it("gives an example only when it adds something after the prefix", () => {
        for (const p of Prefixes.PREFIXES.filter(p => p.example !== undefined)) {
            const typed = Prefixes.completion(p);
            assert.ok(p.example.startsWith(typed) && p.example.trim().length > typed.trim().length, `${p.word}: ${p.example}`);
        }
    });

    test.it("says what a prefix does, with its example when it has one", () => {
        assert.strictEqual(Prefixes.detail({ about: "Connect to a host", example: "ssh nemurenai" }), "Connect to a host, as in ssh nemurenai");
        assert.strictEqual(Prefixes.detail({ about: "Test your internet speed" }), "Test your internet speed");
    });
});

test.describe("typo guesses leave prefixes alone", () => {
    const heads = Prefixes.PREFIXES.flatMap(p => [p.word].concat(p.also));
    const nearly = word => word.slice(0, -1) + (word.endsWith("x") ? "y" : "x");
    const guess = (text, labels) => Prefixes.guess(text, labels, Ranking.closest);

    test.it("never turns a prefix word into the name it is one letter from", () => {
        const long = heads.filter(h => h.length >= 5);
        assert.ok(long.length > 10);
        for (const head of long) {
            const labels = [nearly(head)];
            assert.strictEqual(Ranking.closest(head, labels), 0, head);
            assert.strictEqual(guess(head, labels), -1, head);
            assert.strictEqual(guess(head.toUpperCase(), labels), -1, head);
        }
    });

    test.it("never guesses for a lone ? or a question after it", () => {
        assert.strictEqual(guess("?", ["?"]), -1);
        assert.strictEqual(guess("? firefxo", ["Firefox"]), -1);
    });

    test.it("still guesses a typo, even one that follows a prefix word", () => {
        assert.strictEqual(guess("frefiox", ["Firefox"]), 0);
        assert.strictEqual(guess("lok screen", ["Lock screen"]), 0);
        assert.strictEqual(guess("github desktp", ["GitHub Desktop"]), 0);
    });
});
