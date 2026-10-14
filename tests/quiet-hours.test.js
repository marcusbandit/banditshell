const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/quiet-hours.js"), "utf8");
const Quiet = new Function(src + "\nreturn { minutesOf, nightlyActive, holding, deadlineFor, endsLabel, clockTime, parseEnds };")();

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

const at = (hour, minute, day = 14) => new Date(2026, 9, day, hour, minute, 0, 0).getTime();

test("times of day are read as minutes, and nonsense is refused", () => {
    assert.strictEqual(Quiet.minutesOf("22:00"), 1320);
    assert.strictEqual(Quiet.minutesOf("7:30"), 450);
    assert.strictEqual(Quiet.minutesOf("24:00"), -1);
    assert.strictEqual(Quiet.minutesOf("noon"), -1);
    assert.strictEqual(Quiet.minutesOf(undefined), -1);
});

test("a night that crosses midnight holds on both sides of it", () => {
    inZone("Europe/Copenhagen", () => {
        assert.ok(Quiet.nightlyActive(at(22, 0), "22:00", "07:30"));
        assert.ok(Quiet.nightlyActive(at(23, 59), "22:00", "07:30"));
        assert.ok(Quiet.nightlyActive(at(0, 0, 15), "22:00", "07:30"));
        assert.ok(Quiet.nightlyActive(at(7, 29), "22:00", "07:30"));
        assert.ok(!Quiet.nightlyActive(at(7, 30), "22:00", "07:30"));
        assert.ok(!Quiet.nightlyActive(at(12, 0), "22:00", "07:30"));
        assert.ok(!Quiet.nightlyActive(at(21, 59), "22:00", "07:30"));
    });
});

test("a window inside one day holds only inside it, and a broken one never holds", () => {
    inZone("Europe/Copenhagen", () => {
        assert.ok(Quiet.nightlyActive(at(13, 0), "13:00", "14:00"));
        assert.ok(!Quiet.nightlyActive(at(14, 0), "13:00", "14:00"));
        assert.ok(!Quiet.nightlyActive(at(3, 0), "22:00", "22:00"));
        assert.ok(!Quiet.nightlyActive(at(3, 0), "late", "07:30"));
    });
});

test("quiet holds until its deadline, by hand holds for ever, and the night holds on its own", () => {
    inZone("Europe/Copenhagen", () => {
        const base = { quiet: true, until: 0, nightly: false, from: "22:00", to: "07:30" };
        assert.ok(Quiet.holding(base, at(12, 0)));
        assert.ok(Quiet.holding(Object.assign({}, base, { until: at(13, 0) }), at(12, 59)));
        assert.ok(!Quiet.holding(Object.assign({}, base, { until: at(13, 0) }), at(13, 0)));
        assert.ok(!Quiet.holding(Object.assign({}, base, { quiet: false }), at(12, 0)));
        assert.ok(Quiet.holding(Object.assign({}, base, { quiet: false, nightly: true }), at(23, 0)));
        assert.ok(!Quiet.holding(Object.assign({}, base, { quiet: false, nightly: true }), at(12, 0)));
        assert.ok(Quiet.holding(Object.assign({}, base, { until: at(13, 0), nightly: true }), at(23, 0)));
    });
});

test("each choice computes its deadline when it is chosen", () => {
    inZone("Europe/Copenhagen", () => {
        assert.strictEqual(Quiet.deadlineFor("in an hour", at(10, 15), "07:30"), at(11, 15));
        assert.strictEqual(Quiet.deadlineFor("at 18:00", at(10, 15), "07:30"), at(18, 0));
        assert.strictEqual(Quiet.deadlineFor("at 18:00", at(18, 0), "07:30"), at(18, 0, 15));
        assert.strictEqual(Quiet.deadlineFor("at 18:00", at(19, 0), "07:30"), at(18, 0, 15));
        assert.strictEqual(Quiet.deadlineFor("tomorrow", at(23, 0), "07:30"), at(7, 30, 15));
        assert.strictEqual(Quiet.deadlineFor("tomorrow", at(3, 0), "07:30"), at(7, 30));
        assert.strictEqual(Quiet.deadlineFor("off by hand", at(10, 0), "07:30"), 0);
        assert.strictEqual(Quiet.deadlineFor("nonsense", at(10, 0), "07:30"), 0);
    });
});

test("a deadline reads back as the choice that made it", () => {
    inZone("Europe/Copenhagen", () => {
        const now = at(10, 15);
        for (const choice of ["in an hour", "at 18:00", "tomorrow", "off by hand"])
            assert.strictEqual(Quiet.endsLabel(Quiet.deadlineFor(choice, now, "07:30"), now, "07:30"), choice);
        assert.strictEqual(Quiet.endsLabel(at(11, 0), at(12, 0), "07:30"), "off by hand");
    });
});

test("the deadline reads as a clock time", () => {
    inZone("Europe/Copenhagen", () => {
        assert.strictEqual(Quiet.clockTime(at(9, 5)), "09:05");
        assert.strictEqual(Quiet.clockTime(at(18, 0)), "18:00");
    });
});

test("the command line says its choices short, and anything else is refused", () => {
    assert.strictEqual(Quiet.parseEnds("hour"), "in an hour");
    assert.strictEqual(Quiet.parseEnds("  At 18:00 "), "at 18:00");
    assert.strictEqual(Quiet.parseEnds("evening"), "at 18:00");
    assert.strictEqual(Quiet.parseEnds(""), "off by hand");
    assert.strictEqual(Quiet.parseEnds("never"), "off by hand");
    assert.strictEqual(Quiet.parseEnds("constructor"), "");
    assert.strictEqual(Quiet.parseEnds("soon"), "");
});
