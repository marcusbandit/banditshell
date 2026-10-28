const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/launcher/placement.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Placement = new Function(`${src}\nreturn { searchAt, restTop };`)();

const BAR_OFFSET = 30;
const MARGIN = 12 + 34;
const FULL = 60 + 16 + 1 + 44 * 10 + 30 * 2;

const SCREENS = [1440, 1080, 720, 600];

const tallestOn = height => Math.min(height - MARGIN * 2, FULL);

test.describe("launcher placement", () => {
    test.it("keeps the launcher's full height on screen with the same margin top and bottom at every value", () => {
        for (const height of SCREENS)
            for (let i = 0; i <= 100; i++) {
                const tallest = tallestOn(height);
                const top = Placement.restTop(height, i / 100, BAR_OFFSET, MARGIN, tallest);
                assert.ok(top >= MARGIN, `${height} at ${i}%: top ${top}`);
                assert.ok(top + tallest <= height - MARGIN, `${height} at ${i}%: bottom ${top + tallest}`);
            }
    });

    test.it("moves the launcher up instead of shrinking it when the list would run past the bottom at 720 px", () => {
        const tallest = tallestOn(720);
        assert.strictEqual(tallest, FULL);
        const top = Placement.restTop(720, 0.4, BAR_OFFSET, MARGIN, tallest);
        assert.ok(top < 720 * 0.4 - BAR_OFFSET);
        assert.strictEqual(top + tallest, 720 - MARGIN);
    });

    test.it("puts the middle of the search bar where the setting says when it fits", () => {
        assert.strictEqual(Placement.restTop(1440, 0.4, BAR_OFFSET, MARGIN, FULL) + BAR_OFFSET, 576);
        assert.strictEqual(Placement.restTop(1440, 0.5, BAR_OFFSET, MARGIN, FULL) + BAR_OFFSET, 720);
    });

    test.it("works the lowest place out from the panel and the screen, not a fixed cap", () => {
        const low1440 = Placement.restTop(1440, 1, BAR_OFFSET, MARGIN, FULL);
        const low1080 = Placement.restTop(1080, 1, BAR_OFFSET, MARGIN, FULL);
        assert.strictEqual(low1440, 1440 - MARGIN - FULL);
        assert.strictEqual(low1080, 1080 - MARGIN - FULL);
        assert.ok((low1080 + BAR_OFFSET) / 1080 < (low1440 + BAR_OFFSET) / 1440);
    });

    test.it("offers in Settings the whole screen from top to bottom", () => {
        const catalogue = fs.readFileSync(path.join(ROOT, "modules/settings/catalogue.js"), "utf8");
        const row = catalogue.split("\n").find(line => line.includes('cfg: "launcher.list.searchAt"'));
        assert.match(row, /min: 0, max: 1,/);
        assert.match(row, /ends: \["top", "bottom"\]/);
    });
});
