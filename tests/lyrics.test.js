const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/lyrics.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Lyrics = new Function(src + "\nreturn { stamp, parseLrc, group, separate, fromLrc, fromSpicy, plain, lineAt, progress, wordFill, gapFill, layout, litWidth, cleanTitle, firstArtist, pick, query };")();

const close = (a, b) => Math.abs(a - b) < 1e-6;
const texts = words => words.map(w => w.text).join(" ");
const sungLines = lines => lines.filter(l => !l.gap);

test.describe("stamp", () => {
    test.it("reads minutes, seconds and fractions", () => {
        assert.ok(close(Lyrics.stamp("01:02.50"), 62.5));
        assert.ok(close(Lyrics.stamp("00:03.123"), 3.123));
        assert.ok(close(Lyrics.stamp("2:05"), 125));
        assert.ok(close(Lyrics.stamp("1:00:00.5"), 3600.5));
    });

    test.it("refuses what is not a time", () => {
        assert.ok(Number.isNaN(Lyrics.stamp("ar:Someone")));
        assert.ok(Number.isNaN(Lyrics.stamp("length")));
    });
});

test.describe("parseLrc", () => {
    test.it("reads timed lines in order and skips the tags", () => {
        const lines = Lyrics.parseLrc("[ar:Someone]\n[ti:Song]\n[00:05.00] second\n[00:01.00] first\n");
        assert.deepStrictEqual(lines.map(l => [l.start, l.text]), [[1, "first"], [5, "second"]]);
    });

    test.it("repeats a line under every stamp it carries", () => {
        const lines = Lyrics.parseLrc("[00:10.00][00:30.00]chorus\n[00:20.00]verse");
        assert.deepStrictEqual(lines.map(l => [l.start, l.text]), [[10, "chorus"], [20, "verse"], [30, "chorus"]]);
    });

    test.it("applies the offset tag, which moves lines earlier when positive", () => {
        const lines = Lyrics.parseLrc("[offset:+500]\n[00:02.00]a");
        assert.ok(close(lines[0].start, 1.5));
    });

    test.it("reads word stamps, and joins pieces that touch", () => {
        const [line] = Lyrics.parseLrc("[00:01.00]<00:01.00>Hel<00:01.50>lo <00:02.00>world<00:03.00>");
        assert.strictEqual(line.text, "Hello world");
        const words = Lyrics.group(line.pieces);
        assert.deepStrictEqual(words.map(w => [w.text, w.start, w.end]), [["Hello", 1, 2], ["world", 2, 3]]);
        assert.strictEqual(words[0].parts.length, 2);
    });

    test.it("survives windows line endings and junk", () => {
        const lines = Lyrics.parseLrc("garbage\r\n[00:01.00]a\r\n[xx:yy]b\r\n");
        assert.deepStrictEqual(lines.map(l => l.text), ["a"]);
    });
});

test.describe("separate", () => {
    const words = text => text.split(" ").map((t, i) => ({ text: t, start: i, end: i + 1, parts: null }));

    test.it("lifts a parenthesis out of the middle and keeps its punctuation in the lead", () => {
        const { lead, back } = Lyrics.separate(words("Well (Our love), is a bubbling fountain"));
        assert.strictEqual(texts(lead), "Well, is a bubbling fountain");
        assert.strictEqual(texts(back), "Our love");
    });

    test.it("makes a line that is all parenthesis a backing line", () => {
        const { lead, back } = Lyrics.separate(words("(Coming back to town)"));
        assert.strictEqual(lead.length, 0);
        assert.strictEqual(texts(back), "Coming back to town");
    });

    test.it("keeps the timing of the words it moves", () => {
        const { back } = Lyrics.separate(words("I'm levitating (yeah)"));
        assert.deepStrictEqual(back.map(w => [w.text, w.start]), [["yeah", 2]]);
    });

    test.it("trims syllable parts along with the brackets", () => {
        const w = { text: "(oh)", start: 1, end: 2, parts: [{ size: 4, start: 1, end: 2 }] };
        const { back } = Lyrics.separate([w]);
        assert.strictEqual(back[0].text, "oh");
        assert.strictEqual(back[0].parts[0].size, 2);
    });
});

test.describe("fromLrc", () => {
    test.it("paces words across the line in reading order", () => {
        const lines = sungLines(Lyrics.fromLrc(Lyrics.parseLrc("[00:01.00]one two three\n[00:04.00]next"), 30));
        const ws = lines[0].lead;
        assert.ok(ws[0].start === 1 && ws[0].end <= ws[1].start + 1e-9 && ws[1].end <= ws[2].start + 1e-9);
        assert.ok(ws[2].end <= 4);
    });

    test.it("opens with a break when the singing starts late", () => {
        const lines = Lyrics.fromLrc(Lyrics.parseLrc("[00:12.00]a\n[00:14.00]b"), 60);
        assert.strictEqual(lines[0].gap, true);
        assert.strictEqual(lines[0].end, 12);
    });

    test.it("finds the music between lines that were followed by a long silence", () => {
        const lines = Lyrics.fromLrc(Lyrics.parseLrc("[00:01.00]short line\n[00:30.00]after the solo\n[00:33.00]x"), 60);
        assert.deepStrictEqual(lines.map(l => l.gap ? "~" : l.text), ["short line", "~", "after the solo", "x"]);
    });

    test.it("does not invent a break between lines that run into each other", () => {
        const lines = Lyrics.fromLrc(Lyrics.parseLrc("[00:01.00]a fairly long line of words\n[00:05.00]and the next one\n[00:08.00]and one more"), 60);
        assert.strictEqual(lines.filter(l => l.gap).length, 0);
    });

    test.it("trusts an empty stamped line as the end of the singing", () => {
        const lines = Lyrics.fromLrc(Lyrics.parseLrc("[00:01.00]a\n[00:04.00]\n[00:09.00]b"), 60);
        assert.deepStrictEqual(lines.map(l => l.gap ? "~" : l.text), ["a", "~", "b"]);
    });

    test.it("splits a backing vocal into its own words", () => {
        const [line] = Lyrics.fromLrc(Lyrics.parseLrc("[00:00.00]You, moonlight (you're the moonlight)\n[00:04.00]x"), 30);
        assert.strictEqual(texts(line.lead), "You, moonlight");
        assert.strictEqual(texts(line.back), "you're the moonlight");
    });
});

test.describe("fromSpicy", () => {
    const syl = (text, start, end, joins) => ({ Text: text, StartTime: start, EndTime: end, IsPartOfWord: !!joins });

    const content = {
        Type: "Syllable",
        Content: [
            {
                Type: "Vocal",
                OppositeAligned: false,
                Lead: { StartTime: 1, EndTime: 3, Syllables: [syl("Hel", 1, 1.5, true), syl("lo", 1.5, 2), syl("there", 2, 3)] },
                Background: [{ StartTime: 2.5, EndTime: 3.4, Syllables: [syl("oh", 2.5, 3.4)] }]
            },
            {
                Type: "Vocal",
                OppositeAligned: true,
                Lead: { StartTime: 10, EndTime: 11, Syllables: [syl("Duet", 10, 11)] }
            }
        ]
    };

    test.it("groups syllables into words and keeps their timing", () => {
        const { synced } = Lyrics.fromSpicy(content, 60);
        const first = sungLines(synced)[0];
        assert.deepStrictEqual(first.lead.map(w => [w.text, w.start, w.end]), [["Hello", 1, 2], ["there", 2, 3]]);
        assert.strictEqual(texts(first.back), "oh");
        assert.strictEqual(first.end, 3.4);
        assert.strictEqual(first.timed, true);
    });

    test.it("puts the other singer on the other side, and the music between them in dots", () => {
        const { synced } = Lyrics.fromSpicy(content, 60);
        assert.deepStrictEqual(synced.map(l => l.gap ? `~${l.start}-${l.end}` : l.side), ["left", "~3.4-10", "right"]);
    });

    test.it("reads line-only lyrics and their real ends", () => {
        const { synced } = Lyrics.fromSpicy({
            Type: "Line",
            Content: [
                { Type: "Vocal", Text: "Go ​spin the wheel", StartTime: 1, EndTime: 3 },
                { Type: "Vocal", Text: "later", StartTime: 9, EndTime: 10 }
            ]
        }, 60);
        assert.deepStrictEqual(synced.map(l => l.gap ? "~" : l.text), ["Go spin the wheel", "~", "later"]);
        assert.ok(close(sungLines(synced)[0].lead[3].end, 3));
    });

    test.it("hands back unsynced lyrics as plain lines", () => {
        assert.deepStrictEqual(Lyrics.fromSpicy({ Type: "Static", SongWriters: ["Someone"], Lines: [{ Text: "a" }, { Text: "b" }] }, 0), { plain: ["a", "b"], writers: ["Someone"] });
    });
});

test.describe("timing", () => {
    const words = [
        { text: "ab", start: 1, end: 2, parts: null },
        { text: "cdef", start: 2, end: 4, parts: [{ size: 2, start: 2, end: 3 }, { size: 2, start: 3, end: 4 }] }
    ];

    test.it("counts whole words sung plus the part of the one being sung", () => {
        assert.strictEqual(Lyrics.progress(words, 0.5), 0);
        assert.ok(close(Lyrics.progress(words, 1.5), 0.5));
        assert.ok(close(Lyrics.progress(words, 2.5), 1.25));
        assert.ok(close(Lyrics.progress(words, 3.5), 1.75));
        assert.strictEqual(Lyrics.progress(words, 9), 2);
    });

    test.it("finds the line that began last", () => {
        const lines = [{ start: 1 }, { start: 5 }, { start: 9 }];
        assert.strictEqual(Lyrics.lineAt(lines, 0.5), -1);
        assert.strictEqual(Lyrics.lineAt(lines, 5), 1);
        assert.strictEqual(Lyrics.lineAt(lines, 100), 2);
    });

    test.it("fills a break just before it ends", () => {
        const g = { start: 10, end: 20 };
        assert.strictEqual(Lyrics.gapFill(g, 10), 0);
        assert.strictEqual(Lyrics.gapFill(g, 19.8), 1);
    });
});

test.describe("layout", () => {
    test.it("breaks between words, never inside one", () => {
        const rows = Lyrics.layout([30, 40, 50, 20], 10, 90);
        assert.deepStrictEqual(rows.map(r => [r.first, r.count, r.width]), [[0, 2, 80], [2, 2, 80]]);
        assert.deepStrictEqual(rows[1].starts, [0, 60]);
    });

    test.it("gives a word wider than the room a row of its own", () => {
        const rows = Lyrics.layout([200, 10], 10, 90);
        assert.deepStrictEqual(rows.map(r => r.count), [1, 1]);
    });

    test.it("lights a row word by word, the current word partly", () => {
        const widths = [30, 40, 50, 20];
        const rows = Lyrics.layout(widths, 10, 90);
        assert.strictEqual(Lyrics.litWidth(rows[0], widths, 0), 0);
        assert.strictEqual(Lyrics.litWidth(rows[0], widths, 1.5), 40 + 20);
        assert.strictEqual(Lyrics.litWidth(rows[0], widths, 3), 80);
        assert.strictEqual(Lyrics.litWidth(rows[1], widths, 1.5), 0);
        assert.strictEqual(Lyrics.litWidth(rows[1], widths, 2.5), 25);
    });
});

test.describe("matching", () => {
    test.it("cleans titles of features, remasters and versions", () => {
        assert.strictEqual(Lyrics.cleanTitle("Levitating (feat. DaBaby)"), "Levitating");
        assert.strictEqual(Lyrics.cleanTitle("Bohemian Rhapsody - Remastered 2011"), "Bohemian Rhapsody");
        assert.strictEqual(Lyrics.cleanTitle("Song [Official Video]"), "Song");
        assert.strictEqual(Lyrics.cleanTitle("Mr. Brightside"), "Mr. Brightside");
        assert.strictEqual(Lyrics.cleanTitle("Everything Now (continued)"), "Everything Now (continued)");
    });

    test.it("takes the first of several artists", () => {
        assert.strictEqual(Lyrics.firstArtist("Dua Lipa, DaBaby"), "Dua Lipa");
        assert.strictEqual(Lyrics.firstArtist("Simon & Garfunkel"), "Simon");
        assert.strictEqual(Lyrics.firstArtist("Calvin Harris feat. Rihanna"), "Calvin Harris");
    });

    const wanted = { title: "Billie Jean", artist: "Michael Jackson", album: "Thriller", length: 294 };

    test.it("prefers synced lyrics at the right length by the right artist", () => {
        const records = [
            { trackName: "Billie Jean", artistName: "Pizza Music", duration: 294, syncedLyrics: "[00:01.00]x" },
            { trackName: "Billie Jean", artistName: "Michael Jackson", duration: 294, plainLyrics: "x" },
            { trackName: "Billie Jean", artistName: "Michael Jackson", duration: 295, syncedLyrics: "[00:01.00]x", id: "best" },
            { trackName: "Billie Jean", artistName: "Michael Jackson", duration: 679, syncedLyrics: "[00:01.00]x" }
        ];
        assert.strictEqual(Lyrics.pick(records, wanted).id, "best");
    });

    test.it("refuses a different song or a different length", () => {
        assert.strictEqual(Lyrics.pick([{ trackName: "Beat It", artistName: "Michael Jackson", duration: 294, syncedLyrics: "x" }], wanted), null);
        assert.strictEqual(Lyrics.pick([{ trackName: "Billie Jean", artistName: "Michael Jackson", duration: 400, syncedLyrics: "x" }], wanted), null);
    });

    test.it("builds a query that skips empty fields", () => {
        assert.strictEqual(Lyrics.query({ a: "x y", b: "", c: 3 }), "a=x%20y&c=3");
    });
});
