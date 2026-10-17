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

const Tray = lib("services/tray-search.js", ["ask", "matching", "ambient"]);

const ITEMS = [
    { key: "discord@1", id: "discord", name: "Discord", detail: "3 unread" },
    { key: "nm-applet@2", id: "nm-applet", name: "Network", detail: "" },
    { key: "steam@3", id: "steam", name: "Steam", detail: "" }
];

test.describe("asking for the tray", () => {
    test.it("answers to tray and its longer names, with words to narrow by", () => {
        assert.deepStrictEqual(Tray.ask("tray"), { words: "" });
        assert.deepStrictEqual(Tray.ask("System Tray discord"), { words: "discord" });
        assert.deepStrictEqual(Tray.ask("tray icons"), { words: "" });
        assert.deepStrictEqual(Tray.ask("tray items steam"), { words: "steam" });
    });

    test.it("leaves other words alone", () => {
        for (const text of ["trays", "traytool", "discord", ""])
            assert.strictEqual(Tray.ask(text), null, text);
    });
});

test.describe("listing tray items", () => {
    test.it("lists every item for a bare ask, up to the limit", () => {
        assert.strictEqual(Tray.matching(ITEMS, "", Ranking.place, 10).length, 3);
        assert.strictEqual(Tray.matching(ITEMS, "", Ranking.place, 2).length, 2);
    });

    test.it("narrows by the name, the id or the tooltip", () => {
        assert.deepStrictEqual(Tray.matching(ITEMS, "disc", Ranking.place, 5).map(i => i.key), ["discord@1"]);
        assert.deepStrictEqual(Tray.matching(ITEMS, "nm", Ranking.place, 5).map(i => i.key), ["nm-applet@2"]);
        assert.deepStrictEqual(Tray.matching(ITEMS, "unread", Ranking.place, 5).map(i => i.key), ["discord@1"]);
        assert.deepStrictEqual(Tray.matching(ITEMS, "zzz", Ranking.place, 5), []);
    });
});

test.describe("an app name on its own", () => {
    test.it("shows the item below every app and setting", () => {
        const rows = Tray.ambient(ITEMS, "disc", Ranking.place, 3);
        assert.deepStrictEqual(rows.map(r => r.entry.key), ["discord@1"]);
        for (const r of rows)
            assert.ok(r.score > 0 && r.score < 0.5, String(r.score));
        assert.ok(Tray.ambient(ITEMS, "steam", Ranking.place, 3)[0].score < 0.5);
    });

    test.it("stays quiet for short words, sentences and words in the middle of a name", () => {
        assert.deepStrictEqual(Tray.ambient(ITEMS, "di", Ranking.place, 3), []);
        assert.deepStrictEqual(Tray.ambient(ITEMS, "open discord", Ranking.place, 3), []);
        assert.deepStrictEqual(Tray.ambient(ITEMS, "cord", Ranking.place, 3), []);
    });
});
