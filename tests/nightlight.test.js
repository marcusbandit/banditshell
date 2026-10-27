const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/nightlight.js"), "utf8");
const Night = new Function(src + "\nreturn { sunEvents, sunWindow, minutesOf, clockOf, timesWindow, windowFor, fractionAt, nextEdge, warmKelvin, nightAt };")();

const MINUTE = 60000;
const COPENHAGEN = { lat: 55.676, lon: 12.568 };
const TROMSO = { lat: 69.65, lon: 18.96 };
const SYDNEY = { lat: -33.87, lon: 151.21 };

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

function local(year, month, day, hour, minute) {
    return new Date(year, month - 1, day, hour, minute, 0, 0).getTime();
}

function clock(ms) {
    const d = new Date(ms);
    return d.getHours() * 60 + d.getMinutes();
}

test("clock text becomes minutes and back, and rejects what is not a time", () => {
    assert.strictEqual(Night.minutesOf("21:00"), 1260);
    assert.strictEqual(Night.minutesOf("7:05"), 425);
    assert.strictEqual(Night.minutesOf("24:00"), -1);
    assert.strictEqual(Night.minutesOf("21:60"), -1);
    assert.strictEqual(Night.minutesOf("tonight"), -1);
    assert.strictEqual(Night.clockOf(425), "07:05");
    assert.strictEqual(Night.clockOf(1260), "21:00");
});

test("sunset in Copenhagen in mid October falls where the almanac puts it", () => {
    inZone("Europe/Copenhagen", () => {
        const w = Night.sunWindow(local(2026, 10, 14, 12, 0), COPENHAGEN);
        assert.ok(Math.abs(clock(w.start) - (18 * 60 + 12)) <= 6, `sunset at ${clock(w.start)}`);
        assert.ok(Math.abs(clock(w.end) - (7 * 60 + 42)) <= 6, `sunrise at ${clock(w.end)}`);
        assert.strictEqual(new Date(w.end).getDate(), 15);
    });
});

test("after dark the window is the one already open, and by day it is the one coming", () => {
    inZone("Europe/Copenhagen", () => {
        const night = Night.sunWindow(local(2026, 10, 14, 23, 0), COPENHAGEN);
        assert.ok(night.start < local(2026, 10, 14, 23, 0) && night.end > local(2026, 10, 14, 23, 0));
        const dawn = Night.sunWindow(local(2026, 10, 15, 3, 0), COPENHAGEN);
        assert.strictEqual(dawn.start, night.start);
        assert.strictEqual(dawn.end, night.end);
        const noon = Night.sunWindow(local(2026, 10, 15, 12, 0), COPENHAGEN);
        assert.ok(noon.start > local(2026, 10, 15, 12, 0));
    });
});

test("the sun maths holds in the other hemisphere and across the date line of a zone", () => {
    inZone("Australia/Sydney", () => {
        const w = Night.sunWindow(local(2026, 10, 14, 12, 0), SYDNEY);
        assert.ok(Math.abs(clock(w.start) - (19 * 60 + 7)) <= 6, `sunset at ${clock(w.start)}`);
        assert.ok(w.end - w.start > 10 * 3600000 && w.end - w.start < 13 * 3600000);
    });
});

test("in the polar night the window never closes and in the midnight sun it never opens", () => {
    inZone("Europe/Oslo", () => {
        const winter = Night.sunWindow(local(2026, 12, 21, 12, 0), TROMSO);
        assert.strictEqual(winter.end, Infinity);
        assert.strictEqual(Night.fractionAt(local(2026, 12, 21, 12, 0), winter, 5 * MINUTE), 1);
        assert.strictEqual(Night.sunWindow(local(2026, 6, 21, 12, 0), TROMSO), null);
    });
});

test("no place means no sunset window", () => {
    assert.strictEqual(Night.sunWindow(Date.now(), null), null);
    assert.strictEqual(Night.windowFor("sunset", Date.now(), { place: null }), null);
});

test("set times that cross midnight open this evening, or opened last evening", () => {
    inZone("Europe/Copenhagen", () => {
        const evening = Night.timesWindow(local(2026, 10, 14, 12, 0), "21:00", "07:00");
        assert.strictEqual(evening.start, local(2026, 10, 14, 21, 0));
        assert.strictEqual(evening.end, local(2026, 10, 15, 7, 0));
        const small = Night.timesWindow(local(2026, 10, 15, 3, 0), "21:00", "07:00");
        assert.strictEqual(small.start, local(2026, 10, 14, 21, 0));
        assert.strictEqual(small.end, local(2026, 10, 15, 7, 0));
    });
});

test("set times inside one day, and times that are no window at all", () => {
    inZone("Europe/Copenhagen", () => {
        const day = Night.timesWindow(local(2026, 10, 14, 16, 0), "13:00", "15:00");
        assert.strictEqual(day.start, local(2026, 10, 15, 13, 0));
        const open = Night.timesWindow(local(2026, 10, 14, 14, 0), "13:00", "15:00");
        assert.strictEqual(open.start, local(2026, 10, 14, 13, 0));
        assert.strictEqual(Night.timesWindow(Date.now(), "21:00", "21:00"), null);
        assert.strictEqual(Night.timesWindow(Date.now(), "nonsense", "07:00"), null);
    });
});

test("the night light is off before the window, eases in, holds, eases out and is off after", () => {
    inZone("Europe/Copenhagen", () => {
        const w = Night.windowFor("times", local(2026, 10, 14, 12, 0), { from: "21:00", to: "07:00" });
        const ease = 5 * MINUTE;
        const at = (h, m) => Night.fractionAt(local(2026, 10, 14, h, m), w, ease);
        assert.strictEqual(at(20, 59), 0);
        assert.strictEqual(at(21, 0), 0);
        assert.ok(at(21, 2) > 0 && at(21, 2) < 1);
        assert.ok(at(21, 3) > at(21, 2));
        assert.strictEqual(at(21, 5), 1);
        assert.strictEqual(at(23, 30), 1);
        assert.strictEqual(Night.fractionAt(local(2026, 10, 15, 6, 57), w, ease) < 1, true);
        assert.strictEqual(Night.fractionAt(local(2026, 10, 15, 6, 59), w, ease) > 0, true);
        assert.strictEqual(Night.fractionAt(local(2026, 10, 15, 7, 0), w, ease), 0);
        assert.strictEqual(Night.fractionAt(local(2026, 10, 15, 9, 0), w, ease), 0);
    });
});

test("a window shorter than the ease never reaches full", () => {
    const w = { start: 0, end: 4 * MINUTE };
    const peak = Math.max(...[0, 1, 2, 3].map(m => Night.fractionAt(m * MINUTE, w, 5 * MINUTE)));
    assert.ok(peak < 1);
});

test("the next edge is the start before a window, the end inside it, and nothing after", () => {
    const w = { start: 1000, end: 5000 };
    assert.strictEqual(Night.nextEdge(500, w), 1000);
    assert.strictEqual(Night.nextEdge(2000, w), 5000);
    assert.strictEqual(Night.nextEdge(6000, w), 0);
    assert.strictEqual(Night.nextEdge(1, null), 0);
});

test("the eased warmth runs from neutral down to the wanted kelvin", () => {
    assert.strictEqual(Night.warmKelvin(0, 6500, 3000), 6500);
    assert.strictEqual(Night.warmKelvin(1, 6500, 3000), 3000);
    assert.strictEqual(Night.warmKelvin(0.5, 6500, 3000), 4750);
});

test("the schedule is off for any mode it does not know", () => {
    assert.strictEqual(Night.windowFor("off", Date.now(), {}), null);
    assert.strictEqual(Night.windowFor("whenever", Date.now(), {}), null);
});

test.describe("auto light and dark follow the schedule", () => {
    test.it("turns dark at the start of set times and light again at their end", () => {
        const times = { from: "21:00", to: "07:00" };
        const before = Night.nightAt("times", local(2026, 10, 14, 20, 59), times);
        assert.deepStrictEqual([before.known, before.night, clock(before.next)], [true, false, 1260]);
        const after = Night.nightAt("times", local(2026, 10, 14, 21, 0), times);
        assert.deepStrictEqual([after.night, clock(after.next)], [true, 420]);
        assert.strictEqual(Night.nightAt("times", local(2026, 10, 15, 6, 59), times).night, true);
        const morning = Night.nightAt("times", local(2026, 10, 15, 7, 0), times);
        assert.deepStrictEqual([morning.night, clock(morning.next)], [false, 1260]);
    });

    test.it("flips at sunset and sunrise where the screens warm", () => {
        inZone("Europe/Copenhagen", () => {
            const w = Night.sunWindow(local(2026, 10, 14, 12, 0), COPENHAGEN);
            const settings = { place: COPENHAGEN };
            assert.strictEqual(Night.nightAt("sunset", w.start - MINUTE, settings).night, false);
            assert.strictEqual(Night.nightAt("sunset", w.start - MINUTE, settings).next, w.start);
            assert.strictEqual(Night.nightAt("sunset", w.start, settings).night, true);
            assert.strictEqual(Night.nightAt("sunset", w.end - MINUTE, settings).night, true);
            assert.strictEqual(Night.nightAt("sunset", w.end, settings).night, false);
        });
    });

    test.it("stays dark with no schedule to follow, and light through a polar day", () => {
        for (const [mode, settings] of [["off", {}], ["sunset", { place: null }], ["times", { from: "21:00", to: "21:00" }], ["times", { from: "late", to: "07:00" }]])
            assert.deepStrictEqual(Night.nightAt(mode, local(2026, 10, 14, 12, 0), settings), { known: false, night: true, next: 0 }, mode);
        const polar = Night.nightAt("sunset", local(2026, 6, 21, 12, 0), { place: TROMSO });
        assert.deepStrictEqual([polar.known, polar.night], [true, false]);
    });
});
