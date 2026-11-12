const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.resolve(__dirname, "../services/theme-editor.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { slug, problem, editedToml, previewFrom } = new Function(`${src}\nreturn { slug, problem, editedToml, previewFrom };`)();

const colours = { dim: "#112233", mid: "#223344", bright: "#334455", alarm: "#445566" };

test("a theme name becomes a safe folder name", () => {
    assert.strictEqual(slug("  My Night / Theme! "), "my-night-theme");
});

test("a save is refused for an empty or taken name and for a bad colour", () => {
    assert.strictEqual(problem("", colours, []), "give it a name");
    assert.strictEqual(problem("Slate", colours, ["slate"]), "slate already exists");
    assert.strictEqual(problem("mine", Object.assign({}, colours, { mid: "blue" }), []), "mid needs a colour like #7fb3d4");
    assert.strictEqual(problem("mine", colours, ["slate"]), "");
});

test("the copy keeps every other line and swaps only the highlight colours", () => {
    const base = 'mode = "dark"\nbackground = "#0F1114"\naccent = "#7FB3D4"\naccent_dim = "#5B8FB0"\naccent_mid = "#7FB3D4"\naccent_bright = "#B8DCF0"\norange = "#FF7A4D"\n';
    const edited = editedToml(base, colours);
    assert.ok(edited.includes('background = "#0F1114"'));
    assert.ok(edited.includes('accent = "#223344"'));
    assert.ok(edited.includes('accent_dim = "#112233"'));
    assert.ok(edited.includes('accent_bright = "#334455"'));
    assert.ok(edited.includes('orange = "#445566"'));
});

test("a missing key is appended instead of lost", () => {
    assert.ok(editedToml('mode = "dark"', colours).includes('orange = "#445566"'));
});

test("the live preview ignores a half-typed colour", () => {
    const shown = previewFrom({ dim: "#000001", mid: "#000002", bright: "#000003", alarm: "#000004", ramp: [] }, { dim: "#aabbcc", mid: "#12", bright: "", alarm: "#ddeeff" });
    assert.strictEqual(shown.dim, "#aabbcc");
    assert.strictEqual(shown.mid, "#000002");
    assert.strictEqual(shown.alarm, "#ddeeff");
});
