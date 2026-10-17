const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/activities.js"), "utf8");
const A = new Function(src + "\nreturn { ACTIVE_MAX, LINGER_MS, ENDING_MS, LEVEL_MS, parseSpan, readProgress, push, update, end, remove, sweep, nextWake, ordered, itemOf, listLine, clockText, clockSample, timerRemaining, timerItem, timerItems, alarmItem, alarmActions, levelIcon, levelMoment, levelDiffers, coveredKinds, levelWanted };")();

const NOW = 1_000_000;

function filled(...specs) {
    let list = [];
    let at = NOW;
    for (const spec of specs) {
        list = A.push(list, spec, at++).list;
    }
    return list;
}

test.describe("parseSpan", () => {
    test.it("reads units, combinations and bare seconds", () => {
        assert.strictEqual(A.parseSpan("30s"), 30000);
        assert.strictEqual(A.parseSpan("2m"), 120000);
        assert.strictEqual(A.parseSpan("1h30m"), 5400000);
        assert.strictEqual(A.parseSpan("500ms"), 500);
        assert.strictEqual(A.parseSpan("45"), 45000);
        assert.strictEqual(A.parseSpan("1.5s"), 1500);
        assert.strictEqual(A.parseSpan(" 10S "), 10000);
    });

    test.it("reads nothing as no limit", () => {
        assert.strictEqual(A.parseSpan(""), 0);
        assert.strictEqual(A.parseSpan(undefined), 0);
        assert.strictEqual(A.parseSpan(0), 0);
    });

    test.it("refuses what is not a span", () => {
        assert.strictEqual(A.parseSpan("soon"), -1);
        assert.strictEqual(A.parseSpan("10x"), -1);
        assert.strictEqual(A.parseSpan("1h 30m extra"), -1);
        assert.strictEqual(A.parseSpan("30d"), -1);
        assert.strictEqual(A.parseSpan(-5), -1);
        assert.strictEqual(A.parseSpan("8d"), -1);
    });
});

test.describe("readProgress", () => {
    test.it("leaves an empty value unset", () => {
        assert.deepStrictEqual(A.readProgress(""), { unset: true });
        assert.deepStrictEqual(A.readProgress(undefined), { unset: true });
    });

    test.it("clamps above one and turns any negative into unknown", () => {
        assert.strictEqual(A.readProgress("0.4").value, 0.4);
        assert.strictEqual(A.readProgress(7).value, 1);
        assert.strictEqual(A.readProgress("-1").value, -1);
        assert.strictEqual(A.readProgress(-0.3).value, -1);
        assert.strictEqual(A.readProgress(0).value, 0);
        assert.strictEqual(A.readProgress("unknown").value, -1);
    });

    test.it("refuses text", () => {
        assert.ok(A.readProgress("half").error);
    });
});

test.describe("push", () => {
    test.it("makes an entry with defaults", () => {
        const { entry, list } = A.push([], { id: "build", text: "Building" }, NOW);
        assert.strictEqual(list.length, 1);
        assert.strictEqual(entry.kind, "external");
        assert.strictEqual(entry.progress, -1);
        assert.strictEqual(entry.priority, 0);
        assert.strictEqual(entry.deadline, 0);
        assert.strictEqual(entry.state, "running");
    });

    test.it("takes a deadline from until", () => {
        const { entry } = A.push([], { id: "a", text: "A", until: "30s" }, NOW);
        assert.strictEqual(entry.deadline, NOW + 30000);
    });

    test.it("collapses whitespace in text", () => {
        const { entry } = A.push([], { id: "a", text: "  two\n lines\t here " }, NOW);
        assert.strictEqual(entry.text, "two lines here");
    });

    test.it("refuses a bad id, missing text, unknown kind and a bad span", () => {
        assert.ok(A.push([], { id: "has space", text: "x" }, NOW).error);
        assert.ok(A.push([], { id: "", text: "x" }, NOW).error);
        assert.ok(A.push([], { id: "a" }, NOW).error);
        assert.ok(A.push([], { id: "a", text: "x", kind: "dictation" }, NOW).error);
        assert.ok(A.push([], { id: "a", text: "x", until: "later" }, NOW).error);
        assert.ok(A.push([], { id: "a", text: "x", progress: "lots" }, NOW).error);
        assert.ok(A.push([], { id: "a", text: "x".repeat(121) }, NOW).error);
    });

    test.it("leaves the list alone on an error", () => {
        const list = filled({ id: "a", text: "A" });
        assert.strictEqual(A.push(list, { id: "", text: "x" }, NOW).list, list);
    });

    test.it("replaces an entry with the same id and keeps its place in time", () => {
        const list = filled({ id: "a", text: "A" }, { id: "b", text: "B" });
        const again = A.push(list, { id: "a", text: "A again", progress: 0.5 }, NOW + 500);
        assert.strictEqual(again.list.length, 2);
        assert.strictEqual(again.entry.born, NOW);
        assert.strictEqual(again.entry.text, "A again");
    });

    test.it("holds at most twelve and drops the ended, then the weakest, then the oldest", () => {
        let list = [];
        for (let i = 0; i < A.ACTIVE_MAX; i++)
            list = A.push(list, { id: `a${i}`, text: "x", priority: i === 3 ? -5 : 0 }, NOW + i).list;
        list = A.push(list, { id: "extra", text: "x" }, NOW + 100).list;
        assert.strictEqual(list.length, A.ACTIVE_MAX);
        assert.ok(!list.some(e => e.id === "a3"));
        list = A.end(list, "a5", "done", NOW + 200).list;
        list = A.push(list, { id: "more", text: "x" }, NOW + 300).list;
        assert.ok(!list.some(e => e.id === "a5"));
        assert.ok(list.some(e => e.id === "more"));
    });
});

test.describe("update", () => {
    test.it("merges only what is given", () => {
        const list = filled({ id: "a", text: "A", detail: "step 1", progress: 0.2, icon: "build" });
        const next = A.update(list, "a", { progress: "0.6" }, NOW + 10).entry;
        assert.strictEqual(next.progress, 0.6);
        assert.strictEqual(next.text, "A");
        assert.strictEqual(next.detail, "step 1");
        assert.strictEqual(next.icon, "build");
    });

    test.it("can change text, detail, icon and priority", () => {
        const list = filled({ id: "a", text: "A" });
        const next = A.update(list, "a", { text: "B", detail: "now", icon: "bolt", priority: "5" }, NOW + 10).entry;
        assert.deepStrictEqual([next.text, next.detail, next.icon, next.priority], ["B", "now", "bolt", 5]);
    });

    test.it("empty detail clears it and empty text keeps the old one", () => {
        const list = filled({ id: "a", text: "A", detail: "x" });
        const next = A.update(list, "a", { text: "", detail: "" }, NOW + 10).entry;
        assert.strictEqual(next.text, "A");
        assert.strictEqual(next.detail, "");
    });

    test.it("restarts the deadline when until is given", () => {
        const list = filled({ id: "a", text: "A", until: "10s" });
        assert.strictEqual(A.update(list, "a", { until: "1m" }, NOW + 5000).entry.deadline, NOW + 65000);
    });

    test.it("refuses an unknown or ended activity and bad values", () => {
        const list = filled({ id: "a", text: "A" });
        assert.ok(A.update(list, "nope", { text: "x" }, NOW).error);
        assert.ok(A.update(list, "a", { progress: "x" }, NOW).error);
        assert.ok(A.update(list, "a", { until: "x" }, NOW).error);
        const ended = A.end(list, "a", "done", NOW).list;
        assert.ok(A.update(ended, "a", { text: "x" }, NOW).error);
    });
});

test.describe("end", () => {
    test.it("marks the outcome and lets it linger", () => {
        const list = filled({ id: "a", text: "A", progress: 0.3 });
        const done = A.end(list, "a", "done", NOW + 10).entry;
        assert.strictEqual(done.state, "ended");
        assert.strictEqual(done.outcome, "done");
        assert.strictEqual(done.progress, 1);
        assert.strictEqual(done.outcomeUntil, NOW + 10 + A.LINGER_MS);
        const failed = A.end(list, "a", "failed", NOW + 10).entry;
        assert.strictEqual(failed.progress, 0.3);
    });

    test.it("defaults to done and refuses an unknown outcome", () => {
        const list = filled({ id: "a", text: "A" });
        assert.strictEqual(A.end(list, "a", "", NOW).entry.outcome, "done");
        assert.ok(A.end(list, "a", "exploded", NOW).error);
        assert.ok(A.end(list, "missing", "done", NOW).error);
    });

    test.it("clears a deadline so it cannot expire mid-linger", () => {
        const list = filled({ id: "a", text: "A", until: "1s" });
        assert.strictEqual(A.end(list, "a", "done", NOW).entry.deadline, 0);
    });
});

test.describe("sweep and nextWake", () => {
    test.it("drops expired running entries and finished lingers", () => {
        let list = filled({ id: "gone", text: "x", until: "1s" }, { id: "kept", text: "x", until: "1m" }, { id: "open", text: "x" }, { id: "fin", text: "x" });
        list = A.end(list, "fin", "done", NOW).list;
        const swept = A.sweep(list, NOW + 2000 + A.LINGER_MS);
        assert.deepStrictEqual(swept.map(e => e.id).sort(), ["kept", "open"]);
    });

    test.it("returns the same list when nothing left", () => {
        const list = filled({ id: "a", text: "x", until: "1m" });
        assert.strictEqual(A.sweep(list, NOW + 10), list);
    });

    test.it("says how long until the next thing changes", () => {
        const list = filled({ id: "a", text: "x", until: "30s" }, { id: "b", text: "x", until: "5s" }, { id: "c", text: "x" });
        assert.strictEqual(A.nextWake(list, NOW + 1000), 4001);
        assert.strictEqual(A.nextWake(filled({ id: "c", text: "x" }), NOW), -1);
        assert.strictEqual(A.nextWake([], NOW), -1);
    });

    test.it("counts a lingering outcome", () => {
        const list = A.end(filled({ id: "a", text: "x" }), "a", "failed", NOW).list;
        assert.strictEqual(A.nextWake(list, NOW + 500), A.LINGER_MS - 500);
    });
});

test.describe("ordered", () => {
    test.it("puts priority first, then the newest", () => {
        const list = filled({ id: "old", text: "x" }, { id: "urgent", text: "x", priority: 9 }, { id: "new", text: "x" });
        assert.deepStrictEqual(A.ordered(list).map(e => e.id), ["urgent", "new", "old"]);
    });

    test.it("does not reorder the source", () => {
        const list = filled({ id: "a", text: "x" }, { id: "b", text: "x", priority: 1 });
        A.ordered(list);
        assert.deepStrictEqual(list.map(e => e.id), ["a", "b"]);
    });
});

test.describe("itemOf and listLine", () => {
    test.it("keys the island item by id and says whether it can be pressed", () => {
        const withAct = A.push([], { id: "a", text: "A", act: "true" }, NOW).entry;
        const without = A.push([], { id: "b", text: "B" }, NOW).entry;
        assert.strictEqual(A.itemOf(withAct).key, "external:a");
        assert.strictEqual(A.itemOf(withAct).pressable, true);
        assert.strictEqual(A.itemOf(without).pressable, false);
        assert.ok(!("act" in A.itemOf(withAct)));
    });

    test.it("prints one tab separated line per activity", () => {
        const list = filled({ id: "build", text: "Building", progress: 0.4, until: "30s" });
        assert.strictEqual(A.listLine(list[0], NOW + 10000), "build\trunning\t40%\tBuilding\t20s left");
        const done = A.end(list, "build", "done", NOW).list[0];
        assert.strictEqual(A.listLine(done, NOW), "build\tdone\t100%\tBuilding");
    });
});

test.describe("timers", () => {
    const timer = (fields) => Object.assign({ id: "t1", total: 600000, deadline: NOW + 600000, left: 0, paused: false, finished: false, label: "", quiet: false }, fields);

    test.it("writes the time left as a clock", () => {
        assert.strictEqual(A.clockText(0), "0:00");
        assert.strictEqual(A.clockText(9100), "0:10");
        assert.strictEqual(A.clockText(750000), "12:30");
        assert.strictEqual(A.clockText(3723000), "1:02:03");
    });

    test.it("sizes a row for the widest time it will show", () => {
        assert.strictEqual(A.clockSample(90000), "00:00");
        assert.strictEqual(A.clockSample(7200000), "0:00:00");
    });

    test.it("counts down from the deadline, or holds when paused", () => {
        assert.strictEqual(A.timerRemaining(timer(), NOW + 100000), 500000);
        assert.strictEqual(A.timerRemaining(timer({ paused: true, left: 42000 }), NOW + 100000), 42000);
        assert.strictEqual(A.timerRemaining(timer(), NOW + 700000), 0);
        assert.strictEqual(A.timerRemaining(null, NOW), 0);
    });

    test.it("describes a timer with its fraction left", () => {
        const item = A.timerItem(timer({ label: "Tea" }), NOW + 150000);
        assert.strictEqual(item.key, "timer:t1");
        assert.strictEqual(item.text, "Tea");
        assert.strictEqual(item.clock, "7:30");
        assert.strictEqual(item.progress, 0.75);
        assert.strictEqual(item.ending, false);
    });

    test.it("falls back to a plain name", () => {
        assert.strictEqual(A.timerItem(timer(), NOW).text, "Timer");
    });

    test.it("is ending in the last ten seconds, but not while paused", () => {
        assert.strictEqual(A.timerItem(timer(), NOW + 600000 - A.ENDING_MS).ending, true);
        assert.strictEqual(A.timerItem(timer(), NOW + 600000 - A.ENDING_MS - 1000).ending, false);
        assert.strictEqual(A.timerItem(timer({ paused: true, left: 3000 }), NOW).ending, false);
    });

    test.it("lists running timers soonest first and leaves out finished and quiet ones", () => {
        const items = A.timerItems([
            timer({ id: "late", deadline: NOW + 900000, total: 900000 }),
            timer({ id: "soon", deadline: NOW + 60000, total: 60000 }),
            timer({ id: "done", finished: true }),
            timer({ id: "pomodoro", quiet: true })
        ], NOW);
        assert.deepStrictEqual(items.map(i => i.id), ["soon", "late"]);
    });
});

test.describe("alarms", () => {
    test.it("offers snooze only when the alarm can be snoozed", () => {
        assert.deepStrictEqual(A.alarmActions(true).map(a => a.name), ["snooze", "stop"]);
        assert.deepStrictEqual(A.alarmActions(false).map(a => a.name), ["stop"]);
    });

    test.it("keys the item by the alarm", () => {
        const item = A.alarmItem("x1", "07:30  Wake up", A.alarmActions(true));
        assert.strictEqual(item.key, "alarm:x1");
        assert.strictEqual(item.kind, "alarm");
        assert.strictEqual(item.actions.length, 2);
    });
});

test.describe("level moments", () => {
    test.it("picks a volume icon by how loud it is", () => {
        assert.strictEqual(A.levelIcon("volume", 0.1, false), "volume_mute");
        assert.strictEqual(A.levelIcon("volume", 0.5, false), "volume_down");
        assert.strictEqual(A.levelIcon("volume", 0.9, false), "volume_up");
        assert.strictEqual(A.levelIcon("volume", 0.9, true), "volume_off");
        assert.strictEqual(A.levelIcon("volume", 0, false), "volume_off");
    });

    test.it("picks a brightness icon by thirds", () => {
        assert.strictEqual(A.levelIcon("brightness", 0.1, false), "brightness_low");
        assert.strictEqual(A.levelIcon("brightness", 0.5, false), "brightness_medium");
        assert.strictEqual(A.levelIcon("brightness", 0.9, false), "brightness_high");
    });

    test.it("shows volume as a meter and a percentage", () => {
        const m = A.levelMoment("volume", 0.45, false, 1);
        assert.strictEqual(m.key, "level:volume");
        assert.strictEqual(m.kind, "level");
        assert.strictEqual(m.meter, 0.45);
        assert.strictEqual(m.readout, "45%");
        assert.strictEqual(m.ms, A.LEVEL_MS);
    });

    test.it("scales the meter by the boosted ceiling but reads out the real volume", () => {
        const m = A.levelMoment("volume", 0.75, false, 1.5);
        assert.strictEqual(m.meter, 0.5);
        assert.strictEqual(m.readout, "75%");
    });

    test.it("shows a mute without a meter value", () => {
        const m = A.levelMoment("volume", 0.45, true, 1);
        assert.strictEqual(m.meter, 0);
        assert.strictEqual(m.text, "Volume muted");
        assert.strictEqual(m.readout, "");
        assert.strictEqual(m.icon, "volume_off");
    });

    test.it("shows the microphone as a state", () => {
        const off = A.levelMoment("mic", 0.5, true, 1);
        assert.strictEqual(off.icon, "mic_off");
        assert.strictEqual(off.text, "Mic muted");
        assert.strictEqual(off.meter, -1);
        assert.strictEqual(A.levelMoment("mic", 0.5, false, 1).icon, "mic");
    });

    test.it("knows only three kinds", () => {
        assert.strictEqual(A.levelMoment("caps", 1, false, 1), null);
    });

    test.it("notices a real change and ignores noise", () => {
        assert.strictEqual(A.levelDiffers("volume", { value: 0.5, muted: false }, { value: 0.5, muted: false }), false);
        assert.strictEqual(A.levelDiffers("volume", { value: 0.5, muted: false }, { value: 0.502, muted: false }), false);
        assert.strictEqual(A.levelDiffers("volume", { value: 0.5, muted: false }, { value: 0.55, muted: false }), true);
        assert.strictEqual(A.levelDiffers("volume", { value: 0.5, muted: false }, { value: 0.5, muted: true }), true);
        assert.strictEqual(A.levelDiffers("mic", { value: 0.2, muted: false }, { value: 0.9, muted: false }), false);
        assert.strictEqual(A.levelDiffers("mic", { value: 0.2, muted: false }, { value: 0.2, muted: true }), true);
    });

    test.it("never compares with a reading it does not have yet", () => {
        assert.strictEqual(A.levelDiffers("volume", null, { value: 0.5, muted: false }), false);
    });
});

test.describe("surfaces that already show a level", () => {
    const covers = [{ kinds: ["volume", "mic"] }, { kinds: ["volume"] }, { kinds: ["brightness"] }];

    test.it("unites the kinds without repeats", () => {
        assert.deepStrictEqual(A.coveredKinds(covers), ["volume", "mic", "brightness"]);
        assert.deepStrictEqual(A.coveredKinds([]), []);
        assert.deepStrictEqual(A.coveredKinds(undefined), []);
    });

    test.it("wants a moment only when enabled and no open surface shows it", () => {
        assert.strictEqual(A.levelWanted(true, [], "volume"), true);
        assert.strictEqual(A.levelWanted(true, [{ kinds: ["volume"] }], "volume"), false);
        assert.strictEqual(A.levelWanted(true, [{ kinds: ["volume"] }], "brightness"), true);
        assert.strictEqual(A.levelWanted(false, [], "volume"), false);
    });
});
