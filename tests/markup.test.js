const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/markup.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Markup = new Function(src + "\nreturn { sanitise, shorten };")();

const ALLOWED_TAG = /^<(\/?(b|i|u)|br)>$/;

function tagsIn(markup) {
    return markup.match(/<[^>]*>?/g) || [];
}

function balanced(markup) {
    const open = [];
    for (const tag of tagsIn(markup)) {
        if (tag === "<br>")
            continue;
        const name = tag.replace(/[<>/]/g, "");
        if (tag.startsWith("</")) {
            if (open.pop() !== name)
                return false;
        } else {
            open.push(name);
        }
    }
    return open.length === 0;
}

function assertSafe(markup) {
    for (const tag of tagsIn(markup))
        assert.match(tag, ALLOWED_TAG, `unexpected tag ${tag} in ${JSON.stringify(markup)}`);
    assert.ok(balanced(markup), `unbalanced ${JSON.stringify(markup)}`);
    assert.ok(!/&(?!(amp|lt|gt);)/.test(markup), `stray entity in ${JSON.stringify(markup)}`);
}

test.describe("sanitise", () => {
    test.it("passes plain text through", () => {
        assert.strictEqual(Markup.sanitise("Download finished"), "Download finished");
        assert.strictEqual(Markup.sanitise(""), "");
        assert.strictEqual(Markup.sanitise(undefined), "");
        assert.strictEqual(Markup.sanitise(null), "");
    });

    test.it("keeps bold, italic and underline", () => {
        assert.strictEqual(Markup.sanitise("<b>a</b> <i>b</i> <u>c</u>"), "<b>a</b> <i>b</i> <u>c</u>");
        assert.strictEqual(Markup.sanitise("<B>a</B>"), "<b>a</b>");
    });

    test.it("drops images in every spelling", () => {
        assert.strictEqual(Markup.sanitise("<img src=\"http://127.0.0.1:9/x.png\">"), "");
        assert.strictEqual(Markup.sanitise("<IMG SRC=http://127.0.0.1:9/x.png>"), "");
        assert.strictEqual(Markup.sanitise("a<img src='x>y' alt=\"z\"/>b"), "ab");
        assert.strictEqual(Markup.sanitise("<b><img src=x></b>"), "<b></b>");
        assert.strictEqual(Markup.sanitise("<img\nsrc=x>"), "");
    });

    test.it("shows links as their text", () => {
        assert.strictEqual(Markup.sanitise("<a href=\"https://example.org\">the page</a>"), "the page");
        assert.strictEqual(Markup.sanitise("<A HREF='x'><b>bold</b></A>"), "<b>bold</b>");
    });

    test.it("strips other tags and keeps their text", () => {
        assert.strictEqual(Markup.sanitise("<font color=red>x</font>"), "x");
        assert.strictEqual(Markup.sanitise("<span style=\"x\">y</span>"), "y");
        assert.strictEqual(Markup.sanitise("<p>one</p><h1>two</h1>"), "onetwo");
        assert.strictEqual(Markup.sanitise("<b/>x"), "x");
    });

    test.it("turns line breaks into br", () => {
        assert.strictEqual(Markup.sanitise("a\nb"), "a<br>b");
        assert.strictEqual(Markup.sanitise("a\r\nb\rc"), "a<br>b<br>c");
        assert.strictEqual(Markup.sanitise("a<br>b<br/>c<BR />d</br>e"), "a<br>b<br>c<br>de");
    });

    test.it("escapes bare angle brackets and ampersands", () => {
        assert.strictEqual(Markup.sanitise("a < b > c & d"), "a &lt; b &gt; c &amp; d");
        assert.strictEqual(Markup.sanitise("x<3"), "x&lt;3");
        assert.strictEqual(Markup.sanitise("<b-c>"), "&lt;b-c&gt;");
        assert.strictEqual(Markup.sanitise("</>"), "&lt;/&gt;");
    });

    test.it("decodes entities and escapes the result", () => {
        assert.strictEqual(Markup.sanitise("Tom &amp; Jerry"), "Tom &amp; Jerry");
        assert.strictEqual(Markup.sanitise("&lt;img src=x&gt;"), "&lt;img src=x&gt;");
        assert.strictEqual(Markup.sanitise("&#60;img src=x&#62;"), "&lt;img src=x&gt;");
        assert.strictEqual(Markup.sanitise("&#x3C;IMG&#x3e;"), "&lt;IMG&gt;");
        assert.strictEqual(Markup.sanitise("&quot;hi&quot; &apos;there&apos;"), "\"hi\" 'there'");
        assert.strictEqual(Markup.sanitise("a&nbsp;b"), "a b");
        assert.strictEqual(Markup.sanitise("&#128512;"), "😀");
        assert.strictEqual(Markup.sanitise("line&#10;next"), "line<br>next");
    });

    test.it("leaves unknown or broken entities as text", () => {
        assert.strictEqual(Markup.sanitise("&copy;"), "&amp;copy;");
        assert.strictEqual(Markup.sanitise("&#0;"), "&amp;#0;");
        assert.strictEqual(Markup.sanitise("&#xD800;"), "&amp;#xD800;");
        assert.strictEqual(Markup.sanitise("&#99999999;"), "&amp;#99999999;");
        assert.strictEqual(Markup.sanitise("& amp;"), "&amp; amp;");
        assert.strictEqual(Markup.sanitise("&amp"), "&amp;amp");
        assert.strictEqual(Markup.sanitise("&__proto__;"), "&amp;__proto__;");
    });

    test.it("closes unclosed tags and drops stray closers", () => {
        assert.strictEqual(Markup.sanitise("<b>bold"), "<b>bold</b>");
        assert.strictEqual(Markup.sanitise("<b><i>x"), "<b><i>x</i></b>");
        assert.strictEqual(Markup.sanitise("</b>stray"), "stray");
        assert.strictEqual(Markup.sanitise("<b>x</i>y"), "<b>xy</b>");
        assert.strictEqual(Markup.sanitise("<b><i>x</b>y</i>"), "<b><i>x</i></b>y");
    });

    test.it("treats a tag that never ends as text", () => {
        assert.strictEqual(Markup.sanitise("<img src=\"http://x/y.png"), "&lt;img src=\"http://x/y.png");
        assert.strictEqual(Markup.sanitise("<b"), "&lt;b");
        assert.strictEqual(Markup.sanitise("<b <i>x</i>"), "&lt;b <i>x</i>");
        assert.strictEqual(Markup.sanitise("<a href='x>y"), "&lt;a href='x&gt;y");
    });

    test.it("never lets anything but the kept tags through", () => {
        const alphabet = ["<", ">", "/", "&", ";", "#", "x", "3", "C", "\"", "'", " ", "=", "\n", "a", "b", "i", "u", "img", "IMG", "src", "br", "lt", "amp", "gt", "font", "http://h/"];
        let seed = 12345;
        const next = () => {
            seed = (seed * 1103515245 + 12345) & 0x7fffffff;
            return seed;
        };
        for (let round = 0; round < 3000; round++) {
            let text = "";
            const length = next() % 40;
            for (let k = 0; k < length; k++)
                text += alphabet[next() % alphabet.length];
            const clean = Markup.sanitise(text);
            assertSafe(clean);
            assert.strictEqual(Markup.sanitise(clean), clean, `not stable for ${JSON.stringify(text)}`);
        }
    });
});

test.describe("shorten", () => {
    test.it("returns markup that fits unchanged", () => {
        assert.strictEqual(Markup.shorten("<b>short</b>", 10), "<b>short</b>");
        assert.strictEqual(Markup.shorten("a &amp; b", 5), "a &amp; b");
    });

    test.it("counts what is shown, not the markup", () => {
        assert.strictEqual(Markup.shorten("<b>abcdefghij</b>", 10), "<b>abcdefghij</b>");
        assert.strictEqual(Markup.shorten("&amp;&amp;&amp;&amp;", 4), "&amp;&amp;&amp;&amp;");
    });

    test.it("cuts at a word and closes what it left open", () => {
        assert.strictEqual(Markup.shorten("<b>hello world again</b>", 13), "<b>hello world…</b>");
        assert.strictEqual(Markup.shorten("<i>one</i> <b>two three four</b>", 14), "<i>one</i> <b>two three…</b>");
    });

    test.it("cuts mid-word when the last space is too early", () => {
        assert.strictEqual(Markup.shorten("a bcdefghijkl", 10), "a bcdefghi…");
    });

    test.it("never splits an entity or a tag", () => {
        const folded = Markup.shorten("x &lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;&lt;", 5);
        assert.strictEqual(folded, "x &lt;&lt;&lt;…");
        const tagged = Markup.shorten("ab<b>cd</b>ef<i>gh</i>ij", 5);
        assert.strictEqual(tagged, "ab<b>cd</b>e…");
    });

    test.it("drops trailing breaks before the ellipsis", () => {
        assert.strictEqual(Markup.shorten("abcdefgh<br><br>ijklmnop", 10), "abcdefgh…");
    });

    test.it("keeps sanitised output safe", () => {
        const body = Markup.sanitise("<b>Build <i>finished</i></b> &amp; <u>deployed</u> to production at 12:00\nsee <a href=x>logs</a>");
        for (let limit = 1; limit < 80; limit++)
            assertSafe(Markup.shorten(body, limit));
    });
});
