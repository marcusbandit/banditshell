const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/ddcutil.js"), "utf8");
const Ddcutil = new Function(src + "\nreturn { parseDetect };")();

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
            { index: "1", name: "HDMI-A-1", model: "Odyssey G91SD", max: 100 },
            { index: "2", name: "DP-1", model: "HP E243i", max: 100 }
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
            { index: "1", name: "DP-1", model: "HP E243i", max: 100 }
        ]);
    });

    test.it("keeps a monitor line with no manufacturer prefix whole", () => {
        const text = "Display 3\n   DRM connector:    card2-DP-2\n   Monitor:          Generic Panel\n";
        assert.deepStrictEqual(Ddcutil.parseDetect(text), [
            { index: "3", name: "DP-2", model: "Generic Panel", max: 100 }
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
