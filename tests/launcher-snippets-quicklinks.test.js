const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Snippets = lib("services/snippets.js", ["find", "copyName", "keywordRoom", "keywordBefore"]);
const Quicklinks = lib("services/quicklinks.js", ["slots", "takes", "resolve", "values", "missing", "sample", "originOf", "copyOf", "problem"]);

test.describe("snippet pins and copies", () => {
    const LIST = [
        { id: "a", name: "Address", keyword: ";addr", text: "x" },
        { id: "b", name: "Apology", keyword: ";sorry", text: "y", pinned: true },
        { id: "c", name: "Agenda", keyword: "", text: "z" }
    ];

    test.it("lists a pinned snippet first when browsing", () => {
        assert.deepStrictEqual(Snippets.find(LIST, "", true).map(f => f.snippet.id), ["b", "a", "c"]);
    });

    test.it("names a copy so it never clashes with another snippet", () => {
        assert.strictEqual(Snippets.copyName(LIST, "Address"), "Address copy");
        assert.strictEqual(Snippets.copyName(LIST.concat([{ name: "Address copy" }]), "Address"), "Address copy 2");
    });
});

test.describe("expanding a keyword typed before the cursor", () => {
    const LIST = [
        { id: "a", name: "Signature", keyword: ";sig", text: "x" },
        { id: "b", name: "Long", keyword: ";longsig", text: "y" },
        { id: "c", name: "Plain", keyword: "brb", text: "z" }
    ];

    test.it("selects as many characters as the longest keyword, plus one", () => {
        assert.strictEqual(Snippets.keywordRoom(LIST), 8);
        assert.strictEqual(Snippets.keywordRoom([]), 0);
    });

    test.it("finds the keyword at the end of the text and prefers the longest", () => {
        assert.strictEqual(Snippets.keywordBefore(LIST, "hello ;sig").snippet.id, "a");
        assert.strictEqual(Snippets.keywordBefore(LIST, "x ;longsig").snippet.id, "b");
        assert.strictEqual(Snippets.keywordBefore(LIST, "brb").length, 3);
    });

    test.it("ignores a keyword that ends a longer word", () => {
        assert.strictEqual(Snippets.keywordBefore(LIST, "carbrb"), null);
        assert.strictEqual(Snippets.keywordBefore(LIST, "hello"), null);
    });
});

test.describe("quicklink arguments", () => {
    const THREE = "https://example.com/{from}/{to}?d={date}";

    test.it("keeps one query working as before", () => {
        assert.strictEqual(Quicklinks.resolve("https://x.com/?q={query}", "cats and dogs"), "https://x.com/?q=cats%20and%20dogs");
        assert.strictEqual(Quicklinks.resolve("https://x.com/?q={query}", ""), "https://x.com/");
    });

    test.it("fills several named arguments in the order they first appear", () => {
        assert.deepStrictEqual(Quicklinks.slots(THREE), ["from", "to", "date"]);
        assert.strictEqual(Quicklinks.resolve(THREE, "cph lon 2026-12-01"), "https://example.com/cph/lon?d=2026-12-01");
    });

    test.it("gives the last argument the rest of the words", () => {
        assert.deepStrictEqual(Quicklinks.values("https://x.com/{a}/{b}", "one two three"), ["one", "two three"]);
    });

    test.it("fills a repeated name with the same value and leaves a missing one empty", () => {
        assert.strictEqual(Quicklinks.resolve("https://x.com/{a}/{a}/{b}", "one"), "https://x.com/one/one/");
    });

    test.it("takes at most three arguments", () => {
        assert.strictEqual(Quicklinks.slots("https://x.com/{a}{b}{c}{d}").length, 3);
    });

    test.it("says which argument comes next", () => {
        assert.strictEqual(Quicklinks.missing(THREE, "cph"), "to");
        assert.strictEqual(Quicklinks.missing(THREE, "cph lon 5"), "");
        assert.strictEqual(Quicklinks.missing("https://x.com/{query}", ""), "");
    });
});

test.describe("quicklink duplicates and icons", () => {
    const LIST = [
        { name: "GitHub", keyword: "gh", url: "https://github.com/search?q={query}" },
        { name: "GitHub copy", keyword: "gh2", url: "https://github.com/" }
    ];

    test.it("copies a link under a free name and keyword", () => {
        assert.deepStrictEqual(Quicklinks.copyOf(LIST, LIST[0]), { name: "GitHub copy 2", keyword: "gh3", url: LIST[0].url });
    });

    test.it("copies a link whose keyword is the only gap", () => {
        const made = Quicklinks.copyOf([LIST[0]], LIST[0]);
        assert.strictEqual(made.keyword, "gh2");
        assert.strictEqual(Quicklinks.problem(made), "");
    });

    test.it("finds the site root a favicon belongs to", () => {
        assert.strictEqual(Quicklinks.originOf("https://www.youtube.com/results?search_query={query}"), "https://www.youtube.com/");
        assert.strictEqual(Quicklinks.originOf("not a link"), "");
    });
});
