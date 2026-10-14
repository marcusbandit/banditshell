const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
const Apps = new Function(`${read("services/usage-apps.js")}\nreturn { dayKey, credit, prune, top, total, sanitise, merge, same };`)();
const Limits = new Function(`${read("services/usage-limits.js")}\nreturn { beginClock, advanceClock, overCap, shaderOwner, breakNote };`)();

const MINUTE = 60 * 1000;

test("a day key is the local date, zero padded", () => {
    assert.strictEqual(Apps.dayKey(new Date(2026, 0, 5, 23, 59)), "2026-01-05");
});

test("time is credited to the app, per day, without touching the input", () => {
    const empty = {};
    const one = Apps.credit(empty, "2026-10-14", "firefox", 2 * MINUTE);
    const two = Apps.credit(one, "2026-10-14", "firefox", MINUTE);
    const other = Apps.credit(two, "2026-10-15", "kitty", MINUTE);
    assert.deepStrictEqual(empty, {});
    assert.strictEqual(one["2026-10-14"].firefox, 2 * MINUTE);
    assert.strictEqual(two["2026-10-14"].firefox, 3 * MINUTE);
    assert.strictEqual(other["2026-10-15"].kitty, MINUTE);
});

test("nothing is credited for no app or no time", () => {
    const days = {};
    assert.strictEqual(Apps.credit(days, "2026-10-14", "", MINUTE), days);
    assert.strictEqual(Apps.credit(days, "2026-10-14", "kitty", 0), days);
    assert.strictEqual(Apps.credit(days, "2026-10-14", "kitty", -5), days);
});

test("days older than fourteen are pruned, the fourteenth stays", () => {
    const days = { "2026-09-30": { a: 1 }, "2026-10-01": { a: 1 }, "2026-10-14": { a: 1 } };
    const kept = Apps.prune(days, new Date(2026, 9, 14, 12));
    assert.deepStrictEqual(Object.keys(kept), ["2026-10-01", "2026-10-14"]);
});

test("pruning works across a month and year boundary", () => {
    const days = { "2025-12-19": { a: 1 }, "2025-12-20": { a: 1 }, "2026-01-02": { a: 1 } };
    const kept = Apps.prune(days, new Date(2026, 0, 2));
    assert.deepStrictEqual(Object.keys(kept), ["2025-12-20", "2026-01-02"]);
});

test("the top of a day is ranked by time, ties by name, and can be cut", () => {
    const days = { "2026-10-14": { zed: 10 * MINUTE, firefox: 98 * MINUTE, kitty: 10 * MINUTE, spotify: 12 * MINUTE, discord: 27 * MINUTE, steam: MINUTE } };
    const ranked = Apps.top(days, "2026-10-14", 5);
    assert.deepStrictEqual(ranked.map(e => e.appClass), ["firefox", "discord", "spotify", "kitty", "zed"]);
    assert.strictEqual(ranked[0].minutes, 98);
    assert.strictEqual(Apps.top(days, "2026-10-14").length, 6);
    assert.deepStrictEqual(Apps.top(days, "2026-10-13", 5), []);
});

test("a day's total is the sum of its apps", () => {
    assert.strictEqual(Apps.total({ d: { a: 5, b: 7 } }, "d"), 12);
    assert.strictEqual(Apps.total({}, "d"), 0);
});

test("a file with junk in it is cleaned, not trusted", () => {
    const clean = Apps.sanitise({ "2026-10-14": { firefox: 5, bad: "x", neg: -1, nan: null }, "not a day": { a: 1 }, "2026-10-13": [], "2026-10-12": {} });
    assert.deepStrictEqual(clean, { "2026-10-14": { firefox: 5 } });
    assert.deepStrictEqual(Apps.sanitise([1, 2]), {});
    assert.deepStrictEqual(Apps.sanitise(null), {});
});

test("merging another copy keeps the larger count per app", () => {
    const mine = { d: { a: 5, b: 9 } };
    const theirs = { d: { a: 8, c: 1 }, e: { z: 2 } };
    assert.deepStrictEqual(Apps.merge(mine, theirs), { d: { a: 8, b: 9, c: 1 }, e: { z: 2 } });
    assert.ok(Apps.same(Apps.merge(mine, mine), mine));
});

function run(everyMinutes, enabled, steps) {
    let clock = Limits.beginClock(0);
    const nudges = [];
    for (const [minute, idleMinutes] of steps) {
        const now = minute * MINUTE;
        const idleSince = idleMinutes === null ? null : now - idleMinutes * MINUTE;
        const result = Limits.advanceClock(clock, now, idleSince, everyMinutes, enabled);
        clock = result.clock;
        if (result.nudge)
            nudges.push(minute);
    }
    return nudges;
}

function minutes(from, to, idleMinutes) {
    const out = [];
    for (let m = from; m <= to; m++)
        out.push([m, idleMinutes === undefined ? null : idleMinutes]);
    return out;
}

test("the break nudge comes after the set time of unbroken use, and again every period after", () => {
    assert.deepStrictEqual(run(50, true, minutes(1, 160)), [50, 100, 150]);
});

test("short idle stretches do not break the run", () => {
    const steps = minutes(1, 20).concat(minutes(21, 24, 3), minutes(25, 60));
    assert.deepStrictEqual(run(50, true, steps), [50]);
});

test("an idle stretch of five minutes starts the count over", () => {
    const steps = minutes(1, 30).concat(minutes(31, 36, 5), minutes(37, 80));
    assert.deepStrictEqual(run(50, true, steps), []);
    const longer = minutes(1, 30).concat(minutes(31, 36, 5), minutes(37, 100));
    assert.deepStrictEqual(run(50, true, longer), [86]);
});

test("a gap in ticks as long as a break counts as one", () => {
    assert.deepStrictEqual(run(50, true, [[40, null], [41, null]].concat(minutes(200, 250))), [250]);
});

test("switching breaks off stays quiet, and switching them on does not fire at once", () => {
    let clock = Limits.beginClock(0);
    const fired = [];
    for (let minute = 1; minute <= 160; minute++) {
        const result = Limits.advanceClock(clock, minute * MINUTE, null, 50, minute > 120);
        clock = result.clock;
        if (result.nudge)
            fired.push(minute);
    }
    assert.deepStrictEqual(fired, [150]);
});

test("the cap is passed, not just reached", () => {
    assert.strictEqual(Limits.overCap(600, 10), false);
    assert.strictEqual(Limits.overCap(601, 10), true);
    assert.strictEqual(Limits.overCap(0, 10), false);
});

test("raising the cap past today's total lifts the grey", () => {
    assert.strictEqual(Limits.overCap(700, 10), true);
    assert.strictEqual(Limits.overCap(700, 12), false);
});

test("the screen shader slot is only touched when it is ours or empty", () => {
    const ours = "/shell/assets/shaders/desaturate.frag";
    assert.strictEqual(Limits.shaderOwner(JSON.stringify({ option: "decoration:screen_shader", str: "[[EMPTY]]", set: false }), ours), "free");
    assert.strictEqual(Limits.shaderOwner(JSON.stringify({ str: "" }), ours), "free");
    assert.strictEqual(Limits.shaderOwner(JSON.stringify({ str: "/home/a/.claude/worktrees/x/assets/shaders/desaturate.frag" }), ours), "ours");
    assert.strictEqual(Limits.shaderOwner(JSON.stringify({ str: ours }), ours), "ours");
    assert.strictEqual(Limits.shaderOwner(JSON.stringify({ str: "/home/me/crt.frag" }), ours), "foreign");
    assert.strictEqual(Limits.shaderOwner("not json", ours), "unknown");
});

test("the break note says how long it has been", () => {
    assert.ok(Limits.breakNote(50 * MINUTE).startsWith("50 minutes"));
});

test("the grey shader ships with the repo and only drains colour", () => {
    const shader = fs.readFileSync(path.join(ROOT, "assets/shaders/desaturate.frag"), "utf8");
    assert.ok(shader.startsWith("#version 300 es"));
    assert.ok(shader.includes("texture(tex, v_texcoord)"));
    assert.ok(shader.includes("pixel.a"));
});
