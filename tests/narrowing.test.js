const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Narrowing = lib("services/narrowing.js", ["narrows", "grepNarrows", "keepNamed", "pathOf"]);
const Ranking = lib("services/ranking.js", ["place", "WORD", "PREFIX", "NONE"]);

test.describe("narrowing a search instead of running it again", () => {
    test.it("knows a longer query only finds what the shorter one found", () => {
        assert.ok(Narrowing.narrows("fir", "fire"));
        assert.ok(Narrowing.narrows("fir", "Firefox"));
        assert.ok(Narrowing.narrows("ref", "firefox"));
        assert.ok(!Narrowing.narrows("fire", "fir"));
        assert.ok(!Narrowing.narrows("", "fire"));
        assert.ok(!Narrowing.narrows("fox", "fire"));
    });

    test.it("follows ripgrep's smart case", () => {
        assert.ok(Narrowing.grepNarrows("todo", "todo list"));
        assert.ok(Narrowing.grepNarrows("todo", "TODO list"));
        assert.ok(Narrowing.grepNarrows("TODO", "TODO list"));
        assert.ok(!Narrowing.grepNarrows("TODO", "todo list"));
    });

    test.it("keeps the paths whose name still matches, like fd does", () => {
        const lines = ["/home/me/fire/notes.md", "/home/me/firefox.desktop", "/home/me/Firewall/", "/home/me/campfire.txt"];
        assert.deepStrictEqual(Narrowing.keepNamed(lines, "firef"), ["/home/me/firefox.desktop"]);
        assert.deepStrictEqual(Narrowing.keepNamed(lines, "FIRE"), ["/home/me/firefox.desktop", "/home/me/Firewall/", "/home/me/campfire.txt"]);
    });

    test.it("never narrows between a name search and a path search", () => {
        assert.ok(!Narrowing.narrows("hypr", "hypr/"));
        assert.ok(!Narrowing.narrows("hypr/lua", "lua"));
        assert.ok(Narrowing.narrows("hypr/l", "hypr/lua"));
    });

    test.it("matches a path search against the whole path, like fd --full-path", () => {
        const lines = ["/home/me/.config/hypr/lua/", "/home/me/.config/hypr/lua/binds.lua", "/home/me/hypr-notes/lua.md", "/home/me/.config/nvim/lua/"];
        assert.deepStrictEqual(Narrowing.keepNamed(lines, "hypr/lua"), ["/home/me/.config/hypr/lua/", "/home/me/.config/hypr/lua/binds.lua"]);
    });

    test.it("reads the file out of a ripgrep hit", () => {
        assert.strictEqual(Narrowing.pathOf("/home/me/a.md:12:time: 10:30"), "/home/me/a.md");
        assert.strictEqual(Narrowing.pathOf("not a hit"), "");
    });
});

test.describe("ranking", () => {
    test.it("still finds word starts after the pattern is cached, for each new word", () => {
        assert.strictEqual(Ranking.place("Mozilla Firefox", "fire"), Ranking.WORD);
        assert.strictEqual(Ranking.place("Zen Browser", "brow"), Ranking.WORD);
        assert.strictEqual(Ranking.place("Firewall", "fire"), Ranking.PREFIX);
        assert.strictEqual(Ranking.place("a.b (c)", "(c"), Ranking.ANYWHERE ?? 1);
    });
});
