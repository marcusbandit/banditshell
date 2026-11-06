const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const ROOT = path.resolve(__dirname, "..");
const REPO = "https://github.com/marcusbandit/banditshell";
const blog = () => import(pathToFileURL(path.join(ROOT, "site/blog.mjs")).href);
const tmp = () => fs.mkdtempSync(path.join(require("node:os").tmpdir(), "blog-"));
const load = () => import(pathToFileURL(path.join(ROOT, "site/roadmap.mjs")).href);

test.describe("roadmap site", () => {
    test.it("renders docs/roadmap.md with no markdown left over", async () => {
        const { render } = await load();
        const page = render(fs.readFileSync(path.join(ROOT, "docs/roadmap.md"), "utf8"), REPO);
        const html = page.intro + page.sections.map((section) => section.html).join("");
        assert.ok(page.title);
        assert.ok(page.sections.length > 0);
        assert.doesNotMatch(html, /\*\*|`|\|\s*---|^#/m);
        assert.strictEqual(new Set(page.sections.map((section) => section.id)).size, page.sections.length);
    });

    test.it("labels every table cell with its column, so a phone can stack the rows", async () => {
        const { render } = await load();
        const page = render("# t\n\n## s\n\n| A | B |\n|---|---|\n| one | two |\n", REPO);
        assert.match(page.sections[0].html, /<td data-label="A">one<\/td><td data-label="B">two<\/td>/);
    });

    test.it("links pull request numbers and keeps code literal", async () => {
        const { inline } = await load();
        assert.strictEqual(inline("PR #53", REPO), `PR <a href="${REPO}/pull/53">#53</a>`);
        assert.strictEqual(inline("`a **b** #1`", REPO), "<code>a **b** #1</code>");
        assert.strictEqual(inline("<b> & \"q\"", REPO), "&lt;b&gt; &amp; &quot;q&quot;");
    });

    test.it("joins wrapped list items and paragraphs", async () => {
        const { blocks } = await load();
        assert.deepStrictEqual(blocks("- one\n  two\n- three\n\nfour\nfive\n"), [
            { type: "list", ordered: false, items: ["one two", "three"] },
            { type: "paragraph", text: "four five" },
        ]);
    });

    test.it("leaves a draft post out of the build unless drafts are asked for", async () => {
        const dir = fs.mkdtempSync(path.join(require("node:os").tmpdir(), "blog-"));
        const write = (name, draft) =>
            fs.writeFileSync(path.join(dir, name), `---\ntitle: T ${name}\ndate: 2026-11-0${draft ? 2 : 1}\nsummary: s\n${draft ? "draft: true\n" : ""}---\n\nbody\n`);
        write("live.md", false);
        write("soon.md", true);
        const { posts } = await import(pathToFileURL(path.join(ROOT, "site/blog.mjs")).href);
        assert.deepStrictEqual(posts(dir, dir, REPO).map((p) => p.slug), ["live"]);
        assert.deepStrictEqual(posts(dir, dir, REPO, { drafts: true }).map((p) => p.slug), ["soon", "live"]);
        fs.rmSync(dir, { recursive: true });
    });

    test.it("reads front matter and refuses a post that lacks a title, date or summary", async () => {
        const { front, post } = await blog();
        assert.deepStrictEqual(front('---\ntitle: "A, b"\ndraft: true\n---\ntext\n'), { meta: { title: "A, b", draft: "true" }, body: "text\n" });
        assert.throws(() => post("---\ndate: 2026-11-06\nsummary: s\n---\ntext", "x.md", ROOT, REPO), /needs title/);
        assert.throws(() => post("---\ntitle: x\ndate: 2026-11-06\n---\ntext", "x.md", ROOT, REPO), /needs summary/);
        assert.throws(() => post("---\ntitle: x\nsummary: s\n---\ntext", "x.md", ROOT, REPO), /needs date/);
        assert.throws(() => post("---\ntitle: x\ndate: 6 Nov\nsummary: s\n---\ntext", "x.md", ROOT, REPO), /YYYY-MM-DD/);
        assert.throws(() => post("---\ntitle: x\ndate: 2026-13-45\nsummary: s\n---\ntext", "x.md", ROOT, REPO), /real day/);
        assert.throws(() => post("---\ntitle: x\ndate: 2026-02-30\nsummary: s\n---\ntext", "x.md", ROOT, REPO), /real day/);
    });

    test.it("reads the draft flag in any case and rejects anything else", async () => {
        const { post } = await blog();
        const draft = (value) => post(`---\ntitle: x\ndate: 2026-11-06\nsummary: s\ndraft: ${value}\n---\ntext`, "x.md", ROOT, REPO).draft;
        assert.strictEqual(draft("True"), true);
        assert.strictEqual(draft("true # wip"), true);
        assert.strictEqual(draft("'true'"), true);
        assert.strictEqual(draft("false"), false);
        assert.throws(() => draft("yes"), /true or false/);
    });

    test.it("does not validate a draft unless drafts are asked for", async () => {
        const { posts } = await blog();
        const dir = tmp();
        fs.writeFileSync(path.join(dir, "half.md"), "---\ntitle: t\ndate: 2026-11-06\ndraft: true\n---\n![a](/images/missing.webp)\n");
        assert.deepStrictEqual(posts(dir, dir, REPO), []);
        assert.throws(() => posts(dir, dir, REPO, { drafts: true }), /needs summary/);
        fs.rmSync(dir, { recursive: true });
    });

    test.it("orders same-day posts by release number, not by slug text", async () => {
        const { posts } = await blog();
        const dir = tmp();
        const write = (name, release) => fs.writeFileSync(path.join(dir, name), `---\ntitle: ${name}\ndate: 2026-11-06\nrelease: ${release}\nsummary: s\n---\nbody\n`);
        write("v0-3-0-a.md", "v0.3.0");
        write("v0-10-0-b.md", "v0.10.0");
        write("v0-9-0-c.md", "v0.9.0");
        assert.deepStrictEqual(posts(dir, dir, REPO).map((p) => p.slug), ["v0-10-0-b", "v0-9-0-c", "v0-3-0-a"]);
        fs.rmSync(dir, { recursive: true });
    });

    test.it("sizes webp, png and jpg from their headers and refuses what it cannot size", async () => {
        const { webpSize, pngSize, jpegSize, post } = await blog();
        const riff = (kind, body) => Buffer.concat([Buffer.from("RIFF"), Buffer.alloc(4), Buffer.from("WEBP"), Buffer.from(kind), Buffer.alloc(4), body]);
        const vp8x = Buffer.alloc(18);
        vp8x.writeUIntLE(299, 4, 3);
        vp8x.writeUIntLE(312, 7, 3);
        assert.deepStrictEqual(webpSize(riff("VP8X", vp8x)), { width: 300, height: 313 });
        const vp8l = Buffer.alloc(18);
        vp8l.writeUInt32LE(299 | (312 << 14), 1);
        assert.deepStrictEqual(webpSize(riff("VP8L", vp8l)), { width: 300, height: 313 });
        const vp8 = Buffer.alloc(18);
        vp8.writeUInt16LE(300, 6);
        vp8.writeUInt16LE(313, 8);
        assert.deepStrictEqual(webpSize(riff("VP8 ", vp8)), { width: 300, height: 313 });
        assert.strictEqual(webpSize(Buffer.from("RIFF")), null);
        const png = Buffer.alloc(33);
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(png);
        png.write("IHDR", 12);
        png.writeUInt32BE(300, 16);
        png.writeUInt32BE(313, 20);
        assert.deepStrictEqual(pngSize(png), { width: 300, height: 313 });
        const jpg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x04, 0x00, 0x00, 0xff, 0xc0, 0x00, 0x0b, 0x08]), Buffer.from([0x01, 0x39, 0x01, 0x2c]), Buffer.alloc(8)]);
        assert.deepStrictEqual(jpegSize(jpg), { width: 300, height: 313 });

        const dir = tmp();
        fs.mkdirSync(path.join(dir, "images"));
        fs.writeFileSync(path.join(dir, "images", "a.webp"), riff("VP8X", vp8x));
        fs.writeFileSync(path.join(dir, "images", "b.png"), png);
        fs.writeFileSync(path.join(dir, "images", "c.jpg"), jpg);
        fs.writeFileSync(path.join(dir, "images", "bad.webp"), Buffer.from("RIFF"));
        const make = (src) => post(`---\ntitle: t\ndate: 2026-11-06\nsummary: s\n---\n![alt](${src})\n`, "t.md", dir, REPO).html;
        for (const name of ["a.webp", "b.png", "c.jpg"]) assert.match(make(`/images/${name}`), /width="300" height="313"/);
        assert.throws(() => make("/images/bad.webp"), /not a readable/);
        assert.throws(() => make("/images/none.webp"), /is not in site/);
        assert.throws(() => make("/../../etc/passwd"), /must be/);
        assert.throws(() => make("https://example.com/x.png"), /must be/);
        fs.rmSync(dir, { recursive: true });
    });

    test.it("gives every post image its real size so the page does not jump", async () => {
        const { blocks } = await load();
        const { post } = await blog();
        assert.deepStrictEqual(blocks('![a b](/images/x.webp "A cap")')[0], { type: "image", alt: "a b", src: "/images/x.webp", caption: "A cap" });
        const html = post("---\ntitle: t\ndate: 2026-11-06\nsummary: s\n---\n![alt](/images/blog-rail.webp)\n", "t.md", path.join(ROOT, "site"), REPO).html;
        assert.match(html, /<img src="\/images\/blog-rail.webp" width="\d+" height="\d+"/);
    });
});
