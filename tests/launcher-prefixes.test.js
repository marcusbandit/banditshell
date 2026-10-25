const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Prefixes = lib("modules/launcher/prefixes.js", ["PREFIXES", "asked", "claims", "completion"]);
const Ranking = lib("services/ranking.js", ["closest"]);

test.describe("the ? page", () => {
    test.it("opens on a lone question mark and nothing else", () => {
        assert.strictEqual(Prefixes.asked("?"), true);
        for (const text of ["", "??", "? ssh", "what?", "ssh"])
            assert.strictEqual(Prefixes.asked(text), false, text);
    });

    test.it("lists each prefix once with an example that starts the way Enter types it", () => {
        const seen = new Set();
        for (const p of Prefixes.PREFIXES) {
            assert.ok(!seen.has(p.word), `${p.word} listed twice`);
            seen.add(p.word);
            assert.ok(p.example === p.word || p.example.startsWith(Prefixes.completion(p)), `${p.word}: ${p.example}`);
            assert.ok(p.about && p.icon, p.word);
        }
    });
});

test.describe("typo guesses leave prefixes alone", () => {
    const words = Prefixes.PREFIXES.map(p => p.word);
    const asks = ["?"].concat(words, words.map(w => `${w} `), Prefixes.PREFIXES.map(p => p.example));

    test.it("claims ?, every prefix and every example", () => {
        for (const text of asks)
            assert.strictEqual(Prefixes.claims(text.trim()), true, text);
    });

    test.it("claims a prefix in any case", () => {
        assert.strictEqual(Prefixes.claims("SSH nemurenai"), true);
    });

    test.it("leaves a plain typo free to be guessed", () => {
        for (const text of ["frefiox", "lok screen", "nigth light", "sshd-config"])
            assert.strictEqual(Prefixes.claims(text), false, text);
    });

    test.it("blocks the guess a prefix would otherwise get", () => {
        const near = words.filter(w => w.length >= 5).map(w => w.slice(0, -1) + (w.endsWith("x") ? "y" : "x"));
        const blocked = words.filter(w => Ranking.closest(w, near) >= 0);
        assert.ok(blocked.length > 0);
        for (const word of blocked)
            assert.strictEqual(Prefixes.claims(word), true, word);
    });
});
