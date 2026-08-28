// components/base64.js, checked against the codec everybody else agrees on.
//
// The whole point of the hand-written codec is that the bytes survive the trip;
// node's Buffer is a second implementation that already knows the right answer,
// so every case here is "what does Buffer say" rather than a table of expected
// strings somebody typed out once.

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

// The source is a QML .js import: no exports, so it is read and evaluated, and
// the names it declares are handed back by the trailing return.
const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/base64.js"), "utf8");
const B64 = new Function(src + "\nreturn { encode, decode, utf8 };")();

// One character per byte, which is the representation the whole file deals in.
function bytesToString(arr) {
    return Buffer.from(arr).toString("latin1");
}

const ALL_BYTES = bytesToString(Array.from({length: 256}, (_, i) => i));

test.describe("base64", () => {
    test.it("round-trips all 256 byte values", () => {
        assert.strictEqual(B64.decode(B64.encode(ALL_BYTES)), ALL_BYTES);
    });

    test.it("round-trips every byte on its own", () => {
        for (let i = 0; i < 256; i++) {
            const b = String.fromCharCode(i);
            assert.strictEqual(B64.decode(B64.encode(b)), b, "byte " + i);
        }
    });

    test.it("encodes what Buffer encodes", () => {
        for (const s of ["", "a", "ab", "abc", "abcd", ALL_BYTES, "\x00\x00\x00", "\xff\xff\xff"])
            assert.strictEqual(B64.encode(s), Buffer.from(s, "latin1").toString("base64"),
                JSON.stringify(s.slice(0, 8)));
    });

    test.it("pads the way Buffer pads, at every remainder", () => {
        assert.strictEqual(B64.encode("a"), "YQ==");
        assert.strictEqual(B64.encode("ab"), "YWI=");
        assert.strictEqual(B64.encode("abc"), "YWJj");
    });

    test.it("decodes what Buffer decodes", () => {
        for (const s of ["", "a", "ab", "abc", "abcd", ALL_BYTES]) {
            const b64 = Buffer.from(s, "latin1").toString("base64");
            assert.strictEqual(B64.decode(b64), s);
        }
    });

    test.it("decodes every length of frame up to a full alphabet", () => {
        for (let n = 0; n <= 64; n++) {
            const s = ALL_BYTES.slice(0, n);
            assert.strictEqual(B64.decode(Buffer.from(s, "latin1").toString("base64")), s,
                "length " + n);
        }
    });

    test.it("skips characters outside the alphabet rather than refusing the frame", () => {
        // A frame with a stray newline or a dropped byte in it still carries
        // its payload; see the comment in decode().
        const clean = Buffer.from("hello", "latin1").toString("base64");
        assert.strictEqual(B64.decode(clean.slice(0, 4) + "\n" + clean.slice(4)), "hello");
        assert.strictEqual(B64.decode(clean + "\r\n"), "hello");
    });

    test.it("treats padding as nothing to decode", () => {
        assert.strictEqual(B64.decode("YQ=="), "a");
        assert.strictEqual(B64.decode("YQ"), "a");
    });

    test.it("hands back only single bytes", () => {
        const out = B64.decode(B64.encode(ALL_BYTES));
        for (let i = 0; i < out.length; i++)
            assert.ok(out.charCodeAt(i) <= 0xff, "char " + i + " is not a byte");
    });
});

test.describe("base64 utf8", () => {
    // The encoder's output is one character per byte, which is exactly what
    // Buffer calls latin1, so the two can be compared directly.
    function expected(s) {
        return Buffer.from(s, "utf8").toString("latin1");
    }

    const cases = {
        empty: "",
        ascii: "hello, world 0123456789 ~!@#$%^&*()",
        "accented latin": "café naïve Ünderström ÿ",
        "two-byte edges": "߿",
        "three-byte edges": "ࠀ￿",
        greek: "αβγδε",
        cjk: "日本語のテキスト",
        hangul: "한국어",
        "emoji (surrogate pair)": "🎉",
        "emoji run": "🎉🚀🦀",
        "mixed": "ls ~/Downloads # 日本 café 🎉"
    };

    for (const name of Object.keys(cases))
        test.it("encodes " + name + " as UTF-8 bytes", () => {
            assert.strictEqual(B64.utf8(cases[name]), expected(cases[name]));
        });

    test.it("survives the base64 round trip as UTF-8", () => {
        const s = "café 日本 🎉";
        const bytes = B64.utf8(s);
        assert.strictEqual(B64.decode(B64.encode(bytes)), bytes);
        assert.strictEqual(Buffer.from(bytes, "latin1").toString("utf8"), s);
    });

    test.it("leaves every ASCII byte alone", () => {
        for (let i = 0; i < 0x80; i++) {
            const c = String.fromCharCode(i);
            assert.strictEqual(B64.utf8(c), c, "codepoint " + i);
        }
    });

    test.it("agrees with Buffer across the whole BMP", () => {
        // Sampled rather than exhaustive: one in every 37 code points, skipping
        // the surrogate range, which has no meaning on its own.
        for (let cp = 0; cp < 0x10000; cp += 37) {
            if (cp >= 0xd800 && cp <= 0xdfff)
                continue;
            const c = String.fromCharCode(cp);
            assert.strictEqual(B64.utf8(c), expected(c), "codepoint " + cp.toString(16));
        }
    });

    test.it("agrees with Buffer on astral code points", () => {
        for (const cp of [0x10000, 0x1f300, 0x1f600, 0x1f9ff, 0x10ffff]) {
            const c = String.fromCodePoint(cp);
            assert.strictEqual(B64.utf8(c), expected(c), "codepoint " + cp.toString(16));
        }
    });

    test.it("emits four bytes for one emoji, not two lots of three", () => {
        assert.strictEqual(B64.utf8("🎉").length, 4);
    });
});
