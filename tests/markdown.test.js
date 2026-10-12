const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/files/markdown.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Markdown = new Function(src + "\nreturn { inert };")();

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
