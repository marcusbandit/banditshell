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
});
