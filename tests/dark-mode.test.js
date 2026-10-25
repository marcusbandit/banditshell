const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/dark-mode.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Schemes = new Function(src + "\nreturn { parse, lightAfter, schemeFor, afterWrite };")();

function gsettings(held, fails) {
    return {
        held,
        set(value) {
            if (fails)
                return 1;
            this.held = value;
            return 0;
        },
        get() {
            return `'${this.held}'\n`;
        }
    };
}

function shown(store, light, on) {
    const before = Schemes.parse(store.get());
    const wanted = Schemes.schemeFor(on, light);
    const code = store.set(wanted);
    const settled = Schemes.afterWrite(code, wanted, before);
    return { settled, reread: Schemes.parse(store.get()) };
}

test("reads what gsettings prints and ignores what it is not", () => {
    assert.strictEqual(Schemes.parse("'prefer-dark'\n"), "prefer-dark");
    assert.strictEqual(Schemes.parse("color-scheme: 'prefer-light'"), "prefer-light");
    assert.strictEqual(Schemes.parse("No such key “color-scheme”"), "");
    assert.strictEqual(Schemes.parse("'sepia'"), "");
});

test("a failed write puts the switch back to what gsettings really holds", () => {
    const store = gsettings("default", true);
    const out = shown(store, "default", true);
    assert.deepStrictEqual(out, { settled: "default", reread: "default" });
});

test("a write that lands shows the new scheme", () => {
    const store = gsettings("default", false);
    assert.deepStrictEqual(shown(store, "default", true), { settled: "prefer-dark", reread: "prefer-dark" });
});

test("turning dark off returns a prefer-light user to prefer-light, not default", () => {
    const store = gsettings("prefer-light", false);
    let light = Schemes.lightAfter("default", Schemes.parse(store.get()));
    shown(store, light, true);
    light = Schemes.lightAfter(light, Schemes.parse(store.get()));
    assert.strictEqual(shown(store, light, false).reread, "prefer-light");
});

test("turning dark off on a machine that started dark writes default", () => {
    const store = gsettings("prefer-dark", false);
    const light = Schemes.lightAfter("default", Schemes.parse(store.get()));
    assert.strictEqual(shown(store, light, false).reread, "default");
});
