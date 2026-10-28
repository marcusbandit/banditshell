const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/launcher/placement.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Placement = new Function(`${src}\nreturn { searchAt, restTop, roomBelow, bornAt, LOWEST, HIGHEST };`)();

const BAR_OFFSET = 30;
const ROOM = 60 + 44 * 3;
const GAP = 34;

const SCREENS = [
    { name: "5120x1440", height: 1440, inset: 12 },
    { name: "1280x720", height: 720, inset: 12 },
    { name: "1024x600", height: 600, inset: 12 }
];

test.describe("launcher placement", () => {
    test.it("keeps the search bar, its room below and a gap above the frame on screen at every value", () => {
        for (const screen of SCREENS)
            for (let i = 10; i <= 60; i++) {
                const top = Placement.restTop(screen.height, i / 100, BAR_OFFSET, screen.inset, ROOM, GAP);
                const room = Placement.roomBelow(screen.height, top, screen.inset, GAP);
                assert.ok(top >= screen.inset, `${screen.name} at ${i}%: top ${top}`);
                assert.ok(room >= ROOM, `${screen.name} at ${i}%: only ${room} px below`);
                assert.strictEqual(top + room, screen.height - screen.inset - GAP, `${screen.name} at ${i}%`);
            }
    });

    test.it("caps a long list on a 720 px screen at the default so it ends a gap above the frame", () => {
        const top = Placement.restTop(720, 0.4, BAR_OFFSET, 12, ROOM, GAP);
        const list = 1200;
        const bottom = top + Math.min(list, Placement.roomBelow(720, top, 12, GAP));
        assert.strictEqual(bottom, 720 - 12 - GAP);
    });

    test.it("puts the middle of the search bar where the setting says", () => {
        assert.strictEqual(Placement.restTop(1440, 0.4, BAR_OFFSET, 12, ROOM, GAP) + BAR_OFFSET, 576);
        assert.strictEqual(Placement.restTop(1440, 0.5, BAR_OFFSET, 12, ROOM, GAP) + BAR_OFFSET, 720);
    });

    test.it("starts the tab where it was grabbed and has it in the middle by the time it opens", () => {
        assert.strictEqual(Placement.bornAt(240, 0, 800), 240);
        assert.strictEqual(Placement.bornAt(-240, 400, 800), -120);
        assert.strictEqual(Placement.bornAt(240, 800, 800), 0);
        assert.strictEqual(Placement.bornAt(240, 900, 800), 0);
        let last = 240;
        for (let lift = 0; lift <= 800; lift += 10) {
            const at = Placement.bornAt(240, lift, 800);
            assert.ok(at <= last, `moves back out at ${lift}`);
            last = at;
        }
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
