const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const CONFIG = path.join(ROOT, "config/Config.qml");

function lib(file, names) {
    const src = fs.readFileSync(file, "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

function block(opener) {
    const text = fs.readFileSync(CONFIG, "utf8");
    const open = text.indexOf("{", text.indexOf(opener));
    let depth = 0;
    for (let j = open; j < text.length; j++) {
        if (text[j] === "{")
            depth++;
        else if (text[j] === "}" && --depth === 0)
            return text.slice(open, j + 1);
    }
    throw new Error(`unclosed ${opener}`);
}

const Scheme = lib(path.join(ROOT, "config/scheme.js"), ["modeOf", "isLight"]);
const Configuration = lib(path.join(ROOT, "config/configuration.js"), ["merge", "upgrade", "assign"]);
const DEFAULTS = new Function("UserFolders", `return (${block("readonly property var defaults:")});`)({ pictures: "/home/u/Pictures", shown: p => p.replace("/home/u", "~") });
const OPAQUE = new Function(`return ${fs.readFileSync(CONFIG, "utf8").match(/readonly property var opaque: (\[.*\])/)[1]};`)();
const LITERALS = new Function(`return (${block("readonly property var literals:")});`)();

const loaded = saved => Configuration.merge(DEFAULTS, Configuration.upgrade(saved), "", OPAQUE, LITERALS);

test("a config.json from before light themes still opens dark, with its own colours", () => {
    const saved = { theme: "greensteel", colour: { surface: 2, accent: "bright" }, material: { surfaceAlpha: 0.8, label: [0.9, 0.6, 0.5, 0.2] } };
    const values = loaded(saved);
    assert.strictEqual(values.colour.mode, "dark");
    assert.strictEqual(Scheme.isLight(values.colour.mode, true), false);
    assert.deepStrictEqual([values.theme, values.colour.surface, values.colour.accent], ["greensteel", 2, "bright"]);
    assert.deepStrictEqual(values.material.label, [0.9, 0.6, 0.5, 0.2]);
    assert.strictEqual(Scheme.isLight(loaded({}).colour.mode, true), false);
});

test("a chosen light, dark or auto survives a reload, and anything else reads as dark", () => {
    for (const mode of ["light", "dark", "auto"]) {
        const { values } = Configuration.assign(DEFAULTS, [["colour.mode", mode]], LITERALS);
        assert.strictEqual(loaded(values).colour.mode, mode);
    }
    for (const bad of ["sepia", "", 3, null])
        assert.strictEqual(Scheme.modeOf(loaded({ colour: { mode: bad } }).colour.mode), "dark", String(bad));
});

test("auto is light only while the schedule says it is day", () => {
    assert.deepStrictEqual([true, false].map(day => Scheme.isLight("auto", day)), [true, false]);
    assert.deepStrictEqual([true, false].map(day => Scheme.isLight("light", day)), [true, true]);
    assert.deepStrictEqual([true, false].map(day => Scheme.isLight("dark", day)), [false, false]);
});
