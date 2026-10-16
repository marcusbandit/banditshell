const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Dev = lib("services/dev-utilities.js", ["utf8Bytes", "utf8Text", "hexOf", "base64Encode", "base64Decode", "sha256", "sha1", "md5", "readBytes", "pickIndex", "pickInteger", "drawPassword", "strengthBits", "uuidFrom", "drawKey", "draw", "urlEncode", "urlDecode", "htmlEscape", "htmlUnescape", "words", "convertCase", "counts", "jsonProblem", "jsonFormat", "jwtRead", "epochRead", "isoText", "relative", "devAsk", "answers", "PHRASES", "CHARACTER_SETS"]);

const text = s => Dev.utf8Bytes(s);
const NOW = Date.UTC(2026, 9, 16, 10, 0);

function pool(n, seed) {
    const out = [];
    let x = seed || 7;
    for (let i = 0; i < n; i++) {
        x = (x * 1103515245 + 12345) % 2147483648;
        out.push(x >> 16 & 255);
    }
    return out;
}

function b64url(object) {
    return Buffer.from(JSON.stringify(object)).toString("base64url");
}

test.describe("utf8", () => {
    test.it("encodes like Buffer, astral characters included", () => {
        for (const s of ["", "abc", "æøå", "€", "😀 hi", "a\u0000b", "日本語"])
            assert.deepStrictEqual(Dev.utf8Bytes(s), Array.from(Buffer.from(s, "utf8")), s);
    });

    test.it("decodes valid bytes and refuses broken ones", () => {
        for (const s of ["", "abc", "æøå", "😀 hi", "日本語"])
            assert.strictEqual(Dev.utf8Text(Array.from(Buffer.from(s))), s);
        assert.strictEqual(Dev.utf8Text([0xff]), null);
        assert.strictEqual(Dev.utf8Text([0xc3]), null);
        assert.strictEqual(Dev.utf8Text([0xc0, 0x80]), null);
        assert.strictEqual(Dev.utf8Text([0xed, 0xa0, 0x80]), null);
        assert.strictEqual(Dev.utf8Text([0xe2, 0x28, 0xa1]), null);
    });
});

test.describe("base64", () => {
    test.it("encodes what Buffer encodes", () => {
        for (const s of ["", "f", "fo", "foo", "foob", "fooba", "foobar", "hello world", "æøå 😀"])
            assert.strictEqual(Dev.base64Encode(text(s)), Buffer.from(s).toString("base64"), s);
    });

    test.it("decodes padded, unpadded and url-safe text", () => {
        assert.deepStrictEqual(Dev.base64Decode("aGVsbG8="), text("hello"));
        assert.deepStrictEqual(Dev.base64Decode("aGVsbG8"), text("hello"));
        assert.deepStrictEqual(Dev.base64Decode("aGVs bG8="), text("hello"));
        assert.deepStrictEqual(Dev.base64Decode("-_8"), [0xfb, 0xff]);
        assert.deepStrictEqual(Dev.base64Decode("+/8="), [0xfb, 0xff]);
    });

    test.it("refuses what is not base64", () => {
        for (const s of ["a", "abcde", "ab!c", "aGVsbG8==x", "aGVsbG8=="])
            assert.strictEqual(Dev.base64Decode(s), null, s);
    });

    test.it("round-trips random bytes", () => {
        for (let n = 0; n < 70; n++) {
            const bytes = pool(n, n + 1);
            assert.deepStrictEqual(Dev.base64Decode(Dev.base64Encode(bytes)), bytes);
        }
    });
});

test.describe("hashes", () => {
    test.it("match the published vectors", () => {
        assert.strictEqual(Dev.sha256(text("")), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
        assert.strictEqual(Dev.sha256(text("abc")), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        assert.strictEqual(Dev.sha256(text("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")), "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
        assert.strictEqual(Dev.sha1(text("")), "da39a3ee5e6b4b0d3255bfef95601890afd80709");
        assert.strictEqual(Dev.sha1(text("abc")), "a9993e364706816aba3e25717850c26c9cd0d89d");
        assert.strictEqual(Dev.sha1(text("The quick brown fox jumps over the lazy dog")), "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12");
        assert.strictEqual(Dev.md5(text("")), "d41d8cd98f00b204e9800998ecf8427e");
        assert.strictEqual(Dev.md5(text("abc")), "900150983cd24fb0d6963f7d28e17f72");
        assert.strictEqual(Dev.md5(text("message digest")), "f96b697d7cb7938d525a2f31aaf161d0");
        assert.strictEqual(Dev.md5(text("The quick brown fox jumps over the lazy dog")), "9e107d9d372bb6826bd81d3542a419d6");
    });

    test.it("agree with node across every block boundary", () => {
        for (let n = 0; n <= 200; n++) {
            const bytes = pool(n, 3 * n + 11);
            const buffer = Buffer.from(bytes);
            assert.strictEqual(Dev.sha256(bytes), crypto.createHash("sha256").update(buffer).digest("hex"), `sha256 ${n}`);
            assert.strictEqual(Dev.sha1(bytes), crypto.createHash("sha1").update(buffer).digest("hex"), `sha1 ${n}`);
            assert.strictEqual(Dev.md5(bytes), crypto.createHash("md5").update(buffer).digest("hex"), `md5 ${n}`);
        }
    });

    test.it("hash a long text", () => {
        const long = "æ".repeat(5000);
        assert.strictEqual(Dev.sha256(text(long)), crypto.createHash("sha256").update(long, "utf8").digest("hex"));
    });
});

test.describe("random draws", () => {
    test.it("reads od output", () => {
        assert.deepStrictEqual(Dev.readBytes("  12 255   0\n   7\n"), [12, 255, 0, 7]);
        assert.deepStrictEqual(Dev.readBytes(""), []);
    });

    test.it("rejects bytes that would bias the pick", () => {
        assert.deepStrictEqual(Dev.pickIndex([255, 251, 3], 0, 10), { value: 3, next: 3 });
        assert.deepStrictEqual(Dev.pickIndex([249], 0, 10), { value: 9, next: 1 });
        assert.strictEqual(Dev.pickIndex([255], 0, 10), null);
    });

    test.it("picks integers in range, with enough bytes for wide ranges", () => {
        assert.deepStrictEqual(Dev.pickInteger([250, 199], 0, 1, 100), { value: 100, next: 2 });
        const wide = Dev.pickInteger(pool(64, 5), 0, 1, 1e12);
        assert.ok(wide.value >= 1 && wide.value <= 1e12);
        assert.strictEqual(wide.next % 5, 0);
        const negative = Dev.pickInteger([10], 0, -5, 5);
        assert.strictEqual(negative.value, 5);
    });

    test.it("makes v4 uuids", () => {
        const id = Dev.uuidFrom(pool(16, 9));
        assert.match(id, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
        assert.strictEqual(Dev.uuidFrom(new Array(16).fill(255)), "ffffffff-ffff-4fff-bfff-ffffffffffff");
    });

    test.it("draws passwords that use every class", () => {
        const got = Dev.drawPassword(pool(600, 21), 0, 20, "full");
        assert.strictEqual(got.value.length, 20);
        for (const chars of Dev.CHARACTER_SETS.full)
            assert.ok([...got.value].some(c => chars.includes(c)), chars);
        const simple = Dev.drawPassword(pool(600, 22), 0, 32, "simple").value;
        assert.match(simple, /^[A-Za-z0-9]{32}$/);
        assert.match(Dev.drawPassword(pool(100, 23), 0, 6, "digits").value, /^\d{6}$/);
        assert.strictEqual(Dev.drawPassword([1, 2, 3], 0, 20, "full"), null);
    });

    test.it("never puts quotes, spaces or backslashes in a password", () => {
        assert.doesNotMatch(Dev.CHARACTER_SETS.full.join(""), /["'`\\\s|]/);
    });

    test.it("reports strength in bits", () => {
        assert.strictEqual(Dev.strengthBits(20, "full"), 129);
        assert.strictEqual(Dev.strengthBits(20, "simple"), 119);
        assert.strictEqual(Dev.strengthBits(6, "digits"), 19);
    });

    test.it("keys and draws each kind", () => {
        const bytes = pool(1024, 31);
        assert.strictEqual(Dev.drawKey({ tool: "password", length: 0, set: "full" }, 24), "password:24:full");
        assert.strictEqual(Dev.drawKey({ tool: "uuid", count: 3 }, 20), "uuid:3");
        assert.strictEqual(Dev.drawKey({ tool: "json" }, 20), "");
        assert.strictEqual(Dev.draw("uuid:3", bytes, 0).value.length, 3);
        assert.strictEqual(Dev.draw("uuid:3", bytes, 0).next, 48);
        const dice = Dev.draw("dice:3:6", bytes, 0).value;
        assert.strictEqual(dice.length, 3);
        assert.ok(dice.every(n => n >= 1 && n <= 6));
        assert.ok(["Heads", "Tails"].includes(Dev.draw("coin", bytes, 0).value));
        const n = Dev.draw("random:1:100", bytes, 0).value;
        assert.ok(n >= 1 && n <= 100);
        assert.strictEqual(Dev.draw("uuid:2", bytes.slice(0, 20), 0), null);
    });
});

test.describe("text tools", () => {
    test.it("percent encodes and decodes", () => {
        assert.strictEqual(Dev.urlEncode("a b&c"), "a%20b%26c");
        assert.strictEqual(Dev.urlEncode("it's (fine)!*"), "it%27s%20%28fine%29%21%2A");
        assert.strictEqual(Dev.urlDecode("a%20b"), "a b");
        assert.strictEqual(Dev.urlDecode("%E2%82%AC"), "€");
        assert.strictEqual(Dev.urlDecode("%E2%82"), null);
    });

    test.it("escapes and unescapes html", () => {
        assert.strictEqual(Dev.htmlEscape("<b>\"Tom\" & 'Jerry'</b>"), "&lt;b&gt;&quot;Tom&quot; &amp; &#39;Jerry&#39;&lt;/b&gt;");
        assert.strictEqual(Dev.htmlUnescape("&lt;b&gt; &amp;amp; &#65;&#x42; &copy; &nope; &#xD800;"), "<b> &amp; AB © &nope; &#xD800;");
    });

    test.it("splits words across camel case, acronyms and separators", () => {
        assert.deepStrictEqual(Dev.words("XMLHttpRequest"), ["XML", "Http", "Request"]);
        assert.deepStrictEqual(Dev.words("my_title-here.now"), ["my", "title", "here", "now"]);
        assert.deepStrictEqual(Dev.words("version2Final"), ["version", "2", "Final"]);
    });

    test.it("converts between cases", () => {
        const cases = {
            camel: "myTitleHere",
            pascal: "MyTitleHere",
            snake: "my_title_here",
            constant: "MY_TITLE_HERE",
            kebab: "my-title-here",
            dot: "my.title.here",
            upper: "MY TITLE HERE",
            lower: "my title here",
            title: "My Title Here",
            sentence: "My title here",
            slug: "my-title-here"
        };
        for (const id in cases)
            assert.strictEqual(Dev.convertCase(id, "My Title Here"), cases[id], id);
        assert.strictEqual(Dev.convertCase("snake", "XMLHttpRequest"), "xml_http_request");
        assert.strictEqual(Dev.convertCase("camel", "some-kebab_snake words"), "someKebabSnakeWords");
        assert.strictEqual(Dev.convertCase("title", "the lord of the rings"), "The Lord of the Rings");
        assert.strictEqual(Dev.convertCase("slug", "Æble på Øen: Crème Brûlée!"), "aeble-pa-oen-creme-brulee");
    });

    test.it("counts characters, words, lines and bytes", () => {
        assert.deepStrictEqual(Dev.counts("😀 hi"), { characters: 4, words: 2, lines: 1, bytes: 7 });
        assert.deepStrictEqual(Dev.counts("one\ntwo three\n"), { characters: 14, words: 3, lines: 3, bytes: 14 });
        assert.deepStrictEqual(Dev.counts(""), { characters: 0, words: 0, lines: 0, bytes: 0 });
    });
});

test.describe("json", () => {
    test.it("formats and minifies", () => {
        const got = Dev.jsonFormat("{\"a\":1,\"b\":[1,2]}", false);
        assert.strictEqual(got.text, "{\n  \"a\": 1,\n  \"b\": [\n    1,\n    2\n  ]\n}");
        assert.strictEqual(got.other, "{\"a\":1,\"b\":[1,2]}");
        assert.strictEqual(got.shape, "2 keys");
        assert.strictEqual(Dev.jsonFormat(" [1, 2, 3] ", true).text, "[1,2,3]");
        assert.strictEqual(Dev.jsonFormat("[1]", true).shape, "1 item");
    });

    test.it("says where it broke", () => {
        const at = s => {
            const p = Dev.jsonProblem(s);
            return p && [p.line, p.column, p.expected, p.found];
        };
        assert.deepStrictEqual(at("{\"a\": 1,, \"b\": 2}"), [1, 9, "a quoted key", ","]);
        assert.deepStrictEqual(at("{\n  \"a\": 1\n  \"b\": 2\n}"), [3, 3, "a comma or }", "\""]);
        assert.deepStrictEqual(at("[1, 2,]"), [1, 7, "a value after the comma", "]"]);
        assert.deepStrictEqual(at("{\"a\": 1,}"), [1, 9, "a key after the comma", "}"]);
        assert.deepStrictEqual(at("{'a': 1}"), [1, 2, "a quoted key", "'"]);
        assert.deepStrictEqual(at("{\"a\": tru}"), [1, 7, "a value", "t"]);
        assert.deepStrictEqual(at("{\"a\": \"x"), [1, 9, "a closing quote", "the end"]);
        assert.deepStrictEqual(at("{\"a\": 1} {"), [1, 10, "nothing more", "{"]);
        assert.deepStrictEqual(at("[01]"), [1, 3, "a comma or ]", "1"]);
        assert.deepStrictEqual(at(""), [1, 1, "a value", "the end"]);
    });

    test.it("finds nothing wrong with what JSON.parse accepts", () => {
        const samples = [{ a: [1, 2, { b: null }], "é": "x\"y\\z\n", n: -1.5e-7 }, [], {}, "text", 12, true, null, [[[[]]]]];
        for (const sample of samples)
            for (const spaced of [0, 2])
                assert.strictEqual(Dev.jsonProblem(JSON.stringify(sample, null, spaced)), null, JSON.stringify(sample));
    });

    test.it("answers with the error and a pointer for the peek", () => {
        const rows = Dev.answers({ tool: "json", minify: false, input: "{\"a\": 1,, \"b\": 2}" }, "", undefined, NOW);
        assert.strictEqual(rows[0].label, "Invalid JSON at 1:9");
        assert.strictEqual(rows[0].detail, "expected a quoted key · found ,");
        assert.strictEqual(rows[0].peek, "{\"a\": 1,, \"b\": 2}\n        ^");
        assert.ok(rows[0].failed);
    });

    test.it("keeps the pointer in view on a long minified line", () => {
        const long = `[${"1,".repeat(200)}x]`;
        const peek = Dev.answers({ tool: "json", minify: false, input: long }, "", undefined, NOW)[0].peek.split("\n");
        assert.ok(peek[0].length <= 73);
        assert.strictEqual(peek[0].charAt(peek[1].length - 1), "x");
    });
});

test.describe("jwt", () => {
    const header = { alg: "HS256", typ: "JWT" };
    const payload = { sub: "42", name: "Ada", iat: 1700000000, exp: 1900000000 };
    const token = `${b64url(header)}.${b64url(payload)}.c2lnbmF0dXJl`;

    test.it("decodes the header and payload without verifying", () => {
        const got = Dev.jwtRead(token);
        assert.deepStrictEqual(got.header, header);
        assert.deepStrictEqual(got.payload, payload);
        assert.strictEqual(got.algorithm, "HS256");
        assert.deepStrictEqual(got.times.map(t => [t.claim, t.ms]), [["exp", 1900000000000], ["iat", 1700000000000]]);
        assert.deepStrictEqual(Dev.jwtRead(`Bearer ${token}`).payload, payload);
    });

    test.it("refuses what is not a token", () => {
        for (const s of ["", "abc", "a.b.c", `${b64url(header)}.notjson.x`, `${b64url([1])}.${b64url(payload)}.x`])
            assert.strictEqual(Dev.jwtRead(s), null, s);
    });

    test.it("answers with payload, header and dated claims", () => {
        const rows = Dev.answers(Dev.devAsk(`jwt ${token}`), "", undefined, NOW);
        assert.deepStrictEqual(rows.map(r => r.id), ["jwt:payload", "jwt:header", "jwt:exp", "jwt:iat"]);
        assert.strictEqual(rows[0].detail, "payload · HS256 · not verified");
        assert.strictEqual(rows[2].detail, "exp · in 3 years");
        assert.strictEqual(rows[2].copy, "2030-03-17T17:46:40Z");
        assert.strictEqual(rows[3].detail, "iat · 2 years ago");
        assert.ok(rows[0].peek.includes("\"alg\": \"HS256\""));
    });

    test.it("marks an expired token", () => {
        const old = `${b64url(header)}.${b64url({ exp: 1600000000 })}.`;
        const rows = Dev.answers({ tool: "jwt", input: old }, "", undefined, NOW);
        assert.strictEqual(rows[0].detail, "payload · HS256 · unsigned");
        assert.ok(rows.find(r => r.id === "jwt:exp").expired);
    });
});

test.describe("epoch", () => {
    test.it("reads seconds, milliseconds and finer units", () => {
        assert.deepStrictEqual(Dev.epochRead("1700000000"), { ms: 1700000000000, unit: "seconds" });
        assert.deepStrictEqual(Dev.epochRead("1700000000000"), { ms: 1700000000000, unit: "milliseconds" });
        assert.deepStrictEqual(Dev.epochRead("1700000000000000"), { ms: 1700000000000, unit: "microseconds" });
        assert.deepStrictEqual(Dev.epochRead("1700000000.5"), { ms: 1700000000500, unit: "seconds" });
        assert.strictEqual(Dev.epochRead("abc"), null);
        assert.strictEqual(Dev.epochRead("1700000000000.5"), null);
    });

    test.it("writes iso time and relative spans", () => {
        assert.strictEqual(Dev.isoText(1700000000000), "2023-11-14T22:13:20Z");
        assert.strictEqual(Dev.isoText(1700000000123), "2023-11-14T22:13:20.123Z");
        assert.strictEqual(Dev.relative(NOW + 90 * 60000, NOW), "in 1 hour");
        assert.strictEqual(Dev.relative(NOW - 3 * 86400000, NOW), "3 days ago");
        assert.strictEqual(Dev.relative(NOW, NOW), "now");
    });

    test.it("answers now in seconds, milliseconds and iso", () => {
        const rows = Dev.answers({ tool: "now", explicit: true }, "", undefined, 1700000000123);
        assert.deepStrictEqual(rows.map(r => r.label), ["1700000000", "1700000000123", "2023-11-14T22:13:20Z"]);
    });
});

test.describe("devAsk", () => {
    const ask = t => Dev.devAsk(t);

    test.it("reads the generator heads", () => {
        assert.deepStrictEqual(ask("uuid"), { tool: "uuid", count: 1, explicit: true });
        assert.deepStrictEqual(ask("UUID 5"), { tool: "uuid", count: 5, explicit: true });
        assert.strictEqual(ask("new guid").tool, "uuid");
        assert.strictEqual(ask("uuid4").count, 1);
        assert.deepStrictEqual(ask("password 20"), { tool: "password", length: 20, set: "full", explicit: true });
        assert.deepStrictEqual(ask("password 20 simple"), { tool: "password", length: 20, set: "simple", explicit: true });
        assert.strictEqual(ask("password no symbols 16").set, "simple");
        assert.strictEqual(ask("password 32 characters").length, 32);
        assert.strictEqual(ask("24 character password").length, 24);
        assert.strictEqual(ask("generate a password").explicit, true);
        assert.deepStrictEqual(ask("password"), { tool: "password", length: 0, set: "full", explicit: false });
        assert.deepStrictEqual(ask("pin 6"), { tool: "password", length: 6, set: "digits", pin: true, explicit: true });
        assert.deepStrictEqual(ask("random 1 100"), { tool: "random", low: 1, high: 100, explicit: true });
        assert.deepStrictEqual(ask("random 1-6"), { tool: "random", low: 1, high: 6, explicit: true });
        assert.deepStrictEqual(ask("random number between 10 and 20"), { tool: "random", low: 10, high: 20, explicit: true });
        assert.deepStrictEqual(ask("random 50"), { tool: "random", low: 1, high: 50, explicit: true });
        assert.deepStrictEqual(ask("random -5 5"), { tool: "random", low: -5, high: 5, explicit: true });
        assert.deepStrictEqual(ask("pick a number between 1 and 10"), { tool: "random", low: 1, high: 10, explicit: true });
        assert.deepStrictEqual(ask("roll a die"), { tool: "dice", count: 1, sides: 6, explicit: true });
        assert.deepStrictEqual(ask("roll 3d6"), { tool: "dice", count: 3, sides: 6, explicit: true });
        assert.deepStrictEqual(ask("roll d20"), { tool: "dice", count: 1, sides: 20, explicit: true });
        assert.strictEqual(ask("d20").explicit, false);
        assert.deepStrictEqual(ask("flip a coin"), { tool: "coin", explicit: true });
        assert.strictEqual(ask("heads or tails?").tool, "coin");
    });

    test.it("reads the converters", () => {
        assert.deepStrictEqual(ask("base64 hello"), { tool: "base64", decode: false, either: true, input: "hello", explicit: true });
        assert.strictEqual(ask("base64 decode aGVsbG8=").decode, true);
        assert.strictEqual(ask("decode base64 aGVsbG8=").decode, true);
        assert.strictEqual(ask("b64 -d aGVsbG8=").decode, true);
        assert.strictEqual(ask("base64").input, null);
        assert.deepStrictEqual(ask("url encode a b&c"), { tool: "url", decode: false, input: "a b&c", explicit: true });
        assert.strictEqual(ask("urldecode a%20b").decode, true);
        assert.strictEqual(ask("decode url a%20b").decode, true);
        assert.deepStrictEqual(ask("html escape <b>"), { tool: "html", decode: false, input: "<b>", explicit: true });
        assert.strictEqual(ask("unescape html &lt;").decode, true);
        assert.deepStrictEqual(ask("sha256 text"), { tool: "hash", algorithms: ["sha256"], input: "text", explicit: true });
        assert.deepStrictEqual(ask("sha-1 text").algorithms, ["sha1"]);
        assert.deepStrictEqual(ask("md5sum text").algorithms, ["md5"]);
        assert.deepStrictEqual(ask("hash text").algorithms, ["sha256", "sha1", "md5"]);
        assert.deepStrictEqual(ask("json"), { tool: "json", minify: false, input: null, explicit: true });
        assert.strictEqual(ask("json min").minify, true);
        assert.strictEqual(ask("minify json").minify, true);
        assert.strictEqual(ask("json {\"a\":1}").input, "{\"a\":1}");
        assert.deepStrictEqual(ask("jwt"), { tool: "jwt", input: null, explicit: true });
        assert.deepStrictEqual(ask("jwt decode"), { tool: "jwt", input: null, explicit: true });
    });

    test.it("reads case, time and count asks", () => {
        assert.deepStrictEqual(ask("snake case My Title"), { tool: "case", cases: ["snake"], input: "My Title", explicit: true });
        assert.deepStrictEqual(ask("kebab-case My Title").cases, ["kebab"]);
        assert.deepStrictEqual(ask("SCREAMING_CASE my title").cases, ["constant"]);
        assert.deepStrictEqual(ask("title case").input, null);
        assert.deepStrictEqual(ask("uppercase hello").cases, ["upper"]);
        assert.deepStrictEqual(ask("to lower HELLO").cases, ["lower"]);
        assert.deepStrictEqual(ask("slug My Post"), { tool: "case", cases: ["slug"], input: "My Post", explicit: true });
        assert.strictEqual(ask("upper hello").explicit, false);
        assert.strictEqual(ask("cases hello world").cases.length, 11);
        assert.deepStrictEqual(ask("epoch 1700000000"), { tool: "epoch", ms: 1700000000000, unit: "seconds", explicit: true });
        assert.strictEqual(ask("@1700000000").explicit, true);
        assert.strictEqual(ask("date 1700000000").ms, 1700000000000);
        assert.deepStrictEqual(ask("1700000000"), { tool: "epoch", ms: 1700000000000, unit: "seconds", explicit: false });
        assert.strictEqual(ask("1700000000000").unit, "milliseconds");
        assert.deepStrictEqual(ask("timestamp"), { tool: "now", explicit: true });
        assert.deepStrictEqual(ask("unix time"), { tool: "now", explicit: true });
        assert.deepStrictEqual(ask("now"), { tool: "now", explicit: false });
        assert.deepStrictEqual(ask("count words a b c"), { tool: "count", only: "words", input: "a b c", explicit: true });
        assert.strictEqual(ask("word count a b").only, "words");
        assert.strictEqual(ask("how many characters in hello").only, "characters");
        assert.strictEqual(ask("count lines").input, null);
        assert.strictEqual(ask("count words in hello world").input, "hello world");
        assert.strictEqual(ask("unix").explicit, false);
    });

    test.it("keeps plain searches out, or only ambient", () => {
        for (const t of ["firefox", "password manager", "passwords", "json viewer", "random access memories", "uuidgen", "epoch times", "now playing", "base camp", "date 2026", "time machine", "kill bill", "lower the volume", "upper volume", "pin", "coin market cap", "123456789", "9999999999999"])
            assert.strictEqual(ask(t), null, t);
        for (const t of ["count of monte cristo", "case study", "hash browns", "lower east side", "coin", "d6", "password", "random", "now", "count", "1700000000"])
            assert.strictEqual(ask(t).explicit, false, t);
    });
});

test.describe("answers", () => {
    test.it("base64 offers the decoded text when the input already looks encoded", () => {
        const rows = Dev.answers(Dev.devAsk("base64 aGVsbG8gd29ybGQ="), "", undefined, NOW);
        assert.deepStrictEqual(rows.map(r => r.label), ["YUdWc2JHOGdkMjl5YkdRPQ==", "hello world"]);
        assert.deepStrictEqual(Dev.answers(Dev.devAsk("base64 hello"), "", undefined, NOW).map(r => r.label), ["aGVsbG8="]);
    });

    test.it("decodes binary base64 to hex and flags bad input", () => {
        assert.strictEqual(Dev.answers(Dev.devAsk("base64 decode //79"), "", undefined, NOW)[0].label, "fffefd");
        assert.ok(Dev.answers(Dev.devAsk("base64 decode a!b"), "", undefined, NOW)[0].failed);
    });

    test.it("takes the clipboard when nothing follows the head", () => {
        const rows = Dev.answers(Dev.devAsk("sha256"), "abc", undefined, NOW);
        assert.strictEqual(rows[0].label, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
        assert.strictEqual(rows[0].detail, "SHA-256 · clipboard · 3 bytes");
        assert.deepStrictEqual(Dev.answers(Dev.devAsk("json"), "", undefined, NOW), []);
    });

    test.it("formats clipboard json and offers the other shape", () => {
        const rows = Dev.answers(Dev.devAsk("json"), "{\"a\":[1,2]}", undefined, NOW);
        assert.strictEqual(rows[0].copy, "{\n  \"a\": [\n    1,\n    2\n  ]\n}");
        assert.strictEqual(rows[0].alternate, "{\"a\":[1,2]}");
        assert.strictEqual(rows[0].detail, "clipboard · 1 key · 6 lines");
    });

    test.it("marks drawn values for another draw and keeps passwords secret", () => {
        const password = Dev.answers(Dev.devAsk("password 20"), "", "abcdefghijKLMNOP12!@", NOW)[0];
        assert.ok(password.secret && password.redraw);
        assert.strictEqual(password.detail, "20 characters · 129 bits");
        assert.strictEqual(Dev.answers(Dev.devAsk("pin 4"), "", "1234", NOW)[0].detail, "4 digits · 13 bits");
        assert.deepStrictEqual(Dev.answers(Dev.devAsk("random 0 5"), "", 0, NOW).map(r => r.label), ["0"]);
        assert.deepStrictEqual(Dev.answers(Dev.devAsk("roll 2d6"), "", [3, 4], NOW).map(r => [r.label, r.detail]), [["7", "2d6 · 3 + 4"]]);
        assert.deepStrictEqual(Dev.answers(Dev.devAsk("uuid"), "", undefined, NOW), []);
    });

    test.it("counts with the asked measure first", () => {
        assert.deepStrictEqual(Dev.answers(Dev.devAsk("count words the quick fox"), "", undefined, NOW).map(r => [r.label, r.detail, r.copy]), [["3 words", "13 characters · 1 line · 13 bytes", "3"]]);
    });

    test.it("labels every case", () => {
        const rows = Dev.answers(Dev.devAsk("cases Hello World"), "", undefined, NOW);
        assert.strictEqual(rows.length, 11);
        assert.deepStrictEqual(rows[0], { id: "case:camel", label: "helloWorld", detail: "camel case", copy: "helloWorld" });
    });

    test.it("gives epoch rows a moment to format", () => {
        const rows = Dev.answers(Dev.devAsk("1700000000"), "", undefined, NOW);
        assert.strictEqual(rows[0].when, 1700000000000);
        assert.strictEqual(rows[0].detail, "seconds · 2 years ago");
        assert.strictEqual(rows[1].label, "2023-11-14T22:13:20Z");
    });
});

test.describe("phrases", () => {
    test.it("every phrase head starts something devAsk reads", () => {
        for (const phrase of Dev.PHRASES)
            for (const pick of phrase.picks) {
                const said = `${phrase.head}${pick}`.trim();
                if (pick && !said.endsWith(" "))
                    assert.ok(Dev.devAsk(said) || /^(?:sha256|sha1|md5|jwt|slug|case|snake case|camel case|kebab case|title case)$/.test(said), said);
            }
    });
});
