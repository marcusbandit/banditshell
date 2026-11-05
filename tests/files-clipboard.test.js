const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.resolve(__dirname, "../services/files-clipboard.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Clip = new Function(`${src}\nreturn { copyCommand, typesCommand, readCommand, pick, parse, same };`)();

const ODD = ["/home/ada/two words.txt", "/home/ada/it's \"quoted\".txt", "/home/ada/new\nline", "/home/ada/100%.txt", "/home/ada/#hash?query", "/home/ada/ünï.txt", "/"];

test.describe("files clipboard", () => {
    test.it("offers a copy as a uri list with one encoded line per file", () => {
        const made = Clip.copyCommand(["/home/ada/two words.txt", "/home/ada/b#.txt"], false);
        assert.deepStrictEqual(made.argv, ["wl-copy", "-t", "text/uri-list"]);
        assert.strictEqual(made.input, "file:///home/ada/two%20words.txt\r\nfile:///home/ada/b%23.txt");
    });

    test.it("offers a cut as the GNOME copied-files flavour that starts with cut", () => {
        const made = Clip.copyCommand(["/home/ada/a"], true);
        assert.deepStrictEqual(made.argv, ["wl-copy", "-t", "x-special/gnome-copied-files"]);
        assert.strictEqual(made.input, "cut\nfile:///home/ada/a");
    });

    test.it("reads back every name it wrote, odd ones included, for both flavours", () => {
        for (const cut of [false, true]) {
            const made = Clip.copyCommand(ODD, cut);
            const type = made.argv[2];
            assert.deepStrictEqual(Clip.parse(type, made.input), { paths: ODD, cut });
        }
    });

    test.it("reads a list another app copied: comments, CRLF, localhost and foreign schemes", () => {
        const text = "# copied by dolphin\r\nfile:///home/ada/a%20b.png\r\nfile://localhost/home/ada/c.png\r\nhttps://example.com/x.png\r\nfile://otherhost/etc/passwd\r\n";
        assert.deepStrictEqual(Clip.parse("text/uri-list", text), { paths: ["/home/ada/a b.png", "/home/ada/c.png"], cut: false });
    });

    test.it("reads the copy and cut marker of the GNOME flavour", () => {
        assert.deepStrictEqual(Clip.parse("x-special/gnome-copied-files", "copy\nfile:///a\nfile:///b\n"), { paths: ["/a", "/b"], cut: false });
        assert.deepStrictEqual(Clip.parse("x-special/gnome-copied-files", "cut\nfile:///a"), { paths: ["/a"], cut: true });
    });

    test.it("drops a malformed escape instead of throwing", () => {
        assert.deepStrictEqual(Clip.parse("text/uri-list", "file:///bad%E0%A4%A\nfile:///good"), { paths: ["/good"], cut: false });
    });

    test.it("prefers the GNOME flavour, then the uri list, and ignores a clipboard without files", () => {
        assert.strictEqual(Clip.pick("text/plain\ntext/uri-list\nx-special/gnome-copied-files\n"), "x-special/gnome-copied-files");
        assert.strictEqual(Clip.pick("text/plain\ntext/uri-list\n"), "text/uri-list");
        assert.strictEqual(Clip.pick("text/plain\nimage/png\n"), "");
        assert.strictEqual(Clip.pick(""), "");
    });

    test.it("builds the paste commands and compares two path lists in order", () => {
        assert.deepStrictEqual(Clip.typesCommand(), ["wl-paste", "--list-types"]);
        assert.deepStrictEqual(Clip.readCommand("text/uri-list"), ["wl-paste", "--no-newline", "--type", "text/uri-list"]);
        assert.strictEqual(Clip.same(["/a", "/b"], ["/a", "/b"]), true);
        assert.strictEqual(Clip.same(["/a", "/b"], ["/b", "/a"]), false);
        assert.strictEqual(Clip.same(["/a"], ["/a", "/b"]), false);
    });
});
