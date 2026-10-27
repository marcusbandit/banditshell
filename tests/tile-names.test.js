const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/files/tile-names.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Names = new Function(src + "\nreturn { lines };")();

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

    test.it("elides the middle of a long stem and keeps the extension whole", () => {
        assert.deepStrictEqual(Names.lines("averyverylongfilenamewithoutspaces.tar.gz", 2, room(12)), ["averyverylon", "\u2026aces.tar.gz"]);
    });

    test.it("keeps the end of the stem, where numbered files differ", () => {
        assert.deepStrictEqual(Names.lines("holiday-photos-from-the-beach-0042.jpeg", 2, room(16)), ["holiday-photos-", "\u2026beach-0042.jpeg"]);
    });

    test.it("elides inside one line when only one is allowed", () => {
        assert.deepStrictEqual(Names.lines("report-final.pdf", 1, room(10)), ["rep\u2026al.pdf"]);
    });

    test.it("treats a leading dot as part of the name, not an extension", () => {
        assert.deepStrictEqual(Names.lines(".bashrc_history", 2, room(8)), [".bashrc_", "history"]);
    });

    test.it("does not take a spaced tail for an extension", () => {
        assert.deepStrictEqual(Names.lines("v1.2 release notes", 2, room(10)), ["v1.2", "\u2026ase notes"]);
    });
});
