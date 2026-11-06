const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const ROOT = path.resolve(__dirname, "..");
const REPO = "https://github.com/marcusbandit/banditshell";
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
        const { front, post } = await import(pathToFileURL(path.join(ROOT, "site/blog.mjs")).href);
        assert.deepStrictEqual(front('---\ntitle: "A, b"\ndraft: true\n---\ntext\n'), { meta: { title: "A, b", draft: "true" }, body: "text\n" });
        assert.throws(() => post("---\ntitle: x\ndate: 2026-11-06\n---\ntext", "x.md", ROOT, REPO), /needs summary/);
        assert.throws(() => post("---\ntitle: x\ndate: 6 Nov\nsummary: s\n---\ntext", "x.md", ROOT, REPO), /YYYY-MM-DD/);
    });

    test.it("gives every post image its real size so the page does not jump", async () => {
        const { blocks } = await load();
        const { webpSize, post } = await import(pathToFileURL(path.join(ROOT, "site/blog.mjs")).href);
        assert.deepStrictEqual(blocks('![a b](/images/x.webp "A cap")')[0], { type: "image", alt: "a b", src: "/images/x.webp", caption: "A cap" });
        assert.deepStrictEqual(webpSize(fs.readFileSync(path.join(ROOT, "site/images/blog-rail.webp"))), { width: 300, height: 313 });
        const html = post("---\ntitle: t\ndate: 2026-11-06\nsummary: s\n---\n![alt](/images/blog-rail.webp)\n", "t.md", path.join(ROOT, "site"), REPO).html;
        assert.match(html, /<img src="\/images\/blog-rail.webp" width="300" height="313"/);
    });
});
