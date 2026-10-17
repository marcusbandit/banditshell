const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Ranking = lib("services/ranking.js", ["place"]);

const Recent = lib("services/recent-documents.js", ["ask", "unescapeXml", "readBookmarks", "existing", "matching", "ambient"]);
const Search = lib("modules/launcher/search.js", ["isSecretish"]);

const entry = (href, visited, app, mime) => `  <bookmark href="${href}" added="2026-03-22T22:34:36Z" modified="2026-03-22T22:34:36Z" visited="${visited}">
    <info>
      <metadata owner="http://freedesktop.org">
        <mime:mime-type type="${mime || "application/pdf"}"/>
        <bookmark:applications>
          <bookmark:application name="${app || "Okular"}" exec="&apos;okular %u&apos;" modified="${visited}" count="1"/>
        </bookmark:applications>
      </metadata>
    </info>
  </bookmark>
`;

const XBEL = `<?xml version="1.0" encoding="UTF-8"?>
<xbel version="1.0" xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks" xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info">
${entry("file:///home/me/Documents/Report%20Final.pdf", "2026-10-01T10:00:00Z")}${entry("file:///home/me/Documents/notes.txt", "2026-10-03T10:00:00Z", "Kate", "text/plain")}${entry("file:///home/me/.ssh/id_ed25519", "2026-10-04T10:00:00Z")}${entry("file:///home/me/Documents/passwords.kdbx", "2026-10-05T10:00:00Z")}${entry("file:///home/me/.hidden.txt", "2026-10-06T10:00:00Z")}${entry("https://example.com/page", "2026-10-07T10:00:00Z")}${entry("file:///home/me/Documents/Tom%20&amp;%20Jerry.pdf", "2026-10-02T10:00:00Z")}${entry("file:///home/me/Documents/Report%20Final.pdf", "2026-10-08T10:00:00Z", "Evince")}`;

test.describe("asking for recent documents", () => {
    test.it("answers to recent, recently used and documents, with words to narrow by", () => {
        assert.deepStrictEqual(Recent.ask("recent"), { words: "" });
        assert.deepStrictEqual(Recent.ask("Recently used"), { words: "" });
        assert.deepStrictEqual(Recent.ask("recent documents report"), { words: "report" });
        assert.deepStrictEqual(Recent.ask("recent files"), { words: "" });
        assert.deepStrictEqual(Recent.ask("documents invoice"), { words: "invoice" });
        assert.deepStrictEqual(Recent.ask("docs budget"), { words: "budget" });
    });

    test.it("leaves the downloads and screenshots shelves to the latest files source", () => {
        for (const text of ["recent downloads", "recent download pdf", "recent screenshots", "recent screenshot"])
            assert.strictEqual(Recent.ask(text), null, text);
        assert.deepStrictEqual(Recent.ask("recent downloaded.txt"), { words: "downloaded.txt" });
    });

    test.it("leaves other words alone", () => {
        for (const text of ["recently", "recents", "documentary", "docs2", "docs", "documents", ""])
            assert.strictEqual(Recent.ask(text), null, text);
    });
});

test.describe("reading the xbel file", () => {
    const docs = Recent.readBookmarks(XBEL, Search.isSecretish);

    test.it("decodes the path and lists the newest first, one entry per file", () => {
        assert.deepStrictEqual(docs.map(d => d.name), ["Report Final.pdf", "notes.txt", "Tom & Jerry.pdf"]);
        assert.strictEqual(docs[0].path, "/home/me/Documents/Report Final.pdf");
        assert.strictEqual(docs[0].dir, "/home/me/Documents");
    });

    test.it("keeps the latest visit and the app that made it", () => {
        assert.strictEqual(docs[0].app, "Evince");
        assert.strictEqual(docs[0].visited, Date.parse("2026-10-08T10:00:00Z"));
        assert.strictEqual(docs[1].mime, "text/plain");
        assert.strictEqual(docs[1].app, "Kate");
    });

    test.it("hides secret-named files, hidden files and anything that is not a local file", () => {
        const names = docs.map(d => d.name);
        for (const hidden of ["id_ed25519", "passwords.kdbx", ".hidden.txt", "page"])
            assert.ok(!names.includes(hidden), hidden);
    });

    test.it("reads an empty or broken file as nothing", () => {
        assert.deepStrictEqual(Recent.readBookmarks("", Search.isSecretish), []);
        assert.deepStrictEqual(Recent.readBookmarks("<bookmark href=\"file:///%E0%A4%A\">", Search.isSecretish), []);
        assert.deepStrictEqual(Recent.readBookmarks(null, Search.isSecretish), []);
    });

    test.it("decodes the usual XML entities", () => {
        assert.strictEqual(Recent.unescapeXml("a &amp; b &lt;c&gt; &quot;d&quot; &apos;e&apos; &#65;&#x42;"), "a & b <c> \"d\" 'e' AB");
    });
});

test.describe("keeping files that still exist", () => {
    const docs = Recent.readBookmarks(XBEL, Search.isSecretish);

    test.it("drops the ones the listing does not name", () => {
        const left = Recent.existing(docs, "/home/me/Documents/notes.txt\n/home/me/Documents/Tom & Jerry.pdf\n");
        assert.deepStrictEqual(left.map(d => d.name), ["notes.txt", "Tom & Jerry.pdf"]);
        assert.deepStrictEqual(Recent.existing(docs, ""), []);
    });
});

test.describe("finding a document", () => {
    const docs = Recent.readBookmarks(XBEL, Search.isSecretish);

    test.it("lists the newest for a bare ask and narrows by every word of the path", () => {
        assert.strictEqual(Recent.matching(docs, "", 10).length, 3);
        assert.strictEqual(Recent.matching(docs, "", 2).length, 2);
        assert.deepStrictEqual(Recent.matching(docs, "report", 10).map(d => d.name), ["Report Final.pdf"]);
        assert.deepStrictEqual(Recent.matching(docs, "documents tom", 10).map(d => d.name), ["Tom & Jerry.pdf"]);
        assert.deepStrictEqual(Recent.matching(docs, "zzz", 10), []);
    });

    test.it("shows a document for its bare name below every app and setting", () => {
        const found = Recent.ambient(docs, "rep", Ranking.place, 3);
        assert.deepStrictEqual(found.map(f => f.document.name), ["Report Final.pdf"]);
        assert.ok(found[0].score > 0 && found[0].score < 0.5);
    });

    test.it("stays quiet for short words, sentences and words in the middle of a name", () => {
        assert.deepStrictEqual(Recent.ambient(docs, "re", Ranking.place, 3), []);
        assert.deepStrictEqual(Recent.ambient(docs, "final report", Ranking.place, 3), []);
        assert.deepStrictEqual(Recent.ambient(docs, "inal", Ranking.place, 3), []);
    });
});
