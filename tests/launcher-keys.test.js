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

const Keys = lib("services/keybind-search.js", ["ask", "chordText", "keyLabel", "entries", "matching"]);

const BINDS = [
    { mask: 64, key: "space", presses: [{ mask: 64, key: "space" }], action: "Open or close the launcher", submap: "" },
    { mask: 65, key: "Slash", presses: [{ mask: 65, key: "Slash" }], action: "Show the hotkey sheet", submap: "" },
    { mask: 64, key: "t", presses: [{ mask: 64, key: "t" }], action: "", description: "", expr: "hl.dsp.exec_cmd(\"kitty\")", submap: "" },
    { mask: 0, key: "", presses: [{ mask: 64, key: "1" }, { mask: 64, key: "2" }, { mask: 64, key: "3" }], action: "Focus workspace", submap: "" },
    { mask: 0, key: "e", presses: [], action: "Leave the submap", submap: "resize" },
    { mask: 64, key: "q", presses: [{ mask: 64, key: "q" }], action: "", expr: "", submap: "" },
    { mask: 0, key: "XF86AudioMute", presses: [{ mask: 0, key: "XF86AudioMute" }], action: "Mute", submap: "" },
    { mask: 64, key: "mouse:272", presses: [{ mask: 64, key: "mouse:272" }], action: "Move the window", submap: "" }
];

test.describe("asking for a chord", () => {
    test.it("answers to keys, shortcut and the words after them", () => {
        assert.deepStrictEqual(Keys.ask("keys fullscreen"), { words: "fullscreen" });
        assert.deepStrictEqual(Keys.ask("Shortcut Close Window"), { words: "close window" });
        assert.deepStrictEqual(Keys.ask("shortcuts"), { words: "" });
        assert.deepStrictEqual(Keys.ask("keybind launcher"), { words: "launcher" });
    });

    test.it("leaves words that only start with the same letters alone", () => {
        for (const text of ["keyboard", "keystroke", "key", "short", "shortcutting x", ""])
            assert.strictEqual(Keys.ask(text), null, text);
    });
});

test.describe("writing a chord", () => {
    test.it("names the modifiers in a fixed order and the key plainly", () => {
        assert.strictEqual(Keys.chordText(65, "Slash"), "Super + Shift + Slash");
        assert.strictEqual(Keys.chordText(4 + 8 + 64, "t"), "Super + Ctrl + Alt + T");
        assert.strictEqual(Keys.chordText(0, "XF86AudioMute"), "Audio Mute");
        assert.strictEqual(Keys.chordText(64, "mouse:273"), "Super + Mouse right");
        assert.strictEqual(Keys.chordText(64, ""), "Super");
    });
});

test.describe("the binds the shell parsed", () => {
    const list = Keys.entries(BINDS);

    test.it("keeps one entry per chord and skips binds with nothing to say", () => {
        assert.deepStrictEqual(list.map(e => e.chord), [
            "Super + Space",
            "Super + Shift + Slash",
            "Super + T",
            "Super + 1",
            "Super + 2",
            "Super + 3",
            "E",
            "Audio Mute",
            "Super + Mouse left"
        ]);
    });

    test.it("falls back on the raw expression when no description exists", () => {
        assert.strictEqual(list.find(e => e.chord === "Super + T").action, "hl.dsp.exec_cmd(\"kitty\")");
    });

    test.it("drops a repeated chord and action but keeps the same chord in another submap", () => {
        const twice = Keys.entries([BINDS[0], BINDS[0], Object.assign({}, BINDS[0], { submap: "resize" })]);
        assert.deepStrictEqual(twice.map(e => e.submap), ["", "resize"]);
    });
});

test.describe("finding a chord by what it does", () => {
    const list = Keys.entries(BINDS);
    const find = words => Keys.matching(list, words, Ranking.place, 12).map(e => e.chord);

    test.it("finds the chord whose action holds every word", () => {
        assert.deepStrictEqual(find("launcher"), ["Super + Space"]);
        assert.deepStrictEqual(find("hotkey sheet"), ["Super + Shift + Slash"]);
        assert.deepStrictEqual(find("close launcher"), ["Super + Space"]);
    });

    test.it("finds what a chord does when the chord is typed", () => {
        assert.deepStrictEqual(find("super+shift+slash"), ["Super + Shift + Slash"]);
        assert.deepStrictEqual(find("super 2"), ["Super + 2"]);
    });

    test.it("lists everything for a bare ask, in file order, and respects the limit", () => {
        assert.strictEqual(find("").length, list.length > 12 ? 12 : list.length);
        assert.strictEqual(Keys.matching(list, "", Ranking.place, 2).length, 2);
        assert.deepStrictEqual(find("nothing like this"), []);
    });

    test.it("puts the closer match first", () => {
        const two = Keys.entries([
            { mask: 64, key: "a", presses: [{ mask: 64, key: "a" }], action: "Fit every visible window", submap: "" },
            { mask: 64, key: "b", presses: [{ mask: 64, key: "b" }], action: "Fit", submap: "" }
        ]);
        assert.strictEqual(Keys.matching(two, "fit", Ranking.place, 5)[0].chord, "Super + B");
    });
});
