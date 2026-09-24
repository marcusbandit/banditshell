// components/vt.js: the terminal, as a data structure.
//
// A parser is testable and a delegate is not, which is the reason the file has
// no QML in it; this is the other half of that bargain. What is checked here is
// the behaviour that breaks SILENTLY: a colour that resolves to the wrong hex,
// an erase that forgets the background it was told to use, a character split
// across two reads. None of those throw, and all of them look like the terminal
// is simply wrong.

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/vt.js"), "utf8");
const Vt = new Function(src
    + "\nreturn { create, keySequence, textSequence, pasteSequence, charWidth };")();

// The view's own defaults are what reverse video swaps against, so the tests
// name them rather than letting the constructor pick black on white.
const FG = "#eeeeee";
const BG = "#111111";

function term(cols, rows, opts) {
    return Vt.create(cols || 20, rows || 4, Object.assign({foreground: FG, background: BG}, opts));
}

// A row as plain text, trailing blanks dropped. Wide glyphs leave an empty
// second cell, which joins to nothing and keeps the string readable.
function row(t, y) {
    return t.screen.lines[y].map(c => c.c).join("").replace(/ +$/, "");
}

function rows(t) {
    return t.screen.lines.map((_, y) => row(t, y));
}

// The bytes as they come off the pty: one character per byte.
function bytes(s) {
    return Buffer.from(s, "utf8").toString("latin1");
}

test.describe("vt: text into the grid", () => {
    test.it("puts plain text where the cursor is", () => {
        const t = term(20, 4);
        t.write("hello");
        assert.strictEqual(row(t, 0), "hello");
        assert.strictEqual(t.screen.x, 5);
        assert.strictEqual(t.screen.y, 0);
    });

    test.it("bumps the revision so a view can bind to one number", () => {
        const t = term();
        const before = t.revision;
        t.write("x");
        assert.ok(t.revision > before);
    });

    test.it("carriage return goes to the start of the same row", () => {
        const t = term();
        t.write("hello\rH");
        assert.strictEqual(row(t, 0), "Hello");
        assert.strictEqual(t.screen.y, 0);
    });

    test.it("line feed goes down without going back", () => {
        const t = term();
        t.write("ab\ncd");
        assert.strictEqual(row(t, 0), "ab");
        assert.strictEqual(row(t, 1), "  cd");
    });

    test.it("backspace steps back one and stops at the margin", () => {
        const t = term();
        t.write("abc\b\bX");
        assert.strictEqual(row(t, 0), "aXc");
        t.write("\r\b\b\bZ");
        assert.strictEqual(row(t, 0), "ZXc");
    });

    test.it("tab moves to the next eight-column stop", () => {
        const t = term(20, 4);
        t.write("a\tb");
        assert.strictEqual(t.screen.x, 9);
        assert.strictEqual(row(t, 0), "a       b");
    });

    test.it("tab from a stop goes to the next one, not nowhere", () => {
        const t = term(40, 4);
        t.write("\t");
        assert.strictEqual(t.screen.x, 8);
        t.write("\t");
        assert.strictEqual(t.screen.x, 16);
    });

    test.it("moves the cursor absolutely with CSI H", () => {
        const t = term(20, 4);
        t.write("\x1b[3;5Hx");
        assert.strictEqual(row(t, 2), "    x");
    });
});

test.describe("vt: colour", () => {
    // The markup is where a colour becomes visible, so that is where it is
    // checked: an index in a cell means nothing until renderLine resolves it.
    function markup(t, y) {
        return t.renderLine(t.screen.lines[y === undefined ? 0 : y]).markup;
    }

    function runs(t, y) {
        return t.renderLine(t.screen.lines[y === undefined ? 0 : y]).runs;
    }

    test.it("resolves the indexed foregrounds against the palette", () => {
        const t = term();
        t.write("\x1b[31mred");
        assert.strictEqual(markup(t), "<font color=\"#cd0000\">red</font>");
    });

    test.it("resolves the bright foregrounds as 8 through 15", () => {
        const t = term();
        t.write("\x1b[91mred");
        assert.strictEqual(markup(t), "<font color=\"#ff0000\">red</font>");
    });

    test.it("resolves an indexed background as a run rather than markup", () => {
        const t = term();
        t.write("\x1b[42mgo");
        assert.deepStrictEqual(runs(t), [{x: 0, len: 2, colour: "#00cd00"}]);
        assert.strictEqual(markup(t), "go");
    });

    test.it("computes the 6x6x6 cube rather than looking it up", () => {
        const t = term();
        // 196 is the corner of the cube: full red, no green, no blue.
        t.write("\x1b[38;5;196mx");
        assert.strictEqual(markup(t), "<font color=\"#ff0000\">x</font>");
    });

    test.it("computes the grey ramp", () => {
        const t = term();
        t.write("\x1b[38;5;244mx");
        assert.strictEqual(markup(t), "<font color=\"#808080\">x</font>");
    });

    test.it("takes the first sixteen of the 256 from the palette", () => {
        const t = term();
        t.write("\x1b[38;5;9mx");
        assert.strictEqual(markup(t), "<font color=\"#ff0000\">x</font>");
    });

    test.it("takes truecolor 38;2 as a real colour", () => {
        const t = term();
        t.write("\x1b[38;2;18;52;86mx");
        assert.strictEqual(markup(t), "<font color=\"#123456\">x</font>");
    });

    test.it("takes truecolor 48;2 as a background run", () => {
        const t = term();
        t.write("\x1b[48;2;255;128;0mx");
        assert.deepStrictEqual(runs(t), [{x: 0, len: 1, colour: "#ff8000"}]);
    });

    test.it("honours a palette handed in by the config", () => {
        const t = term(20, 4, {palette: Array(16).fill("#abcdef")});
        t.write("\x1b[31mx");
        assert.strictEqual(markup(t), "<font color=\"#abcdef\">x</font>");
    });

    test.it("resets everything on SGR 0 and on a bare CSI m", () => {
        const t = term();
        t.write("\x1b[1;31mA\x1b[0mB");
        assert.strictEqual(markup(t), "<font color=\"#cd0000\"><b>A</b></font>B");
        t.write("\r\x1b[1;31mA\x1b[mB");
        assert.strictEqual(markup(t), "<font color=\"#cd0000\"><b>A</b></font>B");
    });

    test.it("carries the attributes into the markup", () => {
        const t = term();
        t.write("\x1b[1;3;4;9mx");
        assert.strictEqual(markup(t), "<s><u><i><b>x</b></i></u></s>");
    });

    test.it("turns an attribute off again", () => {
        const t = term();
        t.write("\x1b[1mA\x1b[22mB");
        assert.strictEqual(markup(t), "<b>A</b>B");
    });

    test.it("hides the text of a hidden run without losing its width", () => {
        const t = term();
        t.write("\x1b[8msecret");
        assert.strictEqual(markup(t), "      ");
    });

    test.it("draws nothing at all for an ordinary row", () => {
        const t = term();
        t.write("plain output");
        assert.strictEqual(markup(t), "plain output");
        assert.deepStrictEqual(runs(t), []);
    });

    test.it("escapes the characters that would otherwise be markup", () => {
        const t = term(40, 4);
        t.write("a<b>&c");
        assert.strictEqual(markup(t), "a&lt;b&gt;&amp;c");
    });
});

test.describe("vt: reverse video", () => {
    // Reverse is why the terminal has to KNOW its defaults: swapping two nulls
    // is still two nulls, and the run would draw ordinary text on an ordinary
    // background, which is the one thing reverse means it is not.
    test.it("swaps against the configured defaults when nothing was set", () => {
        const t = term();
        t.write("\x1b[7mrev");
        const line = t.renderLine(t.screen.lines[0]);
        assert.strictEqual(line.markup, "<font color=\"" + BG + "\">rev</font>");
        assert.deepStrictEqual(line.runs, [{x: 0, len: 3, colour: FG}]);
    });

    test.it("swaps the colours that were set", () => {
        const t = term();
        t.write("\x1b[31;44;7mrev");
        const line = t.renderLine(t.screen.lines[0]);
        assert.strictEqual(line.markup, "<font color=\"#0000ee\">rev</font>");
        assert.deepStrictEqual(line.runs, [{x: 0, len: 3, colour: "#cd0000"}]);
    });

    test.it("un-swaps on SGR 27, which is why it is stored on the cell", () => {
        const t = term();
        t.write("\x1b[7mA\x1b[27mB");
        const line = t.renderLine(t.screen.lines[0]);
        assert.strictEqual(line.markup, "<font color=\"" + BG + "\">A</font>B");
        assert.deepStrictEqual(line.runs, [{x: 0, len: 1, colour: FG}]);
    });
});

test.describe("vt: erasing", () => {
    test.it("CSI 2J fills the screen with the CURRENT background", () => {
        const t = term(10, 2);
        t.write("\x1b[41m\x1b[2J");
        assert.strictEqual(t.screen.lines[0][0].b, 1);
        assert.deepStrictEqual(t.renderLine(t.screen.lines[0]).runs,
            [{x: 0, len: 10, colour: "#cd0000"}]);
    });

    test.it("CSI J erases from the cursor to the end of the screen", () => {
        const t = term(10, 3);
        t.write("aaa\r\nbbb\r\nccc");
        t.write("\x1b[2;2H\x1b[J");
        assert.deepStrictEqual(rows(t), ["aaa", "b", ""]);
    });

    test.it("CSI 1J erases from the start of the screen to the cursor", () => {
        const t = term(10, 3);
        t.write("aaa\r\nbbb\r\nccc");
        t.write("\x1b[2;2H\x1b[1J");
        assert.deepStrictEqual(rows(t), ["", "  b", "ccc"]);
    });

    test.it("CSI K erases to the end of the line only", () => {
        const t = term(10, 2);
        t.write("abcdef\r\x1b[3C\x1b[K");
        assert.deepStrictEqual(rows(t), ["abc", ""]);
    });

    test.it("CSI 1K erases back to the start of the line", () => {
        const t = term(10, 2);
        t.write("abcdef\r\x1b[3C\x1b[1K");
        assert.strictEqual(row(t, 0), "    ef");
    });

    test.it("CSI 2K erases the whole line", () => {
        const t = term(10, 2);
        t.write("abcdef\x1b[2K");
        assert.strictEqual(row(t, 0), "");
    });

    test.it("keeps the background on a line erase too", () => {
        const t = term(10, 2);
        t.write("abcdef\r\x1b[44m\x1b[K");
        assert.deepStrictEqual(t.renderLine(t.screen.lines[0]).runs,
            [{x: 0, len: 10, colour: "#0000ee"}]);
    });

    test.it("keeps nothing but the background", () => {
        const t = term(10, 2);
        t.write("\x1b[1;4;31;44mabc\r\x1b[K");
        const cell = t.screen.lines[0][0];
        assert.strictEqual(cell.a, 0);
        assert.strictEqual(cell.f, null);
        assert.strictEqual(cell.b, 4);
    });
});

test.describe("vt: scrolling and history", () => {
    test.it("pushes rows off the top into the scrollback", () => {
        const t = term(10, 3);
        t.write("aaa\r\nbbb\r\nccc\r\nddd");
        assert.deepStrictEqual(t.scrollback.map(l => l.markup), ["aaa"]);
        assert.deepStrictEqual(rows(t), ["bbb", "ccc", "ddd"]);
    });

    test.it("keeps history as rendered rows, not cells", () => {
        const t = term(10, 2);
        t.write("\x1b[31mred\x1b[0m\r\n\r\n");
        assert.strictEqual(t.scrollback[0].markup, "<font color=\"#cd0000\">red</font>");
    });

    test.it("caps the history at scrollbackMax", () => {
        const t = term(10, 2, {scrollback: 3});
        for (let i = 0; i < 10; i++)
            t.write("l" + i + "\r\n");
        assert.strictEqual(t.scrollback.length, 3);
        assert.deepStrictEqual(t.scrollback.map(l => l.markup), ["l6", "l7", "l8"]);
    });

    test.it("keeps no history at all when it is turned off", () => {
        const t = term(10, 2, {scrollback: 0});
        t.write("a\r\nb\r\nc\r\nd");
        assert.deepStrictEqual(t.scrollback, []);
    });

    test.it("does not call a partial scroll region history", () => {
        // A line pushed out of a two-row region in the middle of the display is
        // a redraw, not something that happened and scrolled away.
        const t = term(10, 4);
        t.write("\x1b[2;3r");
        t.write("aa\r\nbb\r\ncc\r\ndd");
        assert.deepStrictEqual(t.scrollback, []);
    });

    test.it("CSI 3J is the only thing that empties the history", () => {
        const t = term(10, 3);
        t.write("a\r\nb\r\nc\r\nd");
        assert.strictEqual(t.scrollback.length, 1);
        t.write("\x1b[2J");
        assert.strictEqual(t.scrollback.length, 1);
        t.write("\x1b[3J");
        assert.strictEqual(t.scrollback.length, 0);
    });

    test.it("scrolls down without touching the history", () => {
        const t = term(10, 3);
        t.write("a\r\nb\r\nc");
        t.write("\x1b[T");
        assert.deepStrictEqual(rows(t), ["", "a", "b"]);
        assert.deepStrictEqual(t.scrollback, []);
    });

    test.it("view() puts however much history is asked for above the screen", () => {
        const t = term(10, 2);
        t.write("a\r\nb\r\nc\r\nd");
        assert.deepStrictEqual(t.view(0).map(l => l.markup), ["c", "d"]);
        assert.deepStrictEqual(t.view(1).map(l => l.markup), ["b", "c"]);
        assert.deepStrictEqual(t.view(99).map(l => l.markup), ["a", "b"]);
    });
});

test.describe("vt: the alt screen", () => {
    test.it("is a separate grid and gives the old one back", () => {
        const t = term(10, 3);
        t.write("main\r\n");
        t.write("\x1b[?1049h");
        t.write("alt");
        assert.strictEqual(t.altActive, true);
        assert.strictEqual(row(t, 0), "alt");
        t.write("\x1b[?1049l");
        assert.strictEqual(t.altActive, false);
        assert.deepStrictEqual(rows(t), ["main", "", ""]);
    });

    test.it("never reaches the scrollback", () => {
        const t = term(10, 3);
        t.write("\x1b[?1049h");
        t.write("a\r\nb\r\nc\r\nd\r\ne\r\nf");
        assert.deepStrictEqual(t.scrollback, []);
        t.write("\x1b[?1049l");
        assert.deepStrictEqual(t.scrollback, []);
    });

    test.it("throws away what was drawn on it", () => {
        const t = term(10, 3);
        t.write("\x1b[?1049h" + "gone" + "\x1b[?1049l");
        t.write("\x1b[?1049h");
        assert.deepStrictEqual(rows(t), ["", "", ""]);
    });

    test.it("puts the cursor back where it was, on 1049", () => {
        const t = term(10, 3);
        t.write("ab\r\ncd");
        const x = t.screen.x, y = t.screen.y;
        t.write("\x1b[?1049h\x1b[3;9Hzz\x1b[?1049l");
        assert.strictEqual(t.screen.x, x);
        assert.strictEqual(t.screen.y, y);
    });

    test.it("ignores a switch to the screen it is already on", () => {
        const t = term(10, 3);
        t.write("\x1b[?1049h");
        t.write("keep");
        t.write("\x1b[?1049h");
        assert.strictEqual(row(t, 0), "keep");
    });
});

test.describe("vt: wrapping", () => {
    test.it("waits at the last column instead of wrapping straight away", () => {
        // The pending wrap: the cursor sits ON the last column until another
        // character arrives, so a line that exactly fills the width does not
        // leave the cursor a row down before anything is there.
        const t = term(5, 3);
        t.write("abcde");
        assert.strictEqual(t.screen.x, 4);
        assert.strictEqual(t.screen.y, 0);
        assert.strictEqual(t.screen.pending, true);
    });

    test.it("wraps when the next character actually arrives", () => {
        const t = term(5, 3);
        t.write("abcdef");
        assert.deepStrictEqual(rows(t), ["abcde", "f", ""]);
        assert.strictEqual(t.screen.x, 1);
        assert.strictEqual(t.screen.y, 1);
    });

    test.it("cancels the pending wrap on carriage return", () => {
        const t = term(5, 3);
        t.write("abcde\rX");
        assert.deepStrictEqual(rows(t), ["Xbcde", "", ""]);
    });

    test.it("spends the pending wrap on a backspace rather than a column", () => {
        const t = term(5, 3);
        t.write("abcde\bX");
        assert.deepStrictEqual(rows(t), ["abcdX", "", ""]);
    });

    test.it("overwrites the last column when autowrap is off", () => {
        const t = term(5, 3);
        t.write("\x1b[?7l");
        t.write("abcdefgh");
        assert.deepStrictEqual(rows(t), ["abcdh", "", ""]);
        assert.strictEqual(t.autowrap, false);
    });

    test.it("wraps again once autowrap is turned back on", () => {
        const t = term(5, 3);
        t.write("\x1b[?7labcde\x1b[?7hf");
        assert.deepStrictEqual(rows(t), ["abcde", "f", ""]);
    });

    test.it("scrolls when a wrap runs off the bottom", () => {
        const t = term(3, 2);
        t.write("abcdefghi");
        assert.deepStrictEqual(rows(t), ["def", "ghi"]);
        assert.deepStrictEqual(t.scrollback.map(l => l.markup), ["abc"]);
    });
});

test.describe("vt: UTF-8", () => {
    test.it("decodes a two-byte character", () => {
        const t = term();
        t.write(bytes("café"));
        assert.strictEqual(row(t, 0), "café");
    });

    test.it("survives a character split across two writes", () => {
        // A chunk boundary off the pty is not a character boundary, and half a
        // sequence decoded on its own is a replacement character mid-word.
        const t = term();
        const b = bytes("é");
        assert.strictEqual(b.length, 2);
        t.write(b[0]);
        assert.strictEqual(t.utf8Need, 1);
        t.write(b[1]);
        assert.strictEqual(row(t, 0), "é");
        assert.strictEqual(t.screen.x, 1);
    });

    test.it("survives a three-byte character split anywhere", () => {
        const b = bytes("日");
        for (let cut = 1; cut < b.length; cut++) {
            const t = term();
            t.write(b.slice(0, cut));
            t.write(b.slice(cut));
            assert.strictEqual(row(t, 0), "日", "cut at " + cut);
        }
    });

    test.it("survives a four-byte character split anywhere", () => {
        const b = bytes("🎉");
        for (let cut = 1; cut < b.length; cut++) {
            const t = term();
            t.write(b.slice(0, cut));
            t.write(b.slice(cut));
            assert.strictEqual(row(t, 0), "🎉", "cut at " + cut);
        }
    });

    test.it("survives a stream cut one byte at a time", () => {
        const t = term(40, 2);
        const b = bytes("ls ~/Downloads café 日本 🎉");
        for (let i = 0; i < b.length; i++)
            t.write(b[i]);
        assert.strictEqual(row(t, 0), "ls ~/Downloads café 日本 🎉");
    });

    test.it("gives a wide character two cells", () => {
        const t = term(10, 2);
        t.write(bytes("日本"));
        assert.strictEqual(t.screen.x, 4);
        assert.deepStrictEqual(t.screen.lines[0].slice(0, 4).map(c => c.w), [2, 0, 2, 0]);
    });

    test.it("hangs a combining mark on the character before it", () => {
        const t = term(10, 2);
        t.write(bytes("é"));
        assert.strictEqual(t.screen.lines[0][0].c, "é");
        assert.strictEqual(t.screen.x, 1);
    });

    test.it("shows a broken sequence rather than swallowing what follows", () => {
        const t = term(10, 2);
        t.write("\xc3" + "A");
        assert.strictEqual(row(t, 0), "�A");
    });

    test.it("measures width the way the grid needs it", () => {
        assert.strictEqual(Vt.charWidth("A".codePointAt(0)), 1);
        assert.strictEqual(Vt.charWidth(0), 0);
        assert.strictEqual(Vt.charWidth(0x301), 0);
        assert.strictEqual(Vt.charWidth(0xfe0f), 0);
        assert.strictEqual(Vt.charWidth("日".codePointAt(0)), 2);
        assert.strictEqual(Vt.charWidth("한".codePointAt(0)), 2);
        assert.strictEqual(Vt.charWidth(0x1f389), 2);
        assert.strictEqual(Vt.charWidth("é".codePointAt(0)), 1);
    });
});

test.describe("vt: resize", () => {
    test.it("keeps what was on the screen", () => {
        const t = term(20, 3);
        t.write("hello\r\nworld");
        t.resize(30, 6);
        assert.strictEqual(t.cols, 30);
        assert.strictEqual(t.rows, 6);
        assert.strictEqual(t.screen.lines.length, 6);
        assert.strictEqual(t.screen.lines[0].length, 30);
        assert.deepStrictEqual(rows(t).slice(0, 2), ["hello", "world"]);
    });

    test.it("keeps what fits when narrowing, and blanks nothing else", () => {
        const t = term(20, 3);
        t.write("abcdefghij");
        t.resize(5, 3);
        assert.strictEqual(row(t, 0), "abcde");
        assert.strictEqual(t.screen.lines[0].length, 5);
    });

    test.it("pushes the rows it loses into the history", () => {
        const t = term(10, 4);
        t.write("aa\r\nbb\r\ncc");
        t.resize(10, 2);
        assert.deepStrictEqual(t.scrollback.map(l => l.markup), ["aa", "bb"]);
        assert.deepStrictEqual(rows(t), ["cc", ""]);
        assert.strictEqual(t.screen.y, 0);
    });

    test.it("re-lays the tab stops for the new width", () => {
        const t = term(20, 3);
        t.resize(10, 3);
        t.write("\t\t");
        assert.strictEqual(t.screen.x, 9);
    });

    test.it("does nothing when the size has not changed", () => {
        const t = term(20, 3);
        t.write("keep");
        const rev = t.revision;
        t.resize(20, 3);
        assert.strictEqual(t.revision, rev);
        assert.strictEqual(row(t, 0), "keep");
    });

    // BUG (not fixed, reported): the comment above the shrink loop in resize()
    // GROWING APPENDS BLANK ROWS and does not pull history back, which every
    // other terminal does and this one cannot. The reason is a trade made
    // deliberately: the scrollback holds RENDERED LINES rather than cells,
    // because keeping half a million live cell objects to represent history
    // costs far more than the strings do - and a rendered line cannot be put
    // back into a live screen made of cells. Pinned so that a future change to
    // the scrollback's representation shows up here as a decision rather than as
    // a surprise.
    test.it("appends blank rows when the window is made taller, keeping history where it is", () => {
        const t = term(10, 3);
        t.write("one\r\ntwo\r\nthree\r\nfour");
        assert.deepStrictEqual(t.scrollback.map(l => l.markup), ["one"]);
        t.resize(10, 5);
        assert.deepStrictEqual(rows(t), ["two", "three", "four", "", ""]);
        assert.deepStrictEqual(t.scrollback.map(l => l.markup), ["one"]);
    });
});

test.describe("vt: the DEC special graphics set", () => {
    test.it("draws a box out of ordinary letters", () => {
        const t = term(20, 3);
        t.write("\x1b(0lqqqk\x1b(B plain");
        assert.strictEqual(rows(t)[0], "\u250c\u2500\u2500\u2500\u2510 plain");
    });

    test.it("keeps two slots and switches between them with SO and SI", () => {
        const t = term(20, 3);
        // G0 is graphics, G1 is left as ASCII: SO selects G1, SI comes back.
        t.write("\x1b(0\x0eq\x0fq");
        assert.strictEqual(rows(t)[0], "q\u2500");
    });

    test.it("puts the translated character in the cell, not just on the screen", () => {
        const t = term(20, 3);
        t.write("\x1b(0q");
        // A search or a copy over the grid should find the box character.
        assert.strictEqual(t.screen.lines[0][0].c, "\u2500");
    });

    test.it("forgets the designation on a reset", () => {
        const t = term(20, 3);
        t.write("\x1b(0q\x1bcq");
        assert.strictEqual(rows(t)[0], "q");
    });
});

test.describe("vt: the mouse", () => {
    test.it("says nothing at all until an application asks", () => {
        const t = term(80, 24);
        assert.strictEqual(t.mouseSequence(0, 4, 2, true, {}, false), "");
    });

    test.it("reports a press and a release apart under SGR", () => {
        const t = term(80, 24);
        t.write("\x1b[?1000h\x1b[?1006h");
        assert.strictEqual(t.mouseSequence(0, 4, 2, true, {}, false), "\x1b[<0;5;3M");
        assert.strictEqual(t.mouseSequence(0, 4, 2, false, {}, false), "\x1b[<0;5;3m");
    });

    test.it("adds the modifiers the way xterm does", () => {
        const t = term(80, 24);
        t.write("\x1b[?1000h\x1b[?1006h");
        // right button 2, plus ctrl 16
        assert.strictEqual(t.mouseSequence(2, 10, 5, true, {ctrl: true}, false), "\x1b[<18;11;6M");
        // shift 4 plus alt 8
        assert.strictEqual(t.mouseSequence(0, 0, 0, true, {shift: true, alt: true}, false), "\x1b[<12;1;1M");
    });

    test.it("holds back motion the mode did not ask for", () => {
        const press = term(80, 24);
        press.write("\x1b[?1000h\x1b[?1006h");
        assert.strictEqual(press.mouseSequence(0, 4, 2, true, {}, true), "");

        const drag = term(80, 24);
        drag.write("\x1b[?1002h\x1b[?1006h");
        assert.strictEqual(drag.mouseSequence(0, 4, 2, true, {}, true), "\x1b[<32;5;3M");
        // 1002 is drag only: no button means no report
        assert.strictEqual(drag.mouseSequence(-1, 4, 2, true, {}, true), "");

        const any = term(80, 24);
        any.write("\x1b[?1003h\x1b[?1006h");
        assert.strictEqual(any.mouseSequence(-1, 4, 2, true, {}, true), "\x1b[<35;5;3M");
    });

    test.it("sends a wheel notch as a button and never as a release", () => {
        const t = term(80, 24);
        t.write("\x1b[?1000h\x1b[?1006h");
        assert.strictEqual(t.wheelSequence(true, 4, 2, {}), "\x1b[<64;5;3M");
        assert.strictEqual(t.wheelSequence(false, 4, 2, {}), "\x1b[<65;5;3M");
    });

    test.it("falls back to the old three-byte encoding, and drops what it cannot express", () => {
        const t = term(300, 24);
        t.write("\x1b[?1002h");
        assert.strictEqual(t.mouseSequence(0, 4, 2, true, {}, false), "\x1b[M" + String.fromCharCode(32, 37, 35));
        // a release cannot say which button it was
        assert.strictEqual(t.mouseSequence(2, 4, 2, false, {}, false), "\x1b[M" + String.fromCharCode(35, 37, 35));
        // and a column past 223 cannot be expressed, so it is not guessed at
        assert.strictEqual(t.mouseSequence(0, 250, 2, true, {}, false), "");
    });
});

test.describe("vt: the answers an application waits for", () => {
    test.it("answers DA with a VT100 with advanced video", () => {
        const t = term();
        t.write("\x1b[c");
        assert.strictEqual(t.takeReply(), "\x1b[?1;2c");
    });

    test.it("answers secondary DA", () => {
        const t = term();
        t.write("\x1b[>c");
        assert.strictEqual(t.takeReply(), "\x1b[>0;95;0c");
    });

    test.it("answers DSR with the cursor position, one-based", () => {
        const t = term(20, 5);
        t.write("\x1b[3;7H");
        t.write("\x1b[6n");
        assert.strictEqual(t.takeReply(), "\x1b[3;7R");
    });

    test.it("answers a device status request", () => {
        const t = term();
        t.write("\x1b[5n");
        assert.strictEqual(t.takeReply(), "\x1b[0n");
    });

    test.it("answers a colour query in X11's own spelling", () => {
        // "#rrggbb" is simply not understood by the thing asking; the reply has
        // to be sixteen bits a channel.
        const t = term(20, 4, {foreground: "#ff8000", background: "#112233"});
        t.write("\x1b]10;?\x07");
        assert.strictEqual(t.takeReply(), "\x1b]10;rgb:ffff/8080/0000\x1b\\");
        t.write("\x1b]11;?\x1b\\");
        assert.strictEqual(t.takeReply(), "\x1b]11;rgb:1111/2222/3333\x1b\\");
    });

    test.it("takes the reply once and then has nothing to say", () => {
        const t = term();
        t.write("\x1b[c");
        assert.notStrictEqual(t.takeReply(), "");
        assert.strictEqual(t.takeReply(), "");
    });

    test.it("says nothing about text that merely looks like a query", () => {
        const t = term(40, 2);
        t.write("echo hello");
        assert.strictEqual(t.takeReply(), "");
    });
});

test.describe("vt: strings and modes", () => {
    test.it("takes the window title off OSC 0 and OSC 2", () => {
        const t = term();
        t.write("\x1b]0;a title\x07");
        assert.strictEqual(t.title, "a title");
        t.write("\x1b]2;another; with a semicolon\x1b\\");
        assert.strictEqual(t.title, "another; with a semicolon");
    });

    test.it("takes the working directory off OSC 7", () => {
        const t = term();
        t.write("\x1b]7;file://host/home/bandit/some%20dir\x07");
        assert.strictEqual(t.cwd, "/home/bandit/some dir");
    });

    test.it("draws none of a string it swallowed", () => {
        const t = term(40, 2);
        t.write("\x1b]0;title\x07visible");
        assert.strictEqual(row(t, 0), "visible");
    });

    test.it("tracks the modes the view has to read", () => {
        const t = term();
        assert.strictEqual(t.cursorVisible, true);
        t.write("\x1b[?25l");
        assert.strictEqual(t.cursorVisible, false);
        t.write("\x1b[?25h");
        assert.strictEqual(t.cursorVisible, true);
        t.write("\x1b[?1h");
        assert.strictEqual(t.appCursor, true);
        t.write("\x1b[?2004h");
        assert.strictEqual(t.bracketedPaste, true);
        t.write("\x1b[?1000h");
        assert.strictEqual(t.mouse, 1000);
        t.write("\x1b[?1000l");
        assert.strictEqual(t.mouse, 0);
    });

    test.it("drops a sequence it does not understand rather than printing it", () => {
        const t = term(40, 2);
        t.write("\x1b[?12;25;1005h\x1b[>4;2mvisible");
        assert.strictEqual(row(t, 0), "visible");
    });

    test.it("saves and restores the cursor with the attributes", () => {
        const t = term(20, 4);
        t.write("\x1b[2;3H\x1b[31m\x1b7");
        t.write("\x1b[4;1H\x1b[0m");
        t.write("\x1b8x");
        assert.strictEqual(row(t, 1), "  x");
        assert.strictEqual(t.renderLine(t.screen.lines[1]).markup,
            "  <font color=\"#cd0000\">x</font>");
    });

    test.it("wipes both screens on a full reset", () => {
        const t = term(10, 3);
        t.write("\x1b[?1049hgone\x1b[?1049lhere\x1b[31m");
        t.write("\x1bc");
        assert.deepStrictEqual(rows(t), ["", "", ""]);
        assert.strictEqual(t.fg, null);
        assert.strictEqual(t.altActive, false);
    });
});

test.describe("vt: the keyboard", () => {
    test.it("sends CARRIAGE RETURN for Return, not a newline", () => {
        // The single most load-bearing line in the file: the tty is in raw mode
        // whenever a line editor is running, so \n is echoed and the command is
        // never accepted.
        assert.strictEqual(Vt.keySequence("return", false, false, false, false), "\r");
        assert.strictEqual(Vt.keySequence("enter", false, false, false, false), "\r");
        assert.notStrictEqual(Vt.keySequence("return", false, false, false, false), "\n");
    });

    test.it("sends DEL for Backspace, not BS", () => {
        // 0x08 arrives as ^H and deletes in the wrong direction or not at all.
        assert.strictEqual(Vt.keySequence("backspace", false, false, false, false), "\x7f");
        assert.strictEqual(Vt.keySequence("backspace", false, false, false, false).charCodeAt(0), 0x7f);
        assert.strictEqual(Vt.keySequence("backspace", false, false, true, false), "\x08");
    });

    test.it("sends the cursor keys in whichever form the application asked for", () => {
        assert.strictEqual(Vt.keySequence("up", false, false, false, false), "\x1b[A");
        assert.strictEqual(Vt.keySequence("up", false, false, false, true), "\x1bOA");
        assert.strictEqual(Vt.keySequence("left", false, false, false, false), "\x1b[D");
        assert.strictEqual(Vt.keySequence("home", false, false, false, true), "\x1bOH");
    });

    test.it("encodes the modifiers as one plus a bitfield", () => {
        assert.strictEqual(Vt.keySequence("right", true, false, false, false), "\x1b[1;2C");
        assert.strictEqual(Vt.keySequence("right", false, true, false, false), "\x1b[1;3C");
        assert.strictEqual(Vt.keySequence("right", false, false, true, false), "\x1b[1;5C");
        assert.strictEqual(Vt.keySequence("right", true, true, true, false), "\x1b[1;8C");
    });

    test.it("leaves an unmodified key out of the modifier form entirely", () => {
        assert.strictEqual(Vt.keySequence("down", false, false, false, false), "\x1b[B");
    });

    test.it("sends the tilde keys with their numbers", () => {
        assert.strictEqual(Vt.keySequence("delete", false, false, false, false), "\x1b[3~");
        assert.strictEqual(Vt.keySequence("pageup", false, false, false, false), "\x1b[5~");
        assert.strictEqual(Vt.keySequence("pagedown", true, false, false, false), "\x1b[6;2~");
    });

    test.it("sends the function keys in their two families", () => {
        assert.strictEqual(Vt.keySequence("f1", false, false, false, false), "\x1bOP");
        assert.strictEqual(Vt.keySequence("f5", false, false, false, false), "\x1b[15~");
        assert.strictEqual(Vt.keySequence("f12", false, false, false, false), "\x1b[24~");
        assert.strictEqual(Vt.keySequence("f4", false, false, true, false), "\x1b[1;5S");
    });

    test.it("sends the odd ones out", () => {
        assert.strictEqual(Vt.keySequence("tab", false, false, false, false), "\t");
        assert.strictEqual(Vt.keySequence("tab", true, false, false, false), "\x1b[Z");
        assert.strictEqual(Vt.keySequence("escape", false, false, false, false), "\x1b");
        assert.strictEqual(Vt.keySequence("space", false, false, false, false), " ");
        assert.strictEqual(Vt.keySequence("space", false, false, true, false), "\x00");
    });

    test.it("sends nothing for a key it has no bytes for", () => {
        assert.strictEqual(Vt.keySequence("f13", false, false, false, false), "");
        assert.strictEqual(Vt.keySequence("printscreen", false, false, false, false), "");
    });

    test.it("round-trips a cursor key back through the parser", () => {
        const t = term(20, 4);
        t.write("\x1b[3;3H");
        t.write(Vt.keySequence("up", false, false, false, false));
        assert.strictEqual(t.screen.y, 1);
    });
});

test.describe("vt: typed text", () => {
    test.it("sends the character as it is", () => {
        assert.strictEqual(Vt.textSequence("a", false, false), "a");
        assert.strictEqual(Vt.textSequence("", false, false), "");
    });

    test.it("turns Ctrl+letter into the control code", () => {
        assert.strictEqual(Vt.textSequence("c", false, true), "\x03");
        assert.strictEqual(Vt.textSequence("C", false, true), "\x03");
        assert.strictEqual(Vt.textSequence("d", false, true), "\x04");
        assert.strictEqual(Vt.textSequence("r", false, true), "\x12");
        assert.strictEqual(Vt.textSequence("z", false, true), "\x1a");
        assert.strictEqual(Vt.textSequence("a", false, true), "\x01");
    });

    test.it("turns Ctrl+? into DEL and Ctrl+2..8 into the rest of them", () => {
        assert.strictEqual(Vt.textSequence("?", false, true), "\x7f");
        assert.strictEqual(Vt.textSequence("2", false, true), "\x00");
        assert.strictEqual(Vt.textSequence("3", false, true), "\x1b");
        assert.strictEqual(Vt.textSequence("7", false, true), "\x1f");
        assert.strictEqual(Vt.textSequence("8", false, true), "\x7f");
    });

    test.it("prefixes Alt with escape, which is what meta-sends-escape means", () => {
        assert.strictEqual(Vt.textSequence("b", true, false), "\x1bb");
        assert.strictEqual(Vt.textSequence("c", true, true), "\x1b\x03");
    });

    test.it("leaves a character with no control code alone", () => {
        assert.strictEqual(Vt.textSequence("!", false, true), "!");
    });
});

test.describe("vt: paste", () => {
    test.it("wraps a bracketed paste so the shell knows it is data", () => {
        assert.strictEqual(Vt.pasteSequence("ls", true), "\x1b[200~ls\x1b[201~");
    });

    test.it("sends the body bare when the application never asked", () => {
        assert.strictEqual(Vt.pasteSequence("ls", false), "ls");
    });

    test.it("turns every flavour of newline into a carriage return", () => {
        assert.strictEqual(Vt.pasteSequence("a\r\nb\nc", false), "a\rb\rc");
        assert.strictEqual(Vt.pasteSequence("a\r\nb", true), "\x1b[200~a\rb\x1b[201~");
    });

    test.it("round-trips a pasted block through the parser as text", () => {
        const t = term(20, 4);
        t.write(Vt.pasteSequence("one\ntwo", false).replace(/\r/g, "\r\n"));
        assert.deepStrictEqual(rows(t).slice(0, 2), ["one", "two"]);
    });
});
