const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.resolve(__dirname, "../services/theme-editor.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { slug, problem, editedToml, overridesFrom } = new Function(`${src}\nreturn { slug, problem, editedToml, overridesFrom };`)();

const colours = { dim: "#112233", mid: "#223344", bright: "#334455", alarm: "#445566" };

test("a theme name becomes a safe folder name", () => {
    assert.strictEqual(slug("  My Night / Theme! "), "my-night-theme");
});

test("a save is refused for an empty or taken name and for a bad colour", () => {
    assert.strictEqual(problem("", colours, []), "give it a name");
    assert.strictEqual(problem("Slate", colours, ["slate"]), "slate already exists");
    assert.strictEqual(problem("mine", Object.assign({}, colours, { mid: "blue" }), []), "mid needs a six digit hex colour");
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

test("a key missing from a file with tables goes above the first table", () => {
    const edited = editedToml('mode = "dark"\n\n[extras]\nx = "1"\n', colours);
    assert.ok(edited.indexOf("accent_dim") < edited.indexOf("[extras]"));
    assert.ok(edited.includes('x = "1"'));
});

test("single quoted values are replaced instead of duplicated", () => {
    const edited = editedToml("accent = '#7FB3D4'\n", colours);
    assert.strictEqual(edited.match(/^accent =/gm).length, 1);
    assert.ok(edited.includes('accent = "#223344"'));
});

test("a key inside a table is not taken for the top level one", () => {
    const edited = editedToml('mode = "dark"\n[extras]\norange = "#000000"\n', colours);
    assert.ok(edited.includes('[extras]\norange = "#000000"'));
    assert.ok(edited.indexOf('orange = "#445566"') < edited.indexOf("[extras]"));
});

test("the live preview keeps only valid colours that differ from the theme", () => {
    const current = { dim: "#000001", mid: "#000002", bright: "#000003", alarm: "#000004" };
    const shown = overridesFrom({ dim: "#aabbcc", mid: "#12", bright: "", alarm: "#ddeeff" }, current);
    assert.deepStrictEqual(shown, { dim: "#aabbcc", alarm: "#ddeeff" });
    assert.strictEqual(overridesFrom({ dim: "#000001", mid: "#12", bright: "", alarm: "#000004" }, current), null);
});
