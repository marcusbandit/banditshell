const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Markdown = lib("services/files-markdown.js", ["rendered"]);
const Catalogue = lib("modules/settings/catalogue.js", ["ROW_BY_KEY", "options", "filesMarkdownOf"]);

test.describe("files markdown", () => {
    test.it("each value Settings writes shows Markdown the way its label reads", () => {
        const row = Catalogue.ROW_BY_KEY.filesMarkdown;
        assert.strictEqual(row.cfg, "files.markdown");
        const shown = Object.fromEntries(Catalogue.options(row, {}).map(([v, l]) => [l, Markdown.rendered(v)]));
        assert.deepStrictEqual(shown, {rendered: true, source: false});
    });

    test.it("a config holding raw from older file manager settings still reads as source", () => {
        assert.strictEqual(Markdown.rendered("raw"), false);
        assert.strictEqual(Catalogue.filesMarkdownOf("raw"), "source");
    });

    test.it("Settings and the file manager pick the same option for any stored value", () => {
        for (const value of ["rendered", "source", "raw", undefined, "", "other"])
            assert.strictEqual(Catalogue.filesMarkdownOf(value) === "rendered", Markdown.rendered(value), `files.markdown = ${value}`);
    });
});
