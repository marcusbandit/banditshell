const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/alarms.js"), "utf8");
const Alarms = new Function(src + "\nreturn { weekdayOf, occurrence, nextClockTime, nextFor, lastFor, pendingFor };")();

const MONDAY = 0;
const SATURDAY = 5;
const SUNDAY = 6;
const EVERY_DAY = [0, 1, 2, 3, 4, 5, 6];

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

function utc(year, month, day, hour, minute) {
    return Date.UTC(year, month - 1, day, hour, minute, 0, 0);
}

function alarm(fields) {
    return Object.assign({ armed: true, hour: 7, minute: 0, days: [], at: 0, handledUntil: 0, snoozedUntil: 0 }, fields);
}

test.describe("weekdayOf", () => {
    test.it("counts from Monday", () => {
        inZone("Europe/Copenhagen", () => {
            assert.strictEqual(Alarms.weekdayOf(new Date(2026, 9, 12)), MONDAY);
            assert.strictEqual(Alarms.weekdayOf(new Date(2026, 9, 17)), SATURDAY);
            assert.strictEqual(Alarms.weekdayOf(new Date(2026, 9, 18)), SUNDAY);
        });
    });
});

test.describe("nextClockTime", () => {
    test.it("is later today, or tomorrow once today's has passed", () => {
        inZone("Europe/Copenhagen", () => {
            const at = local(2026, 10, 12, 8, 0);
            assert.strictEqual(Alarms.nextClockTime(9, 15, at), local(2026, 10, 12, 9, 15));
            assert.strictEqual(Alarms.nextClockTime(7, 0, at), local(2026, 10, 13, 7, 0));
            assert.strictEqual(Alarms.nextClockTime(8, 0, at), local(2026, 10, 13, 8, 0));
        });
    });
});

test.describe("nextFor", () => {
    test.it("is nothing for an alarm that is off", () => {
        assert.strictEqual(Alarms.nextFor(alarm({ armed: false, days: EVERY_DAY }), Date.now()), 0);
        assert.strictEqual(Alarms.nextFor(null, Date.now()), 0);
    });

    test.it("is the snooze while one is running", () => {
        const at = utc(2026, 10, 12, 6, 0);
        assert.strictEqual(Alarms.nextFor(alarm({ days: EVERY_DAY, snoozedUntil: at + 540000 }), at), at + 540000);
    });

    test.it("is the stored moment for a one-shot alarm until it passes", () => {
        const at = utc(2026, 10, 12, 6, 0);
        assert.strictEqual(Alarms.nextFor(alarm({ at: at + 60000 }), at), at + 60000);
        assert.strictEqual(Alarms.nextFor(alarm({ at: at - 60000 }), at), 0);
    });

    test.it("finds the next listed weekday", () => {
        inZone("Europe/Copenhagen", () => {
            const mondayMorning = local(2026, 10, 12, 8, 0);
            assert.strictEqual(Alarms.nextFor(alarm({ days: [MONDAY] }), mondayMorning), local(2026, 10, 19, 7, 0));
            assert.strictEqual(Alarms.nextFor(alarm({ days: [MONDAY] }), local(2026, 10, 12, 6, 0)), local(2026, 10, 12, 7, 0));
            assert.strictEqual(Alarms.nextFor(alarm({ days: [SATURDAY, SUNDAY] }), mondayMorning), local(2026, 10, 17, 7, 0));
        });
    });
});

test.describe("pendingFor", () => {
    test.it("is the last occurrence that has not been handled", () => {
        inZone("Europe/Copenhagen", () => {
            const due = local(2026, 10, 12, 7, 0);
            const daily = alarm({ days: EVERY_DAY, handledUntil: due - 3600000 });
            assert.strictEqual(Alarms.pendingFor(daily, due + 5000), due);
            daily.handledUntil = due;
            assert.strictEqual(Alarms.pendingFor(daily, due + 5000), 0);
        });
    });

    test.it("waits for a snooze, then rings it once", () => {
        const at = utc(2026, 10, 12, 6, 0);
        const snoozed = alarm({ days: EVERY_DAY, snoozedUntil: at + 60000, handledUntil: at });
        assert.strictEqual(Alarms.pendingFor(snoozed, at + 30000), 0);
        assert.strictEqual(Alarms.pendingFor(snoozed, at + 61000), at + 60000);
        snoozed.handledUntil = at + 60000;
        assert.strictEqual(Alarms.pendingFor(snoozed, at + 62000), 0);
    });

    test.it("is nothing for an alarm that is off", () => {
        assert.strictEqual(Alarms.pendingFor(alarm({ armed: false, days: EVERY_DAY }), Date.now()), 0);
    });
});

test.describe("daylight saving, Europe/Copenhagen", () => {
    test.it("rings once at 03:30 when 02:30 does not exist", () => {
        inZone("Europe/Copenhagen", () => {
            const daily = alarm({ hour: 2, minute: 30, days: EVERY_DAY, handledUntil: utc(2026, 3, 28, 1, 30) });
            const saturdayNight = local(2026, 3, 28, 23, 0);
            const due = Alarms.nextFor(daily, saturdayNight);
            assert.strictEqual(due, utc(2026, 3, 29, 1, 30));
            assert.strictEqual(new Date(due).getHours(), 3);

            assert.strictEqual(Alarms.pendingFor(daily, due - 1000), 0);
            assert.strictEqual(Alarms.pendingFor(daily, due + 1000), due);
            daily.handledUntil = due;
            assert.strictEqual(Alarms.pendingFor(daily, due + 3600000), 0);
            assert.strictEqual(Alarms.nextFor(daily, due + 1000), utc(2026, 3, 30, 0, 30));
        });
    });

    test.it("rings once when 02:30 happens twice", () => {
        inZone("Europe/Copenhagen", () => {
            const daily = alarm({ hour: 2, minute: 30, days: EVERY_DAY, handledUntil: utc(2026, 10, 24, 0, 30) });
            const first = Alarms.nextFor(daily, local(2026, 10, 24, 23, 0));
            assert.strictEqual(first, utc(2026, 10, 25, 0, 30));

            assert.strictEqual(Alarms.pendingFor(daily, first + 1000), first);
            daily.handledUntil = first;

            const second = utc(2026, 10, 25, 1, 30);
            assert.strictEqual(new Date(second).getHours(), 2);
            assert.strictEqual(new Date(second).getMinutes(), 30);
            assert.strictEqual(Alarms.pendingFor(daily, second + 1000), 0);
            assert.strictEqual(Alarms.nextFor(daily, second + 1000), utc(2026, 10, 26, 1, 30));
        });
    });

    test.it("keeps a weekly alarm on its wall-clock time across the change", () => {
        inZone("Europe/Copenhagen", () => {
            const sundays = alarm({ hour: 9, minute: 0, days: [SUNDAY] });
            assert.strictEqual(Alarms.nextFor(sundays, local(2026, 10, 18, 10, 0)), utc(2026, 10, 25, 8, 0));
            assert.strictEqual(Alarms.nextFor(sundays, local(2026, 3, 22, 10, 0)), utc(2026, 3, 29, 7, 0));
            assert.strictEqual(Alarms.lastFor(sundays, local(2026, 10, 26, 12, 0)), utc(2026, 10, 25, 8, 0));
        });
    });

    test.it("moves a one-shot 02:30 to 03:30 on the night it does not exist", () => {
        inZone("Europe/Copenhagen", () => {
            assert.strictEqual(Alarms.nextClockTime(2, 30, local(2026, 3, 28, 23, 0)), utc(2026, 3, 29, 1, 30));
        });
    });
});

test.describe("daylight saving, America/New_York", () => {
    test.it("rings once at 03:15 when 02:15 does not exist", () => {
        inZone("America/New_York", () => {
            const daily = alarm({ hour: 2, minute: 15, days: EVERY_DAY, handledUntil: utc(2026, 3, 7, 7, 15) });
            const due = Alarms.nextFor(daily, local(2026, 3, 7, 23, 0));
            assert.strictEqual(due, utc(2026, 3, 8, 7, 15));
            assert.strictEqual(new Date(due).getHours(), 3);
            daily.handledUntil = due;
            assert.strictEqual(Alarms.pendingFor(daily, due + 3600000), 0);
        });
    });

    test.it("rings once when 01:30 happens twice", () => {
        inZone("America/New_York", () => {
            const daily = alarm({ hour: 1, minute: 30, days: EVERY_DAY, handledUntil: utc(2026, 10, 31, 5, 30) });
            const first = Alarms.nextFor(daily, local(2026, 10, 31, 23, 0));
            assert.strictEqual(first, utc(2026, 11, 1, 5, 30));
            daily.handledUntil = first;
            assert.strictEqual(Alarms.pendingFor(daily, utc(2026, 11, 1, 6, 31)), 0);
            assert.strictEqual(Alarms.nextFor(daily, utc(2026, 11, 1, 6, 31)), utc(2026, 11, 2, 6, 30));
        });
    });
});
