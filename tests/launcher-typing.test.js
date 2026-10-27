const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Table = lib("services/emoji-table.js", ["TABLE", "GROUPS", "FIRST_SYMBOL_GROUP"]);
const Emoji = lib("services/emoji.js", ["parse", "index", "ask", "search", "toned", "modifierFor", "remember", "codeOf", "TONES", "POPULAR"]);
const Snippets = lib("services/snippets.js", ["ask", "find", "expand", "preview", "previewText", "suggestName", "newId", "cleanKeyword", "withSnippet", "withoutSnippet", "keywordHolder"]);
const Quicklinks = lib("services/quicklinks.js", ["KEYWORD_SCORE", "match", "resolve", "hostOf", "takes", "cleanKeyword", "withLink", "keywordHolder", "problem", "prefixes"]);
const ClipboardSearch = lib("services/clipboard-search.js", ["ask", "index", "find", "firstLine"]);
const { spawnSync } = require("node:child_process");
const os = require("node:os");

const APP_FLOOR = 0.5;

const ALL = Emoji.parse(Table.TABLE, Table.GROUPS, Table.FIRST_SYMBOL_GROUP);
const BY_CHAR = Emoji.index(ALL);
const first = (query, used) => {
    const asked = Emoji.ask(query);
    return Emoji.search(ALL, BY_CHAR, asked.term, used || {}, asked.explicit, 5).map(e => e.char);
};

test.describe("emoji data", () => {
    test.it("parses every row into a character, a name and a group", () => {
        assert.ok(ALL.length > 2000);
        for (const line of Table.TABLE)
            assert.strictEqual(line.split("|").length, 5, line);
        for (const entry of ALL) {
            assert.ok(entry.char, `row ${entry.index} has a character`);
            assert.ok(entry.name, `${entry.char} has a name`);
            assert.ok(entry.group, `${entry.char} has a group`);
        }
    });

    test.it("holds no en or em dash anywhere", () => {
        const text = fs.readFileSync(path.join(ROOT, "services/emoji-table.js"), "utf8");
        assert.ok(!text.includes(String.fromCharCode(0x2013)) && !text.includes(String.fromCharCode(0x2014)));
    });

    test.it("lists each character once and knows every popular one", () => {
        assert.strictEqual(Object.keys(BY_CHAR).length, ALL.length);
        for (const char of Emoji.POPULAR)
            assert.ok(BY_CHAR[char], `${char} is in the table`);
    });

    test.it("keeps symbols as plain text, not emoji presentation", () => {
        assert.strictEqual(BY_CHAR["©"].symbol, true);
        assert.strictEqual(BY_CHAR["©️"], undefined);
        assert.strictEqual(BY_CHAR["→"].group, "Arrows");
        assert.strictEqual(BY_CHAR["😀"].symbol, false);
    });
});

test.describe("emoji search", () => {
    test.it("reads emoji, symbol and colon asks as explicit", () => {
        assert.deepStrictEqual(Emoji.ask("emoji heart"), { term: "heart", explicit: true });
        assert.deepStrictEqual(Emoji.ask("symbols arrow"), { term: "arrow", explicit: true });
        assert.deepStrictEqual(Emoji.ask(":smile"), { term: "smile", explicit: true });
        assert.deepStrictEqual(Emoji.ask(":"), { term: "", explicit: true });
        assert.deepStrictEqual(Emoji.ask(":D"), { term: ":D", explicit: false });
        assert.deepStrictEqual(Emoji.ask("thumbs up"), { term: "thumbs up", explicit: false });
    });

    test.it("puts the obvious one first", () => {
        assert.strictEqual(first("heart")[0], "❤️");
        assert.strictEqual(first("thumbs up")[0], "👍");
        assert.strictEqual(first(":smile")[0], "😄");
        assert.strictEqual(first(":joy")[0], "😂");
        assert.strictEqual(first("fire")[0], "🔥");
        assert.strictEqual(first("party")[0], "🎉");
        assert.strictEqual(first("flag denmark")[0], "🇩🇰");
    });

    test.it("finds symbols by name, alias and spelling", () => {
        assert.strictEqual(first("deg")[0], "°");
        assert.strictEqual(first("copyright")[0], "©");
        assert.strictEqual(first("->")[0], "→");
        assert.strictEqual(first("1/2")[0], "½");
        assert.strictEqual(first("emoji tm")[0], "™");
        assert.ok(first("emoji alpha").includes("α"));
        assert.ok(first("euro").includes("€"));
    });

    test.it("reads emoticons as they are typed", () => {
        assert.strictEqual(first(":)")[0], "🙂");
        assert.strictEqual(first(":D")[0], "😀");
        assert.strictEqual(first("<3")[0], "❤️");
        assert.strictEqual(first("+1")[0], "👍");
    });

    test.it("stays quiet on short or unrelated plain words", () => {
        assert.deepStrictEqual(first("pi"), []);
        assert.deepStrictEqual(first("firefox"), []);
        assert.deepStrictEqual(first("x"), []);
        assert.ok(first("emoji pi").includes("π"));
    });

    test.it("ranks what was used recently first", () => {
        const used = Emoji.remember({}, "🐱", 1000);
        assert.strictEqual(first("cat")[0], "🐈");
        assert.strictEqual(first("cat", used)[0], "🐱");
    });

    test.it("opens an empty ask on recent ones, then popular ones", () => {
        const used = Emoji.remember(Emoji.remember({}, "🦊", 1), "🐙", 2);
        const shown = first("emoji", used);
        assert.deepStrictEqual(shown.slice(0, 2), ["🐙", "🦊"]);
        assert.strictEqual(shown[2], Emoji.POPULAR[0]);
    });

    test.it("counts uses and keeps the list short", () => {
        let used = {};
        for (let i = 0; i < 80; i++)
            used = Emoji.remember(used, String.fromCodePoint(0x1F600 + i), i);
        used = Emoji.remember(used, "😀", 100);
        assert.strictEqual(Object.keys(used).length, 60);
        assert.strictEqual(used["😀"].count, 1);
        assert.strictEqual(Emoji.remember(used, "😀", 101)["😀"].count, 2);
    });
});

test.describe("skin tones", () => {
    test.it("puts the modifier after the person and drops the presentation selector", () => {
        const medium = Emoji.modifierFor("medium");
        assert.strictEqual(Emoji.toned(BY_CHAR["👍"], medium), "👍🏽");
        assert.strictEqual(Emoji.toned(BY_CHAR["✌️"], Emoji.modifierFor("light")), "✌🏻");
        assert.strictEqual(Emoji.toned(BY_CHAR["🧑‍🤝‍🧑"], Emoji.modifierFor("dark")), "🧑🏿‍🤝‍🧑🏿");
        assert.strictEqual(Emoji.toned(BY_CHAR["🏃‍♀️"], medium), "🏃🏽‍♀️");
    });

    test.it("leaves untoned emoji and the default tone alone", () => {
        assert.strictEqual(Emoji.toned(BY_CHAR["🔥"], Emoji.modifierFor("dark")), "🔥");
        assert.strictEqual(Emoji.toned(BY_CHAR["👍"], Emoji.modifierFor("none")), "👍");
        assert.strictEqual(Emoji.modifierFor("nonsense"), "");
    });

    test.it("names code points the way Unicode writes them", () => {
        assert.strictEqual(Emoji.codeOf("→"), "U+2192");
        assert.strictEqual(Emoji.codeOf("❤️"), "U+2764");
        assert.strictEqual(Emoji.codeOf("👍"), "U+1F44D");
    });
});

test.describe("snippets", () => {
    const LIST = [
        { id: "a", name: "Sign-off", keyword: ";sig", text: "Kind regards,\nMarcus" },
        { id: "b", name: "Address", keyword: "", text: "Main Street 1" },
        { id: "c", name: "Bug report", keyword: "bug", text: "Steps: {cursor}\nSeen on {date}" }
    ];

    test.it("reads snippet asks", () => {
        assert.deepStrictEqual(Snippets.ask("snippet sig"), { term: "sig", explicit: true });
        assert.deepStrictEqual(Snippets.ask("snip"), { term: "", explicit: true });
        assert.deepStrictEqual(Snippets.ask("snippets"), { term: "", explicit: true });
        assert.deepStrictEqual(Snippets.ask("snipe"), { term: "snipe", explicit: false });
    });

    test.it("puts an exact keyword above everything", () => {
        const found = Snippets.find(LIST, ";sig", false);
        assert.strictEqual(found[0].snippet.id, "a");
        assert.strictEqual(found[0].score, Infinity);
        assert.strictEqual(found[0].keyed, true);
    });

    test.it("ranks plain matches below apps unless the keyword is exact", () => {
        for (const query of ["sign", "address", "addr", "bug rep"])
            for (const found of Snippets.find(LIST, query, false))
                assert.ok(found.score < APP_FLOOR, `${query}: ${found.snippet.name} scored ${found.score}`);
        assert.strictEqual(Snippets.find(LIST, "bug", false)[0].score, Infinity);
        const exact = Snippets.find(LIST, "address", false)[0].score;
        const prefix = Snippets.find(LIST, "addr", false)[0].score;
        assert.ok(exact > prefix);
    });

    test.it("shows the clipboard placeholder in previews, never what was copied", () => {
        const shown = Snippets.previewText("Re: {clipboard} on {date}", { date: "16 Oct 2026", clipboard: "hunter2" }, 80);
        assert.strictEqual(shown, "Re: {clipboard} on 16 Oct 2026");
        assert.strictEqual(Snippets.expand("{clipboard}", { clipboard: "hunter2" }).text, "hunter2");
    });

    test.it("finds by name in plain search and by text only when asked", () => {
        assert.deepStrictEqual(Snippets.find(LIST, "addr", false).map(f => f.snippet.id), ["b"]);
        assert.deepStrictEqual(Snippets.find(LIST, "street", false), []);
        assert.deepStrictEqual(Snippets.find(LIST, "street", true).map(f => f.snippet.id), ["b"]);
        assert.strictEqual(Snippets.find(LIST, "", true).length, 3);
        assert.strictEqual(Snippets.find(LIST, "", false).length, 0);
    });

    test.it("fills placeholders and counts the way back to the cursor", () => {
        const done = Snippets.expand("Hi {clipboard}, see you {DATE} at {time}.{cursor} Bye", {
            date: "16 Oct 2026",
            time: "14:05",
            clipboard: "Ana"
        });
        assert.strictEqual(done.text, "Hi Ana, see you 16 Oct 2026 at 14:05. Bye");
        assert.strictEqual(done.back, 4);
    });

    test.it("counts characters beyond the basic plane once", () => {
        assert.strictEqual(Snippets.expand("({cursor})👍", {}).back, 2);
        assert.strictEqual(Snippets.expand("no cursor", {}).back, 0);
        assert.strictEqual(Snippets.expand("{cursor}a{cursor}b", {}).text, "ab");
    });

    test.it("shortens previews and names", () => {
        assert.strictEqual(Snippets.preview("Kind regards,\n  Marcus", 80), "Kind regards, Marcus");
        assert.strictEqual(Snippets.preview("x".repeat(100), 10).length, 10);
        assert.strictEqual(Snippets.suggestName("Thanks for getting back to me so quickly today"), "Thanks for getting back");
    });

    test.it("gives new snippets an id nobody has", () => {
        const id = Snippets.newId([{ id: "s1" }], 1);
        assert.strictEqual(id, "s1-2");
        assert.strictEqual(Snippets.newId([], 36), "s10");
    });

    test.it("adds, replaces and removes without touching the rest", () => {
        const added = Snippets.withSnippet(LIST, { id: "d", name: "New", keyword: "", text: "x" });
        assert.strictEqual(added.length, 4);
        const changed = Snippets.withSnippet(added, { id: "b", name: "Home", keyword: "", text: "y" });
        assert.strictEqual(changed[1].name, "Home");
        assert.deepStrictEqual(Snippets.withoutSnippet(changed, "a").map(s => s.id), ["b", "c", "d"]);
    });

    test.it("notices a keyword another snippet has", () => {
        assert.strictEqual(Snippets.keywordHolder(LIST, "BUG", "a").id, "c");
        assert.strictEqual(Snippets.keywordHolder(LIST, "bug", "c"), null);
        assert.strictEqual(Snippets.cleanKeyword(" ;s ig "), ";sig");
    });
});

test.describe("quicklinks", () => {
    const LINKS = [
        { name: "YouTube", keyword: "yt", url: "https://www.youtube.com/results?search_query={query}" },
        { name: "GitHub", keyword: "gh", url: "https://github.com/search?q={query}" },
        { name: "Arch Wiki", keyword: "arch", url: "https://wiki.archlinux.org/index.php?search={query}" },
        { name: "Mail", keyword: "mail", url: "https://mail.example.com/" }
    ];

    test.it("matches a keyword and the words after it", () => {
        const hit = Quicklinks.match(LINKS, "yt cats playing piano");
        assert.strictEqual(hit.exact[0].link.name, "YouTube");
        assert.strictEqual(hit.exact[0].query, "cats playing piano");
        assert.strictEqual(Quicklinks.match(LINKS, "YT cats").exact.length, 1);
    });

    test.it("offers partial keywords and names for completion", () => {
        assert.deepStrictEqual(Quicklinks.match(LINKS, "ar").partial.map(p => p.link.name), ["Arch Wiki"]);
        assert.deepStrictEqual(Quicklinks.match(LINKS, "you").partial.map(p => p.link.name), ["YouTube"]);
        assert.deepStrictEqual(Quicklinks.match(LINKS, "wiki").partial.map(p => p.link.name), ["Arch Wiki"]);
        assert.strictEqual(Quicklinks.match(LINKS, "arch").exact[0].query, "");
    });

    test.it("needs two letters before a keyword prefix counts, and stays below apps", () => {
        assert.deepStrictEqual(Quicklinks.match(LINKS, "g").partial, []);
        assert.deepStrictEqual(Quicklinks.match(LINKS, "y").partial, []);
        assert.deepStrictEqual(Quicklinks.match(LINKS, "gh").partial, []);
        assert.strictEqual(Quicklinks.match(LINKS, "gh").exact.length, 1);
        assert.deepStrictEqual(Quicklinks.match(LINKS, "ma").partial.map(p => p.link.name), ["Mail"]);
        for (const query of ["ar", "you", "wiki", "ma", "gi"])
            for (const p of Quicklinks.match(LINKS, query).partial)
                assert.ok(p.score < APP_FLOOR, `${query}: ${p.link.name} scored ${p.score}`);
        assert.ok(Quicklinks.KEYWORD_SCORE <= APP_FLOOR);
    });

    test.it("ignores words after a link that takes none", () => {
        assert.strictEqual(Quicklinks.match(LINKS, "mail now").exact.length, 0);
        assert.strictEqual(Quicklinks.match(LINKS, "mail").exact.length, 1);
    });

    test.it("fills the query, encoded, or opens the site", () => {
        assert.strictEqual(Quicklinks.resolve(LINKS[0].url, "c++ & co"), "https://www.youtube.com/results?search_query=c%2B%2B%20%26%20co");
        assert.strictEqual(Quicklinks.resolve(LINKS[1].url, ""), "https://github.com/");
        assert.strictEqual(Quicklinks.resolve(LINKS[3].url, "x"), "https://mail.example.com/");
    });

    test.it("shows the host without www", () => {
        assert.strictEqual(Quicklinks.hostOf("https://www.youtube.com/results?x=1"), "youtube.com");
        assert.strictEqual(Quicklinks.hostOf("https://aur.archlinux.org/packages?K=a"), "aur.archlinux.org");
        assert.strictEqual(Quicklinks.hostOf("not a url"), "");
    });

    test.it("says what an unfinished link needs", () => {
        assert.strictEqual(Quicklinks.problem({ name: "", keyword: "x", url: "https://a.b" }), "needs a name");
        assert.strictEqual(Quicklinks.problem({ name: "A", keyword: " ", url: "https://a.b" }), "needs a keyword");
        assert.ok(Quicklinks.problem({ name: "A", keyword: "a", url: "a.b" }).startsWith("needs a full address"));
        assert.strictEqual(Quicklinks.problem({ name: "A", keyword: "a", url: "https://a.b/?q={query}" }), "");
        assert.strictEqual(Quicklinks.keywordHolder(LINKS, "GH", 0).name, "GitHub");
        assert.strictEqual(Quicklinks.keywordHolder(LINKS, "gh", 1), null);
    });

    test.it("puts each finished link's keyword on the ? page", () => {
        const rows = Quicklinks.prefixes([
            { name: "YouTube", keyword: " YT ", url: "https://youtube.com/results?q={query}" },
            { name: "Mail", keyword: "mail", url: "https://mail.example.com" },
            { name: "Half done", keyword: "", url: "https://a.b" },
            { name: "No address", keyword: "x", url: "a.b" }
        ]);
        assert.deepStrictEqual(rows.map(r => [r.section, r.word, r.label, r.about, r.icon]), [
            ["Quicklinks", "yt", "yt", "Search YouTube", "travel_explore"],
            ["Quicklinks", "mail", "mail", "Open Mail", "link"]
        ]);
    });

    test.it("puts keywords for the same address on one row", () => {
        const wiki = "https://wiki.archlinux.org/index.php?search={query}";
        const rows = Quicklinks.prefixes([
            { name: "Arch Wiki", keyword: "arch", url: wiki },
            { name: "Arch wiki again", keyword: "aw", url: ` ${wiki} ` },
            { name: "Twice", keyword: "arch", url: wiki }
        ]);
        assert.deepStrictEqual(rows.map(r => [r.word, r.label, r.also, r.about]), [["arch", "arch, aw", ["aw"], "Search Arch Wiki"]]);
    });

    test.it("the shipped defaults are all valid and distinct", () => {
        const config = fs.readFileSync(path.join(ROOT, "config/Config.qml"), "utf8");
        const start = config.indexOf("quicklinks: [");
        const end = config.indexOf("]", start);
        const defaults = new Function(`return ${config.slice(start + "quicklinks: ".length, end + 1)};`)();
        assert.ok(defaults.length >= 6);
        const keywords = defaults.map(l => Quicklinks.cleanKeyword(l.keyword));
        assert.strictEqual(new Set(keywords).size, keywords.length);
        for (const link of defaults) {
            assert.strictEqual(Quicklinks.problem(link), "", link.name);
            assert.ok(Quicklinks.takes(link), link.name);
        }
    });
});

test.describe("clipboard privacy", () => {
    test.it("leaves plain-word clipboard search off until asked for", () => {
        const config = fs.readFileSync(path.join(ROOT, "config/Config.qml"), "utf8");
        const typing = config.slice(config.indexOf("typing: {"));
        assert.match(typing, /^typing: \{\s*skinTone: "none",\s*clipboard: false,/);
    });

    const record = types => {
        const bin = fs.mkdtempSync(path.join(os.tmpdir(), "clip-record-"));
        const store = path.join(bin, "store");
        fs.writeFileSync(path.join(bin, "wl-paste"), `#!/bin/sh\ncase "$*" in\n*--list-types*) printf '%s\\n' ${types.map(t => `'${t}'`).join(" ")} ;;\n*) printf 'hunter2' ;;\nesac\n`, { mode: 0o755 });
        const run = spawnSync("bash", [path.join(ROOT, "scripts/clip-record.sh")], {
            env: { PATH: `${bin}:/usr/bin:/bin`, HOME: bin, BANDITSHELL_CLIP_STORE: store, CLIPBOARD_STATE: "data" },
            encoding: "utf8"
        });
        fs.rmSync(bin, { recursive: true, force: true });
        return JSON.parse(run.stdout.trim().split("\n").pop());
    };

    test.it("never records what a password manager marks as secret", { skip: spawnSync("sh", ["-c", "command -v jq"]).status !== 0 }, () => {
        const secret = record(["text/plain", "x-kde-passwordManagerHint"]);
        assert.strictEqual(secret.state, "sensitive");
        assert.strictEqual(secret.text, undefined);
        const plain = record(["text/plain"]);
        assert.strictEqual(plain.state, "data");
        assert.strictEqual(plain.text, "hunter2");
    });
});

test.describe("clipboard in search", () => {
    const ENTRIES = [
        { id: "1", kind: "text", text: "ssh marcus@homehub.local" },
        { id: "2", kind: "image", file: "/tmp/a.png", text: "" },
        { id: "3", kind: "url", text: "https://example.com/homework" },
        { id: "4", kind: "text", text: "Remember the milk\nand the bread" }
    ];
    const summarise = e => e.file ? "a.png" : e.text;
    const INDEX = ClipboardSearch.index(ENTRIES, summarise);

    test.it("reads clip asks", () => {
        assert.deepStrictEqual(ClipboardSearch.ask("clip home"), { term: "home", explicit: true });
        assert.deepStrictEqual(ClipboardSearch.ask("clipboard"), { term: "", explicit: true });
        assert.deepStrictEqual(ClipboardSearch.ask("clipper"), { term: "clipper", explicit: false });
    });

    test.it("lists the newest entries when asked with nothing else", () => {
        assert.deepStrictEqual(ClipboardSearch.find(INDEX, "", true, 2).map(e => e.id), ["1", "2"]);
        assert.deepStrictEqual(ClipboardSearch.find(INDEX, "", false, 2), []);
    });

    test.it("matches word starts in plain search and anything when asked", () => {
        assert.deepStrictEqual(ClipboardSearch.find(INDEX, "milk", false, 3).map(e => e.id), ["4"]);
        assert.deepStrictEqual(ClipboardSearch.find(INDEX, "ome", false, 3), []);
        assert.deepStrictEqual(ClipboardSearch.find(INDEX, "ome", true, 3).map(e => e.id), ["1", "3"]);
        assert.deepStrictEqual(ClipboardSearch.find(INDEX, "ssh", false, 3).map(e => e.id), ["1"]);
    });

    test.it("keeps pictures out of plain search and short words out entirely", () => {
        assert.deepStrictEqual(ClipboardSearch.find(INDEX, "a.png", false, 3), []);
        assert.deepStrictEqual(ClipboardSearch.find(INDEX, "a.png", true, 3).map(e => e.id), ["2"]);
        assert.deepStrictEqual(ClipboardSearch.find(INDEX, "re", false, 3), []);
    });

    test.it("shows the first line that has words", () => {
        assert.strictEqual(ClipboardSearch.firstLine("\n\n  hello   there \nsecond", 80), "hello there");
        assert.strictEqual(ClipboardSearch.firstLine("abcdefghij", 5), "abcd…");
    });
});

test.describe("emoji search while typing", () => {
    test.it("gives the same answer letter by letter as typed at once", () => {
        for (const word of ["thumbs up", "red heart", "smiling face", "fire", "->", "deg"]) {
            const fresh = lib("services/emoji.js", ["ask", "search"]);
            const once = fresh.search(ALL, BY_CHAR, fresh.ask(word).term, {}, fresh.ask(word).explicit, 8).map(e => e.char);
            let typed = [];
            for (let i = 1; i <= word.length; i++) {
                const asked = Emoji.ask(word.slice(0, i));
                typed = Emoji.search(ALL, BY_CHAR, asked.term, {}, asked.explicit, 8).map(e => e.char);
            }
            assert.deepStrictEqual(typed, once, word);
        }
    });
});
