const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/wall-clock.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Ticks = new Function(src + "\nreturn { floorTo, after };")();

const MINUTE = 60000;
const HOUR = 60 * MINUTE;

function inZone(zone, body) {
    const before = process.env.TZ;
    process.env.TZ = zone;
    try {
        body();
    } finally {
        if (before === undefined)
            delete process.env.TZ;
        else
            process.env.TZ = before;
    }
}

const utc = text => Date.parse(text);

test.describe("wall clock ticks", () => {
    test.it("schedules the next minute inside the repeated hour of a fall-back", () => {
        inZone("Europe/Copenhagen", () => {
            const now = utc("2026-10-25T01:47:30Z");
            assert.strictEqual(new Date(now).getHours(), 2);
            assert.strictEqual(Ticks.after(now, MINUTE), utc("2026-10-25T01:48:00Z"));
            assert.strictEqual(Ticks.floorTo(now, MINUTE), utc("2026-10-25T01:47:00Z"));
        });
    });

    test.it("ends each hour on the local hour, through both changes", () => {
        inZone("Europe/Copenhagen", () => {
            assert.strictEqual(Ticks.after(utc("2026-10-25T00:47:00Z"), HOUR), utc("2026-10-25T01:00:00Z"));
            assert.strictEqual(Ticks.after(utc("2026-10-25T01:47:00Z"), HOUR), utc("2026-10-25T02:00:00Z"));
            assert.strictEqual(Ticks.after(utc("2027-03-28T00:30:00Z"), HOUR), utc("2027-03-28T01:00:00Z"));
            assert.strictEqual(new Date(utc("2027-03-28T01:00:00Z")).getHours(), 3);
        });
    });

    test.it("keeps a half-hour zone on its own hour", () => {
        inZone("Asia/Kolkata", () => {
            const now = utc("2026-10-25T04:50:00Z");
            assert.strictEqual(new Date(now).getHours(), 10);
            assert.strictEqual(new Date(Ticks.floorTo(now, HOUR)).getMinutes(), 0);
            assert.strictEqual(Ticks.after(now, HOUR), utc("2026-10-25T05:30:00Z"));
        });
    });

});
