import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";

function loadLogic() {
    const src = fs.readFileSync(path.resolve("services/agent-limits.js"), "utf8").replace(/^\.pragma library\s*/m, "");
    const ctx = { Date, Math, Number, Array, JSON, isFinite };
    vm.createContext(ctx);
    vm.runInContext(src, ctx);
    return ctx;
}

const Logic = loadLogic();

test("enabledProviders respects fixed order and toggles", () => {
    assert.deepEqual(Array.from(Logic.enabledProviders({ claude: true, antigravity: true, codex: false })), ["claude", "antigravity"]);
    assert.deepEqual(Array.from(Logic.enabledProviders({ codex: true, claude: false, antigravity: false })), ["codex"]);
    assert.deepEqual(Array.from(Logic.enabledProviders({})), []);
});

test("remainingPercent and remainingFraction clamp bounds", () => {
    assert.equal(Logic.remainingPercent(85), 15);
    assert.equal(Logic.remainingPercent(0), 100);
    assert.equal(Logic.remainingPercent(120), 0);
    assert.equal(Logic.remainingPercent(-5), 100);
    assert.equal(Logic.remainingFraction(25), 0.75);
});

test("paceFraction computes remaining time ratio for left-filled bars", () => {
    const now = Date.parse("2026-11-26T04:00:00Z");
    assert.equal(Logic.paceFraction("2026-11-26T06:30:00Z", 300, now), 0.5);
    assert.equal(Logic.paceFraction("2026-11-26T03:00:00Z", 300, now), 0);
    assert.equal(Logic.paceFraction("2026-11-27T04:00:00Z", 300, now), 1);
    assert.ok(Math.abs(Logic.paceFraction("2026-11-27T04:00:00Z", 10080, now) - 1 / 7) < 0.001);
    assert.equal(Logic.paceFraction("", 300, now), -1);
});

test("formatReset uses T3 Code style durations", () => {
    const now = Date.parse("2026-11-26T04:00:00Z");
    assert.equal(Logic.formatReset("2026-11-27T06:00:00Z", now), "1d 2h");
    assert.equal(Logic.formatReset("2026-11-26T08:12:00Z", now), "4h 12m");
    assert.equal(Logic.formatReset("2026-11-26T04:25:00Z", now), "25m");
    assert.equal(Logic.formatReset("", now), "");
});

test("compactEntries excludes extra windows like Antigravity partnership group", () => {
    const providers = [
        {
            id: "antigravity",
            name: "Antigravity",
            primary: [{ id: "gemini-5h", usedPercent: 20 }],
            extra: [{ id: "3p-5h", usedPercent: 100 }]
        }
    ];
    const compact = Logic.compactEntries(providers);
    assert.equal(compact.length, 1);
    assert.equal(compact[0].id, "antigravity");
    assert.deepEqual(compact[0].windows, [{ id: "gemini-5h", usedPercent: 20 }]);
});

test("barHeight maps size presets for rail and expanded sidebar", () => {
    assert.equal(Logic.barHeight("small", true), 48);
    assert.equal(Logic.barHeight("normal", true), 76);
    assert.equal(Logic.barHeight("tall", true), 112);
    assert.equal(Logic.barHeight("huge", true), 156);
    assert.equal(Logic.barHeight("tall", false), 80);
    assert.equal(Logic.barHeight("unknown", true), 112);
});

test("mergeReadings keeps last good reading when a poll errors", () => {
    const prev = [{ id: "claude", name: "Claude", primary: [{ id: "seven_day", usedPercent: 85 }], extra: [], error: "" }];
    const incoming = [{ id: "claude", name: "Claude", primary: [], extra: [], error: "timeout" }];
    const merged = Logic.mergeReadings(prev, incoming, ["claude"]);
    assert.equal(merged.length, 1);
    assert.equal(merged[0].primary[0].usedPercent, 85);
    assert.equal(merged[0].error, "timeout");
});
