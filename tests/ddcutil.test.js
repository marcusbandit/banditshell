const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/ddcutil.js"), "utf8");
const Ddcutil = new Function(src + "\nreturn { parseDetect, target, rawLevel, restAfter };")();

const TWO_SCREENS = [
    "Display 1",
    "   I2C bus:          /dev/i2c-2",
    "   DRM connector:    card1-HDMI-A-1",
    "   drm_connector_id: 828",
    "   Monitor:          SAM:Odyssey G91SD:HNTY400178",
    "",
    "Display 2",
    "   I2C bus:          /dev/i2c-3",
    "   DRM connector:    card1-DP-1",
    "   drm_connector_id: 833",
    "   Monitor:          HPN:HP E243i:6CM9301BLK",
    ""
].join("\n");

test.describe("parseDetect", () => {
    test.it("reads every display with the connector name Hyprland uses", () => {
        assert.deepStrictEqual(Ddcutil.parseDetect(TWO_SCREENS), [
            { index: "1", bus: "2", name: "HDMI-A-1", model: "Odyssey G91SD", max: 100 },
            { index: "2", bus: "3", name: "DP-1", model: "HP E243i", max: 100 }
        ]);
    });

    test.it("does not let an invalid display's lines land on the one before it", () => {
        const text = [
            "Display 1",
            "   I2C bus:          /dev/i2c-3",
            "   DRM connector:    card1-DP-1",
            "   Monitor:          HPN:HP E243i:6CM9301BLK",
            "",
            "Invalid display",
            "   I2C bus:          /dev/i2c-6",
            "   DRM connector:    card0-eDP-1",
            "   Monitor:          BOE:NE135FBM-N41:",
            "   DDC communication failed",
            "",
            "Phantom display",
            "   I2C bus:          /dev/i2c-7",
            "   DRM connector:    card1-DP-3"
        ].join("\n");
        assert.deepStrictEqual(Ddcutil.parseDetect(text), [
            { index: "1", bus: "3", name: "DP-1", model: "HP E243i", max: 100 }
        ]);
    });

    test.it("keeps a monitor line with no manufacturer prefix whole", () => {
        const text = "Display 3\n   DRM connector:    card2-DP-2\n   Monitor:          Generic Panel\n";
        assert.deepStrictEqual(Ddcutil.parseDetect(text), [
            { index: "3", bus: "", name: "DP-2", model: "Generic Panel", max: 100 }
        ]);
    });

    test.it("drops a display it cannot name", () => {
        assert.deepStrictEqual(Ddcutil.parseDetect("Display 1\n   I2C bus: /dev/i2c-2\n"), []);
    });

    test.it("finds nothing in empty or missing output", () => {
        assert.deepStrictEqual(Ddcutil.parseDetect(""), []);
        assert.deepStrictEqual(Ddcutil.parseDetect(undefined), []);
        assert.deepStrictEqual(Ddcutil.parseDetect("No displays found.\n"), []);
    });
});

test.describe("target", () => {
    test.it("addresses a monitor by its i2c bus, so a monitor that drops off cannot renumber the others", () => {
        assert.deepStrictEqual(Ddcutil.target({ index: "1", bus: "2" }), ["--bus", "2"]);
    });

    test.it("falls back to the display number when there is no bus", () => {
        assert.deepStrictEqual(Ddcutil.target({ index: "3", bus: "" }), ["--display", "3"]);
    });
});

test.describe("rawLevel", () => {
    test.it("scales to the monitor's own maximum", () => {
        assert.strictEqual(Ddcutil.rawLevel(1, 50), 50);
        assert.strictEqual(Ddcutil.rawLevel(0.4, 50), 20);
        assert.strictEqual(Ddcutil.rawLevel(0.4, 100), 40);
    });

    test.it("never leaves 0 to max", () => {
        assert.strictEqual(Ddcutil.rawLevel(2, 50), 50);
        assert.strictEqual(Ddcutil.rawLevel(-1, 50), 0);
        assert.strictEqual(Ddcutil.rawLevel(NaN, 50), 0);
    });

    test.it("assumes 100 when the maximum is unknown", () => {
        assert.strictEqual(Ddcutil.rawLevel(0.4, undefined), 40);
        assert.strictEqual(Ddcutil.rawLevel(0.4, 0), 40);
    });
});

test.describe("restAfter", () => {
    test.it("doubles the rest a slow monitor needs, within bounds", () => {
        assert.strictEqual(Ddcutil.restAfter(undefined, 2500, 12000), 2500);
        assert.strictEqual(Ddcutil.restAfter(2500, 2500, 12000), 5000);
        assert.strictEqual(Ddcutil.restAfter(10000, 2500, 12000), 12000);
    });
});
