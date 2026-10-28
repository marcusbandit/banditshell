const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/keymap.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Keymap = new Function(src + "\nreturn { keyboard, shared, codes };")();
const fixture = name => fs.readFileSync(path.join(__dirname, "fixtures/hyprctl", name), "utf8");

test.describe("keyboard layout codes", () => {
    test.it("reads the main keyboard's layouts and variants from hyprctl", () => {
        const main = Keymap.keyboard(fixture("devices-us-us-intl.json"));
        assert.deepStrictEqual(main.layouts, ["us", "us"]);
        assert.deepStrictEqual(main.variants, ["", "intl"]);
        assert.strictEqual(main.index, 1);
        assert.strictEqual(main.name, "English (US, intl., with dead keys)");
    });

    test.it("keeps plain codes when every layout differs", () => {
        const main = Keymap.keyboard(fixture("devices-us-dk.json"));
        assert.deepStrictEqual(Keymap.codes(main.layouts, main.variants), ["US", "DK"]);
        assert.strictEqual(Keymap.shared(main.layouts, 0), false);
    });

    test.it("tells two layouts with the same code apart by their variant", () => {
        const main = Keymap.keyboard(fixture("devices-us-us-intl.json"));
        assert.deepStrictEqual(Keymap.codes(main.layouts, main.variants), ["US", "US-I"]);
        assert.strictEqual(Keymap.shared(main.layouts, 0), true);
        assert.deepStrictEqual(Keymap.codes(["us", "us", "dk"], ["dvorak", "intl", ""]), ["US-D", "US-I", "DK"]);
        assert.deepStrictEqual(Keymap.codes(["us", "us"], ["intl", "altgr-intl"]), ["US-I", "US-A"]);
        assert.deepStrictEqual(Keymap.codes(["de", "de"], ["nodeadkeys", "neo"]), ["DE-NO", "DE-NE"]);
    });

    test.it("keeps variants in step with layouts when a layout is left empty", () => {
        const main = Keymap.keyboard(JSON.stringify({ keyboards: [{ main: true, layout: "us,,us", variant: ",x,intl" }] }));
        assert.deepStrictEqual(main.layouts, ["us", "us"]);
        assert.deepStrictEqual(main.variants, ["", "intl"]);
    });

    test.it("reads nothing from output that is not a device list", () => {
        assert.strictEqual(Keymap.keyboard("not json"), null);
        assert.strictEqual(Keymap.keyboard("{}"), null);
    });
});
