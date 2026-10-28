const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/files/urls.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Urls = new Function(src + "\nreturn { fileUrl, freshUrl, uriList };")();

test.describe("urls: file paths as file:// addresses", () => {
    test.it("encodes the characters a URL would read as structure", () => {
        assert.strictEqual(Urls.fileUrl("/home/me/a#b?c%d e"), "file:///home/me/a%23b%3Fc%25d%20e");
    });

    test.it("keeps the slashes between segments", () => {
        assert.strictEqual(Urls.fileUrl("/"), "file:///");
        assert.strictEqual(Urls.fileUrl("/a/b/c.png"), "file:///a/b/c.png");
    });

    test.it("percent-encodes non-ASCII names as UTF-8", () => {
        assert.strictEqual(Urls.fileUrl("/Música/é"), "file:///M%C3%BAsica/%C3%A9");
    });

    test.it("decodes back to the same path", () => {
        const names = ["/tmp/#hash", "/tmp/what?", "/tmp/100%", "/tmp/a\nb", "/tmp/ünï cødé"];
        for (const name of names)
            assert.strictEqual(decodeURIComponent(new URL(Urls.fileUrl(name)).pathname), name);
    });

    test.it("gives nothing for a path that is not valid text", () => {
        assert.strictEqual(Urls.fileUrl("/tmp/\ud800"), "");
    });

    test.it("changes a picture's address when its date or size changes, and only then", () => {
        const before = Urls.freshUrl("/p/holiday.jpeg", 1700000000, 2048);
        assert.strictEqual(before, "file:///p/holiday.jpeg?v=1700000000-2048");
        assert.strictEqual(Urls.freshUrl("/p/holiday.jpeg", 1700000000, 2048), before);
        assert.notStrictEqual(Urls.freshUrl("/p/holiday.jpeg", 1700000300, 2048), before);
        assert.notStrictEqual(Urls.freshUrl("/p/holiday.jpeg", 1700000000, 4096), before);
    });

    test.it("keeps a question mark in a name apart from the version", () => {
        assert.strictEqual(Urls.freshUrl("/p/why?.png", 1, 2), "file:///p/why%3F.png?v=1-2");
        assert.strictEqual(Urls.freshUrl("/tmp/\ud800", 1, 2), "");
    });

    test.it("lists every path, one per CRLF line", () => {
        assert.strictEqual(Urls.uriList(["/a b", "/c#d"]), "file:///a%20b\r\nfile:///c%23d\r\n");
        assert.strictEqual(Urls.uriList([]), "");
    });
});
