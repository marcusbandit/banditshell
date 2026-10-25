const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Calculation = lib("services/calculation.js", ["looksLikeCalculation", "qalcExpression", "readQalc"]);
const Search = lib("modules/launcher/search.js", ["pathQuery", "shortPath", "pathRows", "fileRows", "urlOf", "webSearchUrl", "arrange", "nextPickable", "matchesNothing"]);
const Ranking = lib("services/ranking.js", ["place"]);

test.describe("looksLikeCalculation", () => {
    test.it("takes sums, conversions and functions", () => {
        for (const t of ["5 km to miles", "2^10", "sqrt(2)", "today + 3 weeks", "80 * 20%", "5!", "100 usd to nok", "(1+2)", "-3 + 4", "0xff"])
            assert.ok(Calculation.looksLikeCalculation(t), t);
    });

    test.it("leaves app names and half-typed sums alone", () => {
        for (const t of ["firefox", "firefox 2", "steam", "now", "1 +", "2 *", "", "   "])
            assert.ok(!Calculation.looksLikeCalculation(t), t);
    });

    test.it("lets = force anything through", () => {
        assert.ok(Calculation.looksLikeCalculation("=now"));
        assert.ok(!Calculation.looksLikeCalculation("="));
    });
});

test.describe("qalcExpression", () => {
    test.it("asks for one unit instead of mixed units", () => {
        assert.strictEqual(Calculation.qalcExpression("5 km to miles"), "5 km to -miles");
        assert.strictEqual(Calculation.qalcExpression("150 min to h"), "150 min to -h");
        assert.strictEqual(Calculation.qalcExpression("10 °C → °F"), "10 °C → -°F");
    });

    test.it("keeps base and time conversions as they are", () => {
        assert.strictEqual(Calculation.qalcExpression("255 to hex"), "255 to hex");
        assert.strictEqual(Calculation.qalcExpression("now to utc"), "now to utc");
        assert.strictEqual(Calculation.qalcExpression("5 km to +miles"), "5 km to +miles");
    });

    test.it("drops the forcing =", () => {
        assert.strictEqual(Calculation.qalcExpression("= now"), "now");
    });
});

test.describe("readQalc", () => {
    test.it("reads the one answer line and unquotes dates", () => {
        assert.strictEqual(Calculation.readQalc("3.106855961 mi\n", "5 km to miles"), "3.106855961 mi");
        assert.strictEqual(Calculation.readQalc("\"2026-11-05\"\n", "today + 3 weeks"), "2026-11-05");
    });

    test.it("refuses unit soup, unevaluated functions and echoes", () => {
        assert.strictEqual(Calculation.readQalc("1E−12 × if(y) × B·t·s", "spotify 2"), "");
        assert.strictEqual(Calculation.readQalc("rem(20, 1 B)", "20% of 80"), "");
        assert.strictEqual(Calculation.readQalc("1 / 0", "1/0"), "");
        assert.strictEqual(Calculation.readQalc("error: bad\n2", "x"), "2");
        assert.strictEqual(Calculation.readQalc("", "1+1"), "");
    });
});

test.describe("paths", () => {
    test.it("splits a typed path into folder and the name being typed", () => {
        assert.deepStrictEqual(Search.pathQuery("~/Doc", "/home/u"), { dir: "/home/u/", stem: "Doc" });
        assert.deepStrictEqual(Search.pathQuery("~", "/home/u"), { dir: "/home/u/", stem: "" });
        assert.deepStrictEqual(Search.pathQuery("/etc/pa", "/home/u"), { dir: "/etc/", stem: "pa" });
        assert.deepStrictEqual(Search.pathQuery("/", "/home/u"), { dir: "/", stem: "" });
        assert.strictEqual(Search.pathQuery("firefox", "/home/u"), null);
        assert.strictEqual(Search.pathQuery("~user", "/home/u"), null);
    });

    test.it("writes home as ~", () => {
        assert.strictEqual(Search.shortPath("/home/u/Documents", "/home/u"), "~/Documents");
        assert.strictEqual(Search.shortPath("/home/user2/x", "/home/u"), "/home/user2/x");
    });

    test.it("lists matches by prefix first, folders first, hidden only when asked", () => {
        const entries = [
            { name: "notes.md", kind: "file", class: "text", hidden: false },
            { name: "Documents", kind: "dir", class: "directory", hidden: false },
            { name: "docs.txt", kind: "file", class: "text", hidden: false },
            { name: "my-docs", kind: "dir", class: "directory", hidden: false },
            { name: ".docker", kind: "dir", class: "directory", hidden: true }
        ];
        assert.deepStrictEqual(Search.pathRows(entries, { dir: "/h/", stem: "doc" }, "off", "/h").map(r => r.name), ["Documents", "docs.txt", "my-docs"]);
        assert.deepStrictEqual(Search.pathRows(entries, { dir: "/h/", stem: ".doc" }, "off", "/h").map(r => r.path), ["/h/.docker"]);
        assert.strictEqual(Search.pathRows(entries, { dir: "/h/", stem: "" }, "off", "/h").length, 4);
        assert.strictEqual(Search.pathRows(entries, { dir: "/h/", stem: "" }, "all", "/h").length, 5);
    });

    test.it("shows .config in home when that is the hidden-files choice", () => {
        const home = [{ name: ".config", kind: "dir", hidden: true }, { name: ".local", kind: "dir", hidden: true }, { name: "Music", kind: "dir", hidden: false }];
        assert.deepStrictEqual(Search.pathRows(home, { dir: "/h/", stem: "" }, ".config", "/h").map(r => r.name), [".config", "Music"]);
        assert.deepStrictEqual(Search.pathRows(home, { dir: "/x/", stem: "" }, ".config", "/h").map(r => r.name), ["Music"]);
    });
});

test.describe("fileRows", () => {
    test.it("ranks fd output by how the name matches, then by depth", () => {
        const lines = ["/h/a/b/c/notes/", "/h/notes.md", "/h/x/old-notes.txt", "/h/x/y/notes.md", ""];
        const rows = Search.fileRows(lines, "notes", Ranking.place);
        assert.deepStrictEqual(rows.map(r => r.path), ["/h/a/b/c/notes", "/h/notes.md", "/h/x/y/notes.md", "/h/x/old-notes.txt"]);
        assert.ok(rows[0].dir && !rows[1].dir);
    });

    test.it("ranks a path search by the end of the path, the folder itself first", () => {
        const lines = ["/h/.config/hypr/lua/binds.lua", "/h/.config/hypr/lua/", "/h/.config/hypr/lua/rules.lua", "/h/.config/nvim/lua/"];
        const rows = Search.fileRows(lines, "hypr/lua", Ranking.place);
        assert.deepStrictEqual(rows.map(r => r.path), ["/h/.config/hypr/lua", "/h/.config/hypr/lua/binds.lua", "/h/.config/hypr/lua/rules.lua"]);
        assert.ok(rows[0].score > rows[1].score);
        assert.strictEqual(Search.fileRows(lines, "hypr/lu", Ranking.place)[0].path, "/h/.config/hypr/lua");
    });
});

test.describe("urlOf", () => {
    test.it("knows links when it sees them", () => {
        assert.strictEqual(Search.urlOf("github.com/marcusbandit"), "https://github.com/marcusbandit");
        assert.strictEqual(Search.urlOf("https://example.org/a?b=c"), "https://example.org/a?b=c");
        assert.strictEqual(Search.urlOf("localhost:8080"), "http://localhost:8080");
        assert.strictEqual(Search.urlOf("www.example.zz"), "https://www.example.zz");
    });

    test.it("does not mistake file names and sentences for links", () => {
        for (const t of ["notes.txt", "shell.qml", "5.5", "hello world", "firefox", ""])
            assert.strictEqual(Search.urlOf(t), "", t);
    });

    test.it("fills the search template", () => {
        assert.strictEqual(Search.webSearchUrl("https://duckduckgo.com/?q=%s", " rust & qml "), "https://duckduckgo.com/?q=rust%20%26%20qml");
    });
});

test.describe("arrange", () => {
    const groups = [
        { key: "apps", title: "Apps", items: [{ key: "a1", score: 3 }, { key: "a2", score: 1 }, { key: "a3", score: 1 }] },
        { key: "settings", title: "Settings", items: [{ key: "s1", score: 4 }] },
        { key: "files", title: "Files", items: [] },
        { key: "web", title: "Web", items: [{ key: "w", score: -Infinity }] }
    ];

    test.it("puts the best-matching section first and caps each section", () => {
        const rows = Search.arrange(groups, { apps: 2 });
        assert.deepStrictEqual(rows.map(r => r.key), ["header:settings", "s1", "header:apps", "a1", "a2", "header:web", "w"]);
    });

    test.it("keeps the given order on ties and drops the header when one section is left", () => {
        const tie = [{ key: "apps", title: "Apps", items: [{ key: "a", score: 2 }] }, { key: "settings", title: "Settings", items: [{ key: "s", score: 2 }] }];
        assert.deepStrictEqual(Search.arrange(tie, {}).map(r => r.key), ["header:apps", "a", "header:settings", "s"]);
        assert.deepStrictEqual(Search.arrange([groups[0]], {}).map(r => r.key), ["a1", "a2", "a3"]);
    });

    test.it("keeps an empty section that carries a note, and names the note in its header", () => {
        const cut = { key: "contents", title: "Inside files", note: "stopped after 2 s", items: [] };
        const rows = Search.arrange([groups[0], cut], { apps: 2 });
        assert.deepStrictEqual(rows.map(r => r.key), ["header:apps", "a1", "a2", "header:contents"]);
        assert.strictEqual(rows[3].title, "Inside files · stopped after 2 s");
        assert.strictEqual(rows[3].header, true);
    });

    test.it("adds the note to a section that has rows, and leaves an unnoted one alone", () => {
        const hit = { key: "contents", title: "Inside files", note: "stopped after 2 s", items: [{ key: "c", score: 1 }] };
        const rows = Search.arrange([groups[0], hit], {});
        assert.strictEqual(rows.find(r => r.key === "header:contents").title, "Inside files · stopped after 2 s");
        assert.strictEqual(rows.find(r => r.key === "header:apps").title, "Apps");
    });

    test.it("returns nothing when the only section is a note with no rows", () => {
        assert.deepStrictEqual(Search.arrange([{ key: "contents", title: "Inside files", note: "stopped after 2 s", items: [] }], {}), []);
    });

    test.it("steps over headers, wrapping around", () => {
        const rows = Search.arrange(groups, { apps: 2 });
        assert.strictEqual(Search.nextPickable(rows, 0, 1), 1);
        assert.strictEqual(Search.nextPickable(rows, 2, 1), 3);
        assert.strictEqual(Search.nextPickable(rows, 5, 1), 6);
        assert.strictEqual(Search.nextPickable(rows, 7, 1), 1);
        assert.strictEqual(Search.nextPickable(rows, 0, -1), 6);
        assert.strictEqual(Search.nextPickable([{ header: true }], 0, 1), -1);
    });
});

const Currency = lib("services/currency.js", ["parse", "convert", "total", "places", "readEcb", "codeOf"]);
const Calc = lib("services/calculation.js", ["mathOnly", "firm", "lenient"]);

test.describe("currency", () => {
    const known = ["EUR", "USD", "DKK", "GBP", "SEK", "NOK", "JPY"];
    const evaluate = t => /^[\d+\-*/() .]+$/.test(t) ? Function(`"use strict"; return (${t});`)() : null;
    const one = (text, home) => {
        const got = Currency.parse(text, known, home || "DKK", evaluate);
        return got && got.terms.length === 1 ? { amount: got.terms[0].amount, from: got.terms[0].from, to: got.to } : got;
    };

    test.it("reads an amount with a currency and aims it at the home currency", () => {
        assert.deepStrictEqual(one("5 eur"), { amount: 5, from: "EUR", to: "DKK" });
        assert.deepStrictEqual(one("5eur"), { amount: 5, from: "EUR", to: "DKK" });
        assert.deepStrictEqual(one("€5"), { amount: 5, from: "EUR", to: "DKK" });
        assert.deepStrictEqual(one("12,50 $"), { amount: 12.5, from: "USD", to: "DKK" });
        assert.deepStrictEqual(one("3 euros"), { amount: 3, from: "EUR", to: "DKK" });
    });

    test.it("takes an explicit target either way round", () => {
        assert.deepStrictEqual(one("5 eur to dkk"), { amount: 5, from: "EUR", to: "DKK" });
        assert.deepStrictEqual(one("5 DKK to EUR"), { amount: 5, from: "DKK", to: "EUR" });
        assert.deepStrictEqual(one("100 usd in eur"), { amount: 100, from: "USD", to: "EUR" });
        assert.deepStrictEqual(one("100usd->gbp"), { amount: 100, from: "USD", to: "GBP" });
        assert.deepStrictEqual(one("50 kr to eur"), { amount: 50, from: "DKK", to: "EUR" });
    });

    test.it("does the sum in the amount first", () => {
        assert.deepStrictEqual(one("50+30 jpy"), { amount: 80, from: "JPY", to: "DKK" });
        assert.deepStrictEqual(one("(50+30)*2 eur to usd"), { amount: 160, from: "EUR", to: "USD" });
        assert.deepStrictEqual(one("€10*3"), { amount: 30, from: "EUR", to: "DKK" });
        assert.deepStrictEqual(one("50+30 dkk"), { amount: 80, from: "DKK", to: "DKK" });
    });

    test.it("adds amounts in different currencies", () => {
        const got = Currency.parse("50 eur + 30 usd - 10 eur", known, "DKK", evaluate);
        assert.deepStrictEqual(got.terms, [{ amount: 50, from: "EUR" }, { amount: 30, from: "USD" }, { amount: -10, from: "EUR" }]);
        assert.strictEqual(got.to, "DKK");
        const rates = { USD: 1.1, DKK: 7.46 };
        assert.ok(Math.abs(Currency.total({ terms: [{ amount: 10, from: "EUR" }, { amount: 11, from: "USD" }], to: "EUR" }, rates) - 20) < 1e-9);
    });

    test.it("leaves things that are not money alone", () => {
        for (const t of ["5", "5 km", "5 dkk", "firefox", "5 km to miles", "eur", "5 abc", "5 eur to xyz", "€5 usd", "50 eur + 30", "5+5"])
            assert.strictEqual(Currency.parse(t, known, "DKK", evaluate), null, t);
    });

    test.it("converts through the euro", () => {
        const rates = { USD: 1.1, DKK: 7.46 };
        assert.ok(Math.abs(Currency.convert(5, "EUR", "DKK", rates) - 37.3) < 1e-9);
        assert.ok(Math.abs(Currency.convert(11, "USD", "EUR", rates) - 10) < 1e-9);
        assert.ok(Math.abs(Currency.convert(1.1, "USD", "DKK", rates) - 7.46) < 1e-9);
        assert.ok(isNaN(Currency.convert(1, "XXX", "DKK", rates)));
        assert.strictEqual(Currency.places(37.3), 2);
        assert.strictEqual(Currency.places(0.00512), 4);
    });

    test.it("reads the ECB daily file", () => {
        const xml = "<Cube><Cube time='2026-10-15'><Cube currency='USD' rate='1.1598'/><Cube currency='DKK' rate='7.4613'/></Cube></Cube>";
        assert.deepStrictEqual(Currency.readEcb(xml), { date: "2026-10-15", rates: { USD: 1.1598, DKK: 7.4613 } });
        assert.strictEqual(Currency.readEcb("<html>nope</html>"), null);
    });
});

test.describe("lenient maths", () => {
    const evaluate = t => {
        if (!/^[\d+\-*/() .]+$/.test(t))
            return null;
        try {
            const v = Function(`"use strict"; return (${t});`)();
            return typeof v === "number" && isFinite(v) ? { value: v } : null;
        } catch (e) {
            return null;
        }
    };

    test.it("goes back to the last part that makes sense", () => {
        assert.strictEqual(Calc.lenient("5+", evaluate).value, 5);
        assert.strictEqual(Calc.lenient("5+5", evaluate).value, 10);
        assert.strictEqual(Calc.lenient("5+5-", evaluate).value, 10);
        assert.strictEqual(Calc.lenient("5+(", evaluate).value, 5);
        assert.strictEqual(Calc.lenient("(5+3", evaluate).value, 8);
        assert.strictEqual(Calc.lenient("2*(3+4", evaluate).value, 14);
        assert.strictEqual(Calc.lenient("+", evaluate), null);
    });

    test.it("knows math-only text and when it is clearly a sum", () => {
        assert.ok(Calc.mathOnly("5+5"));
        assert.ok(Calc.mathOnly("(5 x 3"));
        assert.ok(Calc.mathOnly("5"));
        assert.ok(!Calc.mathOnly("5 eur"));
        assert.ok(!Calc.mathOnly("firefox"));
        assert.ok(!Calc.mathOnly("+"));
        assert.ok(Calc.firm("5+"));
        assert.ok(!Calc.firm("5"));
        assert.ok(!Calc.firm("-5"));
    });
});

test.describe("program", () => {
    const Prog = lib("services/calculation.js", ["program"]);
    const evaluate = t => {
        const js = t.replace(/×/g, "*").replace(/÷/g, "/").replace(/−/g, "-");
        if (!/^[\d+\-*/() .]+$/.test(js))
            return null;
        try {
            const v = Function(`"use strict"; return (${js});`)();
            return typeof v === "number" && isFinite(v) ? { value: v } : null;
        } catch (e) {
            return null;
        }
    };
    const format = n => String(parseFloat(n.toPrecision(12)));
    const run = t => Prog.program(t, evaluate, format)?.text ?? null;

    test.it("keeps names between statements", () => {
        assert.strictEqual(run("x=5; x+2"), "7");
        assert.strictEqual(run("x = 5; y = x*2; y+1"), "11");
        assert.strictEqual(run("x=5; 2x"), "10");
        assert.strictEqual(run("r=2; pi*r*r"), "12.5663706144");
        assert.strictEqual(run("x=5;"), "x = 5");
        assert.strictEqual(run("x=5; x+"), "5");
    });

    test.it("solves a line for the one unknown", () => {
        assert.strictEqual(run("2x+3=7"), "x = 2");
        assert.strictEqual(run("a=3; a*y = 12"), "y = 4");
        assert.strictEqual(run("x*x=4"), null);
    });

    test.it("says whether two sides are equal", () => {
        assert.strictEqual(run("5=5"), "true");
        assert.strictEqual(run("2+2=5"), "false");
    });

    test.it("leaves ordinary text alone", () => {
        for (const t of ["firefox", "5+5", "=now", "x+y=3", "x=", "a=b=c", "x==5"])
            assert.strictEqual(run(t), null, t);
    });
});

test.describe("matchesNothing", () => {
    test.it("leaves room for a guess only when the web and terminal rows are all there is", () => {
        assert.ok(Search.matchesNothing([]));
        assert.ok(Search.matchesNothing([{ header: true, key: "header:fallbacks" }, { kind: "fallback", key: "fallback:web" }]));
        assert.ok(!Search.matchesNothing([{ kind: "app", key: "app:firefox" }, { kind: "fallback", key: "fallback:web" }]));
        assert.ok(!Search.matchesNothing([{ kind: "file", key: "file:/home/a/frefiox.txt" }]));
    });
});
