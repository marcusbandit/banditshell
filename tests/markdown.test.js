const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/files/markdown.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Markdown = new Function(src + "\nreturn { inert, flattenHeadings };")();

const SAMPLES = [
    "![alt](https://example.com/a.png)",
    "![alt][ref]\n\n[ref]: http://example.com/b.png",
    "<img src=\"http://example.com/c.png\">",
    "<IMG SRC=http://example.com/d.png>",
    "<style>@import url(http://example.com/e.css);</style>",
    "<link rel=\"stylesheet\" href=\"http://example.com/f.css\">",
    "<table background=\"http://example.com/g.png\"><tr><td>x</td></tr></table>",
    "<!-- comment --> <?php ?> </div>",
    "`<div>` and ```\n<img src=x>\n```"
];

test.describe("markdown: nothing in a previewed file can load a resource", () => {
    test.it("leaves no tag opener and no image opener", () => {
        for (const sample of SAMPLES) {
            const out = Markdown.inert(sample);
            assert.ok(!/<[A-Za-z!?\/]/.test(out), out);
            assert.ok(!/!\[/.test(out), out);
        }
    });

    test.it("changes nothing but the invisible break", () => {
        for (const sample of SAMPLES)
            assert.strictEqual(Markdown.inert(sample).replace(/​/g, ""), sample);
    });

    test.it("keeps prose that only looks like markup", () => {
        assert.strictEqual(Markdown.inert("a < b and c > d, [link](x) and !"), "a < b and c > d, [link](x) and !");
    });
});

const HEADING = /^ {0,3}(?:> ?)*#{1,6}(?:[ \t]|$)/m;
const UNDERLINED = /\S[^\n]*\n {0,3}(?:=+|-+)[ \t]*(?:\n|$)/;
const RULE = /^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$/gm;

test.describe("markdown: a previewed file's headings stay the body size", () => {
    test.it("turns hash headings into bold lines", () => {
        assert.strictEqual(Markdown.flattenHeadings("# Title"), "**Title**\n");
        assert.strictEqual(Markdown.flattenHeadings("text\n## Part ##\nmore"), "text\n\n**Part**\n\nmore");
        assert.strictEqual(Markdown.flattenHeadings("###### six"), "**six**\n");
    });

    test.it("turns underlined headings into bold lines", () => {
        assert.strictEqual(Markdown.flattenHeadings("Title\n====="), "**Title**\n");
        assert.strictEqual(Markdown.flattenHeadings("two\nlines\n---\nafter"), "**two lines**\n\nafter");
    });

    test.it("keeps a rule a rule", () => {
        assert.strictEqual(Markdown.flattenHeadings("para\n\n---\n\nnext"), "para\n\n---\n\nnext");
        assert.strictEqual(Markdown.flattenHeadings("- item\n- ---"), "- item\n- ---");
    });

    test.it("reaches into quotes and list items", () => {
        assert.strictEqual(Markdown.flattenHeadings("> # Quoted"), "> **Quoted**\n>");
        assert.strictEqual(Markdown.flattenHeadings("- # Listed"), "- **Listed**\n");
        assert.strictEqual(Markdown.flattenHeadings("> quoted\n> ==="), "> **quoted**\n>");
    });

    test.it("leaves code alone", () => {
        const fenced = "```\n# not a heading\nnor\n===\n```";
        assert.strictEqual(Markdown.flattenHeadings(fenced), fenced);
        const tilde = "~~~~ sh\n# comment\n~~~\n# still code\n~~~~";
        assert.strictEqual(Markdown.flattenHeadings(tilde), tilde);
        assert.strictEqual(Markdown.flattenHeadings("    # code"), "    # code");
    });

    test.it("leaves text that only looks like a heading", () => {
        assert.strictEqual(Markdown.flattenHeadings("#hashtag and ####### seven"), "#hashtag and ####### seven");
        assert.strictEqual(Markdown.flattenHeadings("issue #4 is open"), "issue #4 is open");
    });

    test.it("leaves no heading in a whole document", () => {
        for (const name of ["DESIGN.md", "CLAUDE.md", "TODO.md"]) {
            const doc = fs.readFileSync(path.join(ROOT, name), "utf8");
            const out = Markdown.flattenHeadings(doc).replace(/```[\s\S]*?```/g, "").replace(RULE, "");
            assert.ok(!HEADING.test(out), name + ": " + (HEADING.exec(out) || [""])[0]);
            assert.ok(!UNDERLINED.test(out), name + ": " + (UNDERLINED.exec(out) || [""])[0]);
        }
    });
});
