const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Ranking = lib("services/ranking.js", ["place"]);

const Special = lib("services/special-workspaces.js", ["ask", "listed", "matching", "labelOf", "detailOf", "windowsText"]);

const LIVE = [
    { id: -98, label: "music", windows: [1] },
    { id: -99, label: "communication", windows: [1, 2] },
    { id: -97, label: "torrents", windows: [] }
];

test.describe("asking for special workspaces", () => {
    test.it("answers to scratchpad and special, with a name to narrow by", () => {
        assert.deepStrictEqual(Special.ask("scratchpad"), { words: "" });
        assert.deepStrictEqual(Special.ask("Scratch pad"), { words: "" });
        assert.deepStrictEqual(Special.ask("special music"), { words: "music" });
        assert.deepStrictEqual(Special.ask("special workspaces"), { words: "" });
        assert.deepStrictEqual(Special.ask("scratchpad comm"), { words: "comm" });
    });

    test.it("leaves unrelated words alone", () => {
        for (const text of ["scratchy", "specialist", "workspace 2", "specialized", ""])
            assert.strictEqual(Special.ask(text), null, text);
    });
});

test.describe("what the rows list", () => {
    test.it("lists every live special with its window count", () => {
        const list = Special.listed(LIVE);
        assert.deepStrictEqual(list.map(e => [e.name, e.windows, e.fallback]), [["music", 1, false], ["communication", 2, false], ["torrents", 0, false]]);
    });

    test.it("offers the default special workspace when none exists, named the scratchpad", () => {
        const list = Special.listed([]);
        assert.deepStrictEqual(list, [{ name: "special", windows: 0, fallback: true }]);
        assert.strictEqual(Special.labelOf(list[0]), "Scratchpad");
        assert.strictEqual(Special.labelOf(Special.listed(LIVE)[0]), "music");
    });

    test.it("narrows by name and keeps the order for a bare ask", () => {
        const list = Special.listed(LIVE);
        assert.deepStrictEqual(Special.matching(list, "", Ranking.place, 10).map(e => e.name), ["music", "communication", "torrents"]);
        assert.deepStrictEqual(Special.matching(list, "comm", Ranking.place, 10).map(e => e.name), ["communication"]);
        assert.deepStrictEqual(Special.matching(list, "nope", Ranking.place, 10), []);
        assert.strictEqual(Special.matching(list, "", Ranking.place, 1).length, 1);
    });

    test.it("says whether a special is open and how full it is", () => {
        assert.strictEqual(Special.windowsText(0), "empty");
        assert.strictEqual(Special.windowsText(1), "1 window");
        assert.strictEqual(Special.windowsText(4), "4 windows");
        assert.strictEqual(Special.detailOf({ windows: 2 }, true), "special workspace · open · 2 windows");
        assert.strictEqual(Special.detailOf({ windows: 0 }, false), "special workspace · empty");
    });
});
