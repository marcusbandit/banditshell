const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Prefixes = lib("modules/launcher/prefixes.js", ["SECTIONS", "OWN", "asked", "guess", "completion", "detail", "sections"]);
const Ranking = lib("services/ranking.js", ["closest"]);

const row = (section, word, also) => ({ section: section, word: word, about: word, icon: "x", also: also || [] });

test.describe("the ? page", () => {
    test.it("opens on a lone question mark and nothing else", () => {
        assert.strictEqual(Prefixes.asked("?"), true);
        for (const text of ["", "??", "? ssh", "what?", "ssh"])
            assert.strictEqual(Prefixes.asked(text), false, text);
    });

    test.it("keeps only the prefixes no source owns", () => {
        assert.deepStrictEqual(Prefixes.OWN.map(p => p.word).sort(), [":", "=", "~"]);
        for (const p of Prefixes.OWN)
            assert.ok(Prefixes.SECTIONS.includes(p.section) && p.about && p.icon, p.word);
    });

    test.it("groups what the sources declare in section order, symbols then A to Z", () => {
        const page = Prefixes.sections([row("System", "vpn"), row("Quicklinks", "yt"), row("System", "kill"), row("Files and clipboard", "recent"), row("Files and clipboard", "~")]);
        assert.deepStrictEqual(page.map(s => [s.title, s.prefixes.map(p => p.word)]), [
            ["Files and clipboard", ["~", "recent"]],
            ["System", ["kill", "vpn"]],
            ["Quicklinks", ["yt"]]
        ]);
    });

    test.it("drops a section when every source behind it is off", () => {
        assert.deepStrictEqual(Prefixes.sections([row("Desktop", "tray")]).map(s => s.title), ["Desktop"]);
        assert.deepStrictEqual(Prefixes.sections([]), []);
    });

    test.it("lists a word once per section, and under each section that answers it", () => {
        const page = Prefixes.sections([row("Ask and look up", "gh"), row("Quicklinks", "gh"), row("Quicklinks", "gh")]);
        assert.deepStrictEqual(page.map(s => [s.title, s.prefixes.length]), [["Ask and look up", 1], ["Quicklinks", 1]]);
    });

    test.it("gives an example only when it adds something after the prefix", () => {
        for (const p of Prefixes.OWN.filter(p => p.example !== undefined)) {
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
    const declared = [row("System", "containers", ["podman", "docker"]), row("Ask and look up", "translate"), row("Desktop", "screenshots")];
    const heads = declared.flatMap(p => [p.word].concat(p.also));
    const nearly = word => word.slice(0, -1) + (word.endsWith("x") ? "y" : "x");
    const guess = (text, labels) => Prefixes.guess(text, labels, Ranking.closest, declared);

    test.it("never turns a prefix word into the name it is one letter from", () => {
        for (const head of heads.filter(h => h.length >= 5)) {
            const labels = [nearly(head)];
            assert.strictEqual(Ranking.closest(head, labels), 0, head);
            assert.strictEqual(guess(head, labels), -1, head);
            assert.strictEqual(guess(head.toUpperCase(), labels), -1, head);
        }
    });

    test.it("guesses again for a word whose source is off", () => {
        assert.strictEqual(Prefixes.guess("translate", ["Translatx"], Ranking.closest, []), 0);
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
