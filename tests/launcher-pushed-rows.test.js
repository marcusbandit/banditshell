const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Pushed = lib("services/pushed-rows.js", ["empty", "readRow", "parseRow", "added", "removed", "live", "nextExpiry", "rowsOf", "readStore", "scoreOf", "iconOf", "titleOfTool"]);
const Ranking = lib("services/ranking.js", ["place"]);

const NOW = 1_800_000_000_000;

function row(fields) {
    const read = Pushed.readRow(Object.assign({ tool: "deploy", id: "failed", title: "Deploy failed" }, fields), NOW);
    assert.ok(read.row, read.error);
    return read.row;
}

test.describe("pushed launcher rows", () => {
    test.it("reads a row with its title, subtitle, keywords and link", () => {
        const r = row({ subtitle: "main · 2 minutes ago", keywords: ["ci", "build"], open: "https://ci.example.org/run/41" });
        assert.deepStrictEqual([r.title, r.subtitle, r.keywords, r.open, r.copy, r.run], ["Deploy failed", "main · 2 minutes ago", ["ci", "build"], "https://ci.example.org/run/41", "", []]);
    });

    test.it("takes keywords as a list or as words in one string", () => {
        assert.deepStrictEqual(row({ keywords: "ci  build " }).keywords, ["ci", "build"]);
    });

    test.it("refuses a row without a title, tool or plain id", () => {
        assert.match(Pushed.readRow({ tool: "deploy", id: "x" }, NOW).error, /title/);
        assert.match(Pushed.readRow({ id: "x", title: "T" }, NOW).error, /tool/);
        assert.match(Pushed.readRow({ tool: "deploy", id: "Has Space", title: "T" }, NOW).error, /id/);
        assert.match(Pushed.readRow({ tool: "../etc", id: "x", title: "T" }, NOW).error, /tool/);
        assert.match(Pushed.readRow([], NOW).error, /object/);
        assert.match(Pushed.parseRow("{nope", NOW).error, /not JSON/);
    });

    test.it("takes one of open, copy or run and never two", () => {
        assert.match(Pushed.readRow({ tool: "a", id: "b", title: "T", open: "https://x.org", copy: "y" }, NOW).error, /one of/);
        assert.strictEqual(row({ copy: "hello" }).copy, "hello");
        assert.deepStrictEqual(row({ run: ["kitty", "-e", "journalctl", "-fu", "deploy"] }).run, ["kitty", "-e", "journalctl", "-fu", "deploy"]);
    });

    test.it("refuses links it cannot open safely and commands that start with a flag", () => {
        assert.match(Pushed.readRow({ tool: "a", id: "b", title: "T", open: "javascript:alert(1)" }, NOW).error, /javascript: link/);
        assert.match(Pushed.readRow({ tool: "a", id: "b", title: "T", open: "--help" }, NOW).error, /starting with -/);
        assert.match(Pushed.readRow({ tool: "a", id: "b", title: "T", open: "notes.txt" }, NOW).error, /not absolute/);
        assert.strictEqual(row({ open: "/home/me/log.txt" }).open, "/home/me/log.txt");
        assert.match(Pushed.readRow({ tool: "a", id: "b", title: "T", run: "rm -rf ~" }, NOW).error, /list of strings/);
        assert.match(Pushed.readRow({ tool: "a", id: "b", title: "T", run: ["-x"] }, NOW).error, /program/);
    });

    test.it("turns a ttl in seconds into an expiry, and none into a row that stays", () => {
        assert.strictEqual(row({ ttl: 600 }).expires, NOW + 600_000);
        assert.strictEqual(row({}).expires, 0);
        assert.match(Pushed.readRow({ tool: "a", id: "b", title: "T", ttl: -1 }, NOW).error, /ttl/);
    });

    test.it("replaces a row with the same tool and id, and keeps other tools apart", () => {
        let store = Pushed.added(Pushed.empty(), row({ title: "First" }));
        store = Pushed.added(store, row({ title: "Second" }));
        store = Pushed.added(store, row({ tool: "mail", id: "inbox", title: "3 new mails" }));
        assert.deepStrictEqual(Pushed.rowsOf(store).map(r => `${r.tool}/${r.id}/${r.title}`), ["deploy/failed/Second", "mail/inbox/3 new mails"]);
        assert.deepStrictEqual(Pushed.rowsOf(store, "mail").map(r => r.id), ["inbox"]);
    });

    test.it("keeps the newest fifty rows of a tool", () => {
        let store = Pushed.empty();
        for (let i = 0; i < 55; i++)
            store = Pushed.added(store, row({ id: `r${i}` }));
        const ids = Pushed.rowsOf(store).map(r => r.id);
        assert.strictEqual(ids.length, 50);
        assert.strictEqual(ids[0], "r5");
    });

    test.it("removes one row, or every row of a tool, and counts them", () => {
        let store = Pushed.added(Pushed.added(Pushed.empty(), row({ id: "a" })), row({ id: "b" }));
        const one = Pushed.removed(store, "deploy", "a");
        assert.deepStrictEqual([one.count, Pushed.rowsOf(one.store).map(r => r.id)], [1, ["b"]]);
        const all = Pushed.removed(store, "deploy", "");
        assert.deepStrictEqual([all.count, Object.keys(all.store.tools)], [2, []]);
        assert.strictEqual(Pushed.removed(store, "nobody", "").count, 0);
    });

    test.it("drops rows once they expire and says when the next one does", () => {
        let store = Pushed.added(Pushed.empty(), row({ id: "soon", ttl: 60 }));
        store = Pushed.added(store, row({ id: "later", ttl: 600 }));
        store = Pushed.added(store, row({ id: "kept" }));
        assert.strictEqual(Pushed.nextExpiry(store), NOW + 60_000);
        const after = Pushed.live(store, NOW + 61_000);
        assert.deepStrictEqual(Pushed.rowsOf(after).map(r => r.id), ["later", "kept"]);
        assert.strictEqual(Pushed.live(after, NOW + 61_000), after);
    });

    test.it("reads its file back, and starts empty from a damaged one", () => {
        let store = Pushed.added(Pushed.empty(), row({ id: "a", ttl: 60 }));
        store = Pushed.added(store, row({ id: "b", run: ["notify-send", "hi"] }));
        const back = Pushed.readStore(JSON.stringify(store), NOW + 1000);
        assert.deepStrictEqual(Pushed.rowsOf(back), Pushed.rowsOf(store));
        assert.deepStrictEqual(Pushed.rowsOf(Pushed.readStore(JSON.stringify(store), NOW + 61_000)).map(r => r.id), ["b"]);
        assert.deepStrictEqual(Pushed.readStore("{oops", NOW), Pushed.empty());
        assert.deepStrictEqual(Pushed.readStore('{"tools":{"x":[{"id":"bad id","title":"T"}]}}', NOW), Pushed.empty());
    });

    test.it("ranks a title match over a keyword match over the tool name", () => {
        const place = (label, typed) => Ranking.place(label, typed);
        const byTitle = Pushed.scoreOf(row({ title: "Logs" }), "logs", place);
        const byKeyword = Pushed.scoreOf(row({ title: "Failed", keywords: ["logs"] }), "logs", place);
        const byTool = Pushed.scoreOf(row({ tool: "logs", title: "Failed" }), "logs", place);
        assert.ok(byTitle > byKeyword, `${byTitle} > ${byKeyword}`);
        assert.ok(byKeyword >= byTool, `${byKeyword} >= ${byTool}`);
        assert.ok(Pushed.scoreOf(row({}), "zebra", place) <= 0);
    });

    test.it("draws a named icon, an emoji or a picture, and picks one from what Enter does", () => {
        assert.deepStrictEqual(Pushed.iconOf(row({ icon: "rocket_launch" })), { name: "rocket_launch" });
        assert.deepStrictEqual(Pushed.iconOf(row({ icon: "🚀" })), { glyph: "🚀" });
        assert.deepStrictEqual(Pushed.iconOf(row({ icon: "/usr/share/icons/x.png" })), { file: "/usr/share/icons/x.png" });
        assert.deepStrictEqual(Pushed.iconOf(row({ copy: "x" })), { name: "content_copy" });
        assert.deepStrictEqual(Pushed.iconOf(row({})), { name: "push_pin" });
    });
});
