const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/files/tile-names.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Names = new Function(src + "\nreturn { lines, heading };")();

const room = width => s => s.length <= width;

test.describe("tile names: wrapping a name under an icon", () => {
    test.it("keeps a name that fits on one line", () => {
        assert.deepStrictEqual(Names.lines("todo.txt", 2, room(10)), ["todo.txt"]);
    });

    test.it("moves the whole extension to the next line instead of splitting it", () => {
        assert.deepStrictEqual(Names.lines("report.pdf", 2, room(9)), ["report", ".pdf"]);
    });

    test.it("breaks between words before breaking inside one", () => {
        assert.deepStrictEqual(Names.lines("quarterly summary.xlsx", 2, room(14)), ["quarterly", "summary.xlsx"]);
    });

    test.it("cuts a word too long for a line with an ellipsis instead of wrapping it", () => {
        assert.deepStrictEqual(Names.lines("Projects", 2, room(7)), ["Projec\u2026"]);
        assert.deepStrictEqual(Names.lines("averyverylongfilenamewithoutspaces.tar.gz", 2, room(12)), ["averyverylo\u2026", "tar.gz"]);
    });

    test.it("keeps the end of the stem, where numbered files differ", () => {
        assert.deepStrictEqual(Names.lines("holiday-photos-from-the-beach-0042.jpeg", 2, room(16)), ["holiday-photos-", "\u2026beach-0042.jpeg"]);
    });

    test.it("elides inside one line when only one is allowed", () => {
        assert.deepStrictEqual(Names.lines("report-final.pdf", 1, room(10)), ["rep\u2026al.pdf"]);
        assert.deepStrictEqual(Names.lines("quarterly.xlsx", 1, room(7)), ["q\u2026.xlsx"]);
        assert.deepStrictEqual(Names.lines("quarterly.xlsx", 1, room(6)), ["quart\u2026"]);
    });

    test.it("treats a leading dot as part of the name, not an extension", () => {
        assert.deepStrictEqual(Names.lines(".bashrc_history", 2, room(8)), [".bashrc_", "history"]);
    });

    test.it("does not take a spaced tail for an extension", () => {
        assert.deepStrictEqual(Names.lines("v1.2 release notes", 2, room(10)), ["v1.2", "\u2026ase notes"]);
    });

    test.it("crops from the right when even the extension is wider than a line", () => {
        assert.deepStrictEqual(Names.lines("photo.markdown", 2, room(5)), ["photo", ".mar\u2026"]);
    });

    test.it("never leaves a blank line for leading spaces", () => {
        assert.deepStrictEqual(Names.lines("  leading.txt", 2, room(8)), ["leading", ".txt"]);
    });
});

test.describe("tile names: a preview title over two lines", () => {
    test.it("breaks after a separator and keeps the extension on the second line", () => {
        assert.deepStrictEqual(Names.heading("quarterly-report-for-the-board-2026.xlsx", room(16)), ["quarterly-", "\u2026board-2026.xlsx"]);
    });

    test.it("fills the first line when a word is wider than the room", () => {
        assert.deepStrictEqual(Names.heading("quarterly-report-for-the-board-2026.xlsx", room(6)), ["quarte", "rly-r\u2026"]);
    });

    test.it("keeps a name that fits on one line", () => {
        assert.deepStrictEqual(Names.heading("notes.md", room(8)), ["notes.md"]);
    });
});
