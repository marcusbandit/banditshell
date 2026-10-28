const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.resolve(__dirname, "../config/user-folders.js"), "utf8").replace(".pragma library", "");
const Folders = new Function(src + "\nreturn { parse, byPath, shown };")();

const HOME = "/home/ana";
const GERMAN = fs.readFileSync(path.join(__dirname, "fixtures/user-dirs.dirs"), "utf8");

test("reads a localized user-dirs.dirs the way xdg-user-dirs-update writes it", () => {
    const folders = Folders.parse(GERMAN, HOME);
    assert.strictEqual(folders.Documents, "/home/ana/Dokumente");
    assert.strictEqual(folders.Downloads, "/home/ana/Downloads");
    assert.strictEqual(folders.Pictures, "/home/ana/Bilder");
    assert.strictEqual(folders.Desktop, "/home/ana/Schreibtisch");
});

test("takes absolute paths and shell escapes, and drops a trailing slash", () => {
    const folders = Folders.parse('XDG_PICTURES_DIR="/data/Fotos \\"neu\\"/"\nXDG_MUSIC_DIR="$HOME/Musik \\$1"\n', HOME);
    assert.strictEqual(folders.Pictures, '/data/Fotos "neu"');
    assert.strictEqual(folders.Music, "/home/ana/Musik $1");
});

test("a missing file, a disabled folder or a line it cannot read falls back to the English name", () => {
    assert.strictEqual(Folders.parse("", HOME).Pictures, "/home/ana/Pictures");
    assert.strictEqual(Folders.parse(undefined, HOME).Downloads, "/home/ana/Downloads");
    const odd = Folders.parse('XDG_DOCUMENTS_DIR="$HOME/"\nXDG_DOWNLOAD_DIR=relative/path\nXDG_VIDEOS_DIR="Filme"\n# XDG_PICTURES_DIR="$HOME/Bilder"\nXDG_UNKNOWN_DIR="$HOME/x"\n', HOME);
    assert.deepStrictEqual([odd.Documents, odd.Downloads, odd.Videos, odd.Pictures], ["/home/ana/Documents", "/home/ana/Downloads", "/home/ana/Videos", "/home/ana/Pictures"]);
    assert.ok(!("Unknown" in odd));
});

test("names each folder by its path, and shows a path under home with a tilde", () => {
    const named = Folders.byPath(Folders.parse(GERMAN, HOME));
    assert.strictEqual(named["/home/ana/Bilder"], "Pictures");
    assert.strictEqual(Folders.shown("/home/ana/Bilder", HOME), "~/Bilder");
    assert.strictEqual(Folders.shown(HOME, HOME), "~");
    assert.strictEqual(Folders.shown("/home/anabel/Bilder", HOME), "/home/anabel/Bilder");
});
