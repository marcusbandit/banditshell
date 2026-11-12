const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Page = lib("services/clipboard-page.js", ["FILTERS", "SHAPES", "shapeOf", "passes", "dayOf", "sections", "counts", "linkParts", "emailOf", "facts", "colourOf"]);
const Colours = lib("services/colours.js", ["parseColour", "FORMS"]);

const NOW = new Date(2026, 10, 12, 15, 0).getTime();
const at = (day, hour = 12, minute = 0) => new Date(2026, 10, day, hour, minute).getTime();
const entry = (kind, text, extra = {}) => Object.assign({ kind, text, file: "", paths: [] }, extra);
const shape = (kind, text, extra) => Page.shapeOf(entry(kind, text, extra), Colours.parseColour);
const item = (id, recorded, pinned = false) => ({ id, entry: { recorded, pinned } });
const row = (rows, label) => (rows.find(r => r.label === label) || {}).value;
const headers = list => list.map(x => (x.header ? x.title : x.id));

test("a copied #FF6363 shows as a colour, and so does rgb(255, 99, 99)", () => {
    assert.strictEqual(shape("colour", "#FF6363"), "colour");
    assert.strictEqual(shape("text", "rgb(255, 99, 99)"), "colour");
});
test("hsl(0, 100%, 69%) shows as a colour", () => assert.strictEqual(shape("text", "hsl(0, 100%, 69%)"), "colour"));
test("a bare hex code like ff6363 shows as a colour", () => assert.strictEqual(shape("colour", "ff6363"), "colour"));
test("bare digits are not a colour", () => assert.notStrictEqual(shape("colour", "123"), "colour"));
test("an address like hello@example.com shows as an email", () => assert.strictEqual(shape("text", "hello@example.com"), "email"));
test("a mailto link shows as an email", () => assert.strictEqual(shape("url", "mailto:hello@example.com"), "email"));
test("a web address shows as a link", () => assert.strictEqual(shape("url", "https://example.com/a"), "link"));
test("JSON, code and dictation keep their own shapes", () => {
    assert.strictEqual(shape("json", '{"a": 1}'), "json");
    assert.strictEqual(shape("code", "const a = 1;"), "code");
    assert.strictEqual(shape("speech", "remind me at noon"), "speech");
});
test("a plain sentence shows as text", () => assert.strictEqual(shape("text", "Meet at noon tomorrow"), "text"));
test("a single copied image shows as an image, and two show as files", () => {
    assert.strictEqual(shape("image", "", { file: "/example/a.png" }), "image");
    assert.strictEqual(shape("image", "", { paths: ["/example/a.png", "/example/b.png"] }), "files");
});
test("one copied file shows as a file, and three documents show as files", () => {
    assert.strictEqual(shape("files", "", { paths: ["/example/a.pdf"] }), "file");
    assert.strictEqual(shape("files", "/example/x.png"), "file");
    assert.strictEqual(shape("document", "", { paths: ["/example/a.pdf", "/example/b.pdf", "/example/c.pdf"] }), "files");
});

test("the All filter and an empty filter let every entry through", () => {
    assert.ok(Page.passes("image", "all"));
    assert.ok(Page.passes("image", ""));
});
test("the Links filter takes links and email addresses", () => {
    assert.ok(Page.passes("link", "link"));
    assert.ok(Page.passes("email", "link"));
});
test("the Text filter takes text and dictation", () => {
    assert.ok(Page.passes("text", "text"));
    assert.ok(Page.passes("speech", "text"));
});
test("the Code filter takes code and JSON", () => {
    assert.ok(Page.passes("code", "code"));
    assert.ok(Page.passes("json", "code"));
});
test("the Images filter rejects text", () => assert.ok(!Page.passes("text", "image")));

test("a copy from earlier today is listed under Today", () => assert.strictEqual(Page.dayOf(at(12, 8), NOW), "Today"));
test("a copy from 23:59 the day before is listed under Yesterday", () => assert.strictEqual(Page.dayOf(at(11, 23, 59), NOW), "Yesterday"));
test("a copy from three days back is listed under This week", () => assert.strictEqual(Page.dayOf(at(9), NOW), "This week"));
test("a copy from ten days back is listed under This month", () => assert.strictEqual(Page.dayOf(at(2), NOW), "This month"));
test("a copy from sixty days back is listed under Older", () => assert.strictEqual(Page.dayOf(new Date(2026, 8, 13, 12).getTime(), NOW), "Older"));

test("pinned copies sit first under Pinned, even when they are old", () => {
    const list = [item("a", at(12, 9)), item("p", at(1), true)];
    assert.deepStrictEqual(headers(Page.sections(list, NOW)), ["Pinned", "p", "Today", "a"]);
});
test("each day gets one header, and a new header only when the day changes", () => {
    const list = [item("a", at(12, 9)), item("b", at(12, 8)), item("c", at(11)), item("d", at(11, 7))];
    assert.deepStrictEqual(headers(Page.sections(list, NOW)), ["Today", "a", "b", "Yesterday", "c", "d"]);
});
test("an empty history gives no sections", () => assert.deepStrictEqual(Page.sections([], NOW), []));

test("an empty copy has no words or lines", () => assert.deepStrictEqual(Page.counts(""), { characters: 0, words: 0, lines: 0 }));
test("two lines of three words count as 13 characters, 3 words and 2 lines", () => assert.deepStrictEqual(Page.counts("one two\nthree"), { characters: 13, words: 3, lines: 2 }));
test("trailing newlines do not add lines", () => assert.strictEqual(Page.counts("a\nb\n\n").lines, 2));

test("a web address splits into its site and scheme", () => {
    const parts = Page.linkParts("https://www.example.com/path?q=1");
    assert.strictEqual(parts.host, "example.com");
    assert.strictEqual(parts.scheme, "https");
});
test("text that is not a link has no link parts", () => assert.strictEqual(Page.linkParts("not a link"), null));

test("an image shows its kind and its size with a multiplication sign", () => {
    const rows = Page.facts({ text: "", w: 977, h: 418 }, "image");
    assert.strictEqual(row(rows, "Kind"), "Image");
    assert.strictEqual(row(rows, "Dimensions"), "977 × 418");
});
test("a copied colour lists its hex, RGB and HSL forms", () => {
    const rows = Page.facts(entry("colour", "#ff6363"), "colour", Colours.parseColour("#ff6363"), Colours.FORMS);
    assert.strictEqual(row(rows, "Hex"), "#FF6363");
    assert.strictEqual(row(rows, "RGB"), "rgb(255, 99, 99)");
    assert.ok(row(rows, "HSL"));
});
test("a piece of text lists its characters, words and lines", () => {
    const rows = Page.facts(entry("text", "Hello there"), "text");
    assert.strictEqual(row(rows, "Characters"), "11");
    assert.strictEqual(row(rows, "Words"), "2");
    assert.strictEqual(row(rows, "Lines"), "1");
});
test("a link lists the site it goes to and its scheme", () => {
    const rows = Page.facts(entry("url", "https://www.example.com/path?q=1"), "link");
    assert.strictEqual(row(rows, "Site"), "example.com");
    assert.strictEqual(row(rows, "Scheme"), "https");
});
