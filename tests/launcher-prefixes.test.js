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
const { scanSource } = require("../scripts/lint-rules.js");

function declaredIn(file) {
    const text = fs.readFileSync(file, "utf8");
    const { code } = scanSource(text);
    const opening = /property var (?:prefixes|parsedHere): (?:![\w.]+ \? \[\] : )?\[\n/g;
    const rows = [];
    let found;
    while ((found = opening.exec(code))) {
        const start = opening.lastIndex - 2;
        let depth = 0;
        let end = start;
        for (; end < code.length; end++) {
            if (code[end] === "[")
                depth++;
            else if (code[end] === "]" && --depth === 0)
                break;
        }
        rows.push(...new Function(`return ${text.slice(start, end + 1)};`)().map(p => Object.assign({ file: path.basename(file) }, p)));
    }
    return rows;
}

const SOURCES = path.join(ROOT, "modules/launcher/sources");
const DECLARED = Prefixes.OWN.concat(declaredIn(path.join(ROOT, "modules/launcher/LauncherSearch.qml")), ...fs.readdirSync(SOURCES).filter(f => f.endsWith(".qml")).sort().map(f => declaredIn(path.join(SOURCES, f))));

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

test.describe("the rows each source declares", () => {
    test.it("are found in the sources", () => {
        assert.ok(DECLARED.length > 40, `${DECLARED.length} rows`);
        assert.ok(DECLARED.some(p => p.file === "LauncherSearch.qml"));
    });

    test.it("name a section the page shows, say what they do and have an icon", () => {
        for (const p of DECLARED)
            assert.ok(Prefixes.SECTIONS.includes(p.section) && p.about && p.icon && Array.isArray(p.also), `${p.file}: ${p.word} in ${p.section}`);
    });

    test.it("give an example only when it adds something after the prefix", () => {
        for (const p of DECLARED.filter(p => p.example !== undefined)) {
            const typed = Prefixes.completion(p);
            assert.ok(p.example.startsWith(typed) && p.example.trim().length > typed.trim().length, `${p.file}: ${p.example}`);
        }
    });

    test.it("declare each word and alias once", () => {
        const heads = DECLARED.flatMap(p => [p.word].concat(p.also));
        assert.deepStrictEqual(heads.filter((h, i) => heads.indexOf(h) !== i), []);
    });

    test.it("are never turned into the name a letter away", () => {
        const nearly = word => word.slice(0, -1) + (word.endsWith("x") ? "y" : "x");
        for (const head of DECLARED.flatMap(p => [p.word].concat(p.also)).filter(h => h.length >= 5)) {
            const labels = [nearly(head)];
            assert.strictEqual(Ranking.closest(head, labels), 0, head);
            assert.strictEqual(Prefixes.guess(head, labels, Ranking.closest, DECLARED), -1, head);
        }
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
