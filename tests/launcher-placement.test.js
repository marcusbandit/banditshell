const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/launcher/placement.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Placement = new Function(`${src}\nreturn { searchAt, restTop, LOWEST, HIGHEST };`)();

const BAR_OFFSET = 30;
const ROOM = 60 + 44 * 3;

const SCREENS = [
    { name: "5120x1440", height: 1440, inset: 12 },
    { name: "1280x720", height: 720, inset: 12 },
    { name: "1024x600", height: 600, inset: 12 }
];

test.describe("launcher placement", () => {
    test.it("keeps the search bar and its room below on screen at every value", () => {
        for (const screen of SCREENS)
            for (let i = -20; i <= 120; i++) {
                const top = Placement.restTop(screen.height, i / 100, BAR_OFFSET, screen.inset, ROOM);
                assert.ok(top >= screen.inset, `${screen.name} at ${i}%: top ${top}`);
                assert.ok(top + ROOM <= screen.height - screen.inset, `${screen.name} at ${i}%: room ends at ${top + ROOM}`);
            }
    });

    test.it("puts the middle of the search bar where the setting says", () => {
        assert.strictEqual(Placement.restTop(1440, 0.4, BAR_OFFSET, 12, ROOM) + BAR_OFFSET, 576);
        assert.strictEqual(Placement.restTop(1440, 0.5, BAR_OFFSET, 12, ROOM) + BAR_OFFSET, 720);
    });

    test.it("holds the setting inside its range, so 1 no longer leaves a sliver and 0 stays below the top", () => {
        assert.strictEqual(Placement.searchAt(1), Placement.HIGHEST);
        assert.strictEqual(Placement.searchAt(0), Placement.LOWEST);
        assert.strictEqual(Placement.searchAt(-3), Placement.LOWEST);
        assert.strictEqual(Placement.searchAt(0.33), 0.33);
    });

    test.it("offers in Settings exactly the range the launcher keeps", () => {
        const catalogue = fs.readFileSync(path.join(ROOT, "modules/settings/catalogue.js"), "utf8");
        const row = catalogue.split("\n").find(line => line.includes('cfg: "launcher.list.searchAt"'));
        assert.match(row, new RegExp(`min: ${Placement.LOWEST}, max: ${Placement.HIGHEST},`));
    });
});
