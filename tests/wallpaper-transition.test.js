const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
const Transition = new Function(read("services/wallpaper-transition.js") + "\nreturn { readPick };")();

const PIC = "/pictures/sea.jpg";
const line = (...bits) => bits.join("\t") + "\n";

test.describe("readPick", () => {
    test.it("reads a contagion answer with its colours", () => {
        assert.deepStrictEqual(Transition.readPick(line(PIC, "contagion", "/c/map-3.png", "/c/map-3-smooth.png", "#58b1e4", "#2f9ddd"), PIC), {
            kind: "contagion",
            field: "/c/map-3.png",
            line: "/c/map-3-smooth.png",
            ember: "#58b1e4",
            ink: "#2f9ddd"
        });
    });

    test.it("reads an outline answer", () => {
        assert.strictEqual(Transition.readPick(line(PIC, "outline", "/c/a-field.png", "/c/a-line.png", "#f3d278", "#f3d278"), PIC).kind, "outline");
    });

    test.it("leaves the colours empty when the picture gave none", () => {
        const found = Transition.readPick(line("-", "contagion", "/c/m.png", "/c/s.png", "-", "-"), "-");
        assert.strictEqual(found.ember, "");
        assert.strictEqual(found.ink, "");
    });

    test.it("ignores an answer about another wallpaper", () => {
        assert.strictEqual(Transition.readPick(line("/pictures/old.jpg", "contagion", "/c/m.png", "/c/s.png", "-", "-"), PIC), null);
    });

    test.it("ignores an answer cut short", () => {
        assert.strictEqual(Transition.readPick(`${PIC}\tcontagion\t/c/m.png`, PIC), null);
        assert.strictEqual(Transition.readPick("", PIC), null);
    });

    test.it("keeps tabs and spaces in a path apart", () => {
        const odd = "/pictures/my sea.jpg";
        assert.strictEqual(Transition.readPick(line(odd, "contagion", "/c/m.png", "/c/s.png", "-", "-"), odd).field, "/c/m.png");
    });

    test.it("fails an answer of a kind it does not know", () => {
        assert.deepStrictEqual(Transition.readPick(line(PIC, "sparkle", "/c/m.png", "/c/s.png", "-", "-"), PIC), { failed: true });
    });
});
