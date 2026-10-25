const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/quiet-hours.js"), "utf8");
const Quiet = new Function(src + "\nreturn { minutesOf, nightlyActive, holding, deadlineFor, endsLabel, clockTime, parseEnds, quietLine, hushUntil, endsAt, hushChoices };")();

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

test("the quiet line names when it ends, and says nothing while it is not quiet", () => {
    inZone("UTC", () => {
        const at = new Date(2026, 9, 17, 14, 0, 0).getTime();
        const until = new Date(2026, 9, 17, 18, 0, 0).getTime();
        const off = { quiet: false, until: 0, nightly: false, from: "22:00", to: "07:30" };
        assert.strictEqual(Quiet.quietLine(off, at), "");
        assert.strictEqual(Quiet.quietLine(Object.assign({}, off, { quiet: true, until }), at), "Quiet until 18:00");
        assert.strictEqual(Quiet.quietLine(Object.assign({}, off, { quiet: true }), at), "Quiet until you turn it off");
        assert.strictEqual(Quiet.quietLine(Object.assign({}, off, { quiet: true, until }), until + 1), "");
        const night = new Date(2026, 9, 17, 23, 0, 0).getTime();
        assert.strictEqual(Quiet.quietLine(Object.assign({}, off, { nightly: true }), night), "Quiet until 07:30");
        assert.strictEqual(Quiet.quietLine(Object.assign({}, off, { nightly: true }), at), "");
    });
});

const MIN = 60 * 1000;
const HOUR = 60 * MIN;

test("a press snoozes or mutes until an hour from now, the night's end, or for good", () => {
    const at = (day, h, m) => new Date(2026, 9, day, h, m).getTime();
    assert.strictEqual(Quiet.hushUntil("hour", at(25, 10, 15), "07:30"), at(25, 11, 15));
    assert.strictEqual(Quiet.hushUntil("always", at(25, 10, 15), "07:30"), 0);
    assert.strictEqual(Quiet.hushUntil("tomorrow", at(25, 23, 0), "07:30"), at(26, 7, 30));
    assert.strictEqual(Quiet.hushUntil("tomorrow", at(25, 3, 0), "07:30"), at(25, 7, 30));
    assert.strictEqual(Quiet.hushUntil("tomorrow", at(25, 7, 30), "07:30"), at(26, 7, 30));
    assert.strictEqual(Quiet.hushUntil("tomorrow", at(31, 22, 0), "07:30"), new Date(2026, 10, 1, 7, 30).getTime());
    assert.strictEqual(Quiet.hushUntil("tomorrow", at(25, 20, 0), ""), at(26, 0, 0));
    assert.strictEqual(Quiet.hushUntil("later", at(25, 20, 0), "07:30"), -1);
});

test("an end reads as a clock time within a day, a weekday within the week, else a date", () => {
    const at = (day, h, m) => new Date(2026, 9, day, h, m).getTime();
    assert.strictEqual(Quiet.endsAt(at(26, 7, 30), at(25, 23, 0)), "07:30");
    assert.strictEqual(Quiet.endsAt(at(26, 0, 24), at(25, 23, 24)), "00:24");
    assert.strictEqual(Quiet.endsAt(at(26, 23, 0), at(25, 23, 0)), "Mon 23:00");
    assert.strictEqual(Quiet.endsAt(at(31, 8, 0), at(25, 9, 0)), "Sat 08:00");
    assert.strictEqual(Quiet.endsAt(at(31, 9, 0), at(25, 9, 0)), "31 Oct");
    assert.strictEqual(Quiet.endsAt(at(25, 8, 0), at(25, 9, 0)), "");
});

test("each choice leads with how long and ends with the time it stops", () => {
    const at = (day, h, m) => new Date(2026, 9, day, h, m).getTime();
    const late = Quiet.hushChoices(at(25, 23, 0), "07:30");
    assert.deepStrictEqual(late.map(c => `${c.text} ${c.detail}`), ["1 hour · until 00:00", "until morning · 07:30"]);
    assert.deepStrictEqual(late.map(c => c.until), [at(26, 0, 0), at(26, 7, 30)]);
    const early = Quiet.hushChoices(at(25, 7, 0), "07:30");
    assert.deepStrictEqual(early.map(c => c.choice), ["tomorrow", "hour"]);
});
