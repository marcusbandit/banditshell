const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const HyprlandLua = new Function(fs.readFileSync(path.join(ROOT, "services/hyprland-lua.js"), "utf8")
    + "\nreturn { scanLua, composeEntry, entryReplacement, spliceLines };")();
const Rules = new Function(fs.readFileSync(path.join(ROOT, "services/monitor-rules.js"), "utf8")
    + "\nreturn { mirrorSource, restingFields, entryFields, violation, mirroring, plan, mirrorChoices, turnsOn, turnsOff, writeOrder, dropTurnOffs, guardSpecs, parseMode, modeString, specFor, newEntry, entryFile, reached };")();

const DESK = {
    "HDMI-A-1": { output: "HDMI-A-1", mode: "5120x1440@144", position: "1200x240", scale: 1, transform: 0, vrr: 1, disabled: false, mirror: "" },
    "DP-1": { output: "DP-1", mode: "1920x1200@60", position: "0x0", scale: 1, transform: 1, vrr: 0, disabled: false, mirror: "" }
};

const MONITORS_LUA = [
    "local ultrawide     = \"HDMI-A-1\"",
    "local vertical_side = \"DP-1\"",
    "",
    "local hosts = {",
    "    banditbox = {",
    "        outputs = {",
    "            { output = vertical_side, mode = \"1920x1200@60\", position = \"0x0\",",
    "              scale = 1, transform = 1 },",
    "            { output = ultrawide, mode = \"5120x1440@144\", position = \"1200x240\",",
    "              scale = 1, transform = 0, bitdepth = 8, vrr = 1 },",
    "        },",
    "    },",
    "}",
    ""
].join("\n");

function rewrite(source, output, changed) {
    const entry = HyprlandLua.scanLua(source).monitors.find(m => m.output === output);
    return HyprlandLua.spliceLines(source, entry.startLine, entry.endLine, HyprlandLua.entryReplacement(source, entry, HyprlandLua.composeEntry(entry, changed)));
}

test("turning a screen off writes disabled = true and keeps the rest of the entry", () => {
    const next = rewrite(MONITORS_LUA, "DP-1", Rules.entryFields(Object.assign({}, DESK["DP-1"], { disabled: true })));
    const back = HyprlandLua.scanLua(next).monitors.find(m => m.output === "DP-1");
    assert.strictEqual(back.disabled, true);
    assert.strictEqual(back.dynamic, false);
    assert.ok(next.includes("output = vertical_side"), "the file's own alias survives");
    assert.ok(next.includes("bitdepth = 8"), "the neighbour is untouched");
    assert.ok(!/mirror/.test(next), "no mirror key is written for a screen that mirrors nothing");
});

test("turning a screen back on drops the disabled key instead of writing false", () => {
    const off = rewrite(MONITORS_LUA, "DP-1", Rules.entryFields(Object.assign({}, DESK["DP-1"], { disabled: true })));
    const on = rewrite(off, "DP-1", Rules.entryFields(DESK["DP-1"]));
    assert.ok(!/disabled/.test(on));
    assert.strictEqual(HyprlandLua.scanLua(on).monitors.find(m => m.output === "DP-1").disabled, undefined);
});

test("mirroring writes a quoted source and stopping drops it", () => {
    const mirrored = rewrite(MONITORS_LUA, "DP-1", Rules.entryFields(Object.assign({}, DESK["DP-1"], { mirror: "HDMI-A-1" })));
    assert.ok(mirrored.includes("mirror = \"HDMI-A-1\""));
    assert.strictEqual(HyprlandLua.scanLua(mirrored).monitors.find(m => m.output === "DP-1").mirror, "HDMI-A-1");
    const plain = rewrite(mirrored, "DP-1", Rules.entryFields(DESK["DP-1"]));
    assert.ok(!/mirror/.test(plain));
});

test("a screen that is off never writes a mirror", () => {
    const fields = Rules.entryFields(Object.assign({}, DESK["DP-1"], { disabled: true, mirror: "HDMI-A-1" }));
    assert.strictEqual(fields.mirror, null);
});

test("an appended entry for an unlisted screen can be off or mirrored", () => {
    const line = HyprlandLua.composeEntry(null, Object.assign({ output: "DP-2" }, Rules.entryFields({ mode: "1920x1080@60", position: "auto", scale: 1, transform: 0, vrr: 0, disabled: true, mirror: "" })));
    assert.ok(line.includes("disabled = true"));
    const mirrored = HyprlandLua.composeEntry(null, Object.assign({ output: "DP-2" }, Rules.entryFields({ mode: "1920x1080@60", position: "auto", scale: 1, transform: 0, vrr: 0, disabled: false, mirror: "DP-1" })));
    assert.ok(!mirrored.includes("disabled"));
    assert.ok(mirrored.includes("mirror = \"DP-1\""));
});

test("an entry whose disabled flag comes from a variable is left to the source", () => {
    const source = "hl.monitor({ output = \"DP-1\", mode = \"1920x1200@60\", disabled = away })\n";
    assert.strictEqual(HyprlandLua.scanLua(source).monitors[0].dynamic, true);
});

test("the last screen that is on cannot be turned off", () => {
    assert.strictEqual(Rules.plan(DESK, "DP-1", { disabled: true }).why, "");
    const one = { "DP-1": DESK["DP-1"], "HDMI-A-1": Object.assign({}, DESK["HDMI-A-1"], { disabled: true }) };
    const refused = Rules.plan(one, "DP-1", { disabled: true });
    assert.strictEqual(refused.why, "the last screen stays on");
    assert.deepStrictEqual(refused.fields, {});
    assert.strictEqual(Rules.violation({ "DP-1": Object.assign({}, DESK["DP-1"], { disabled: true }) }), "the last screen stays on");
});

test("turning a screen on is always allowed", () => {
    const one = { "DP-1": DESK["DP-1"], "HDMI-A-1": Object.assign({}, DESK["HDMI-A-1"], { disabled: true }) };
    assert.deepStrictEqual(Rules.plan(one, "HDMI-A-1", { disabled: false }).fields, { "HDMI-A-1": { disabled: false } });
});

test("a screen cannot mirror itself or a screen that is off", () => {
    assert.match(Rules.plan(DESK, "DP-1", { mirror: "DP-1" }).why, /itself/);
    const off = { "DP-1": DESK["DP-1"], "HDMI-A-1": Object.assign({}, DESK["HDMI-A-1"], { disabled: true }) };
    assert.match(Rules.plan(off, "DP-1", { mirror: "HDMI-A-1" }).why, /is off/);
    assert.match(Rules.plan(DESK, "DP-1", { mirror: "DP-9" }).why, /not connected/);
    assert.deepStrictEqual(Rules.plan(DESK, "DP-1", { mirror: "HDMI-A-1" }).fields, { "DP-1": { mirror: "HDMI-A-1" } });
});

test("mirrors cannot chain, which also rules out a loop", () => {
    const mirrored = { "DP-1": Object.assign({}, DESK["DP-1"], { mirror: "HDMI-A-1" }), "HDMI-A-1": DESK["HDMI-A-1"] };
    assert.match(Rules.plan(mirrored, "HDMI-A-1", { mirror: "DP-1" }).why, /cannot follow/);
    const three = Object.assign({}, mirrored, { "DP-2": Object.assign({}, DESK["DP-1"], { output: "DP-2" }) });
    assert.match(Rules.plan(three, "DP-2", { mirror: "DP-1" }).why, /mirrors HDMI-A-1/);
    assert.deepStrictEqual(Rules.mirrorChoices(three, "DP-2"), ["HDMI-A-1"]);
    assert.deepStrictEqual(Rules.mirrorChoices(three, "HDMI-A-1"), [], "a screen others follow has nothing to follow");
});

test("turning off a screen that others mirror frees them", () => {
    const mirrored = { "DP-1": Object.assign({}, DESK["DP-1"], { mirror: "HDMI-A-1" }), "HDMI-A-1": DESK["HDMI-A-1"] };
    const planned = Rules.plan(mirrored, "HDMI-A-1", { disabled: true });
    assert.strictEqual(planned.why, "");
    assert.deepStrictEqual(planned.fields, { "HDMI-A-1": { disabled: true, mirror: "" }, "DP-1": { mirror: "" } });
});

test("hyprctl says which screen a mirror follows, by name or by id", () => {
    const all = [{ id: 0, name: "HDMI-A-1" }, { id: 1, name: "DP-1" }];
    assert.strictEqual(Rules.mirrorSource({ mirrorOf: "none" }, all), "");
    assert.strictEqual(Rules.mirrorSource({ mirrorOf: 0 }, all), "HDMI-A-1");
    assert.strictEqual(Rules.mirrorSource({ mirrorOf: "0" }, all), "HDMI-A-1");
    assert.strictEqual(Rules.mirrorSource({ mirrorOf: "DP-1" }, all), "DP-1");
    assert.strictEqual(Rules.mirrorSource({ mirrorOf: "gone" }, all), "");
    assert.strictEqual(Rules.mirrorSource({}, all), "");
});

test("a screen that is off still has a mode and a place on the desk", () => {
    const reported = { x: 0, y: 0, width: 0, height: 0, refreshRate: 0, scale: 1, transform: 0, availableModes: ["1920x1200@59.95Hz", "1920x1080@60.00Hz"] };
    assert.strictEqual(Rules.restingFields(reported, null).mode, "1920x1200@60");
    assert.strictEqual(Rules.restingFields(Object.assign({}, reported, { width: 1920, height: 1200, refreshRate: 59.95 }), null).mode, "1920x1200@60");
    const entry = { mode: "2560x1440@144", position: "1200x0", scale: 1.5, transform: 1, vrr: 1 };
    assert.deepStrictEqual(Rules.restingFields(reported, entry), { mode: "2560x1440@144", position: "1200x0", scale: 1.5, transform: 1, vrr: 1 });
    assert.strictEqual(Rules.restingFields({ availableModes: [] }, null).mode, "preferred");
});

const LIVE = [{ name: "HDMI-A-1", disabled: false }, { name: "DP-1", disabled: true }];

test("a write that brings a screen back is ordered before one that turns another off", () => {
    const off = Object.assign({}, DESK["HDMI-A-1"], { disabled: true });
    const on = Object.assign({}, DESK["DP-1"], { disabled: false });
    const tweak = Object.assign({}, DESK["HDMI-A-1"], { scale: 2 });
    assert.strictEqual(Rules.turnsOn(on, LIVE), true);
    assert.strictEqual(Rules.turnsOff(off, LIVE), true);
    assert.strictEqual(Rules.turnsOn(tweak, LIVE), false);
    assert.deepStrictEqual(Rules.writeOrder([off, on], LIVE).map(s => s.output), ["DP-1", "HDMI-A-1"]);
    assert.deepStrictEqual(Rules.writeOrder([off, tweak, on], LIVE).map(s => s.output + s.disabled), ["DP-1false", "HDMI-A-1false", "HDMI-A-1true"]);
});

test("writes of the same kind keep the order they came in", () => {
    const live = [{ name: "A", disabled: false }, { name: "B", disabled: false }, { name: "C", disabled: false }];
    const list = ["C", "A", "B"].map(output => ({ output, disabled: true }));
    assert.deepStrictEqual(Rules.writeOrder(list, live).map(s => s.output), ["C", "A", "B"]);
});

test("when a turn-on fails the queued turn-offs are dropped and the rest stay", () => {
    const queued = { A: { output: "A", disabled: true }, B: { output: "B", disabled: false, scale: 2 } };
    assert.deepStrictEqual(Object.keys(Rules.dropTurnOffs(queued)), ["B"]);
    assert.deepStrictEqual(Rules.dropTurnOffs({}), {});
});

test("the last-screen guard counts what Hyprland has on, not what a failed write once asked for", () => {
    const outputs = [{ name: "HDMI-A-1", disabled: false }, { name: "DP-1", disabled: true }];
    const stale = { "HDMI-A-1": DESK["HDMI-A-1"], "DP-1": Object.assign({}, DESK["DP-1"], { disabled: false }) };
    const off = Object.assign({}, DESK["HDMI-A-1"], { disabled: true });
    assert.ok(Rules.violation(Rules.guardSpecs(outputs, stale, [off])));
    const both = Rules.guardSpecs(outputs, stale, [off, Object.assign({}, DESK["DP-1"], { disabled: false })]);
    assert.strictEqual(Rules.violation(both), "");
});

test("a screen already on its way off does not count as on for the next turn-off", () => {
    const outputs = [{ name: "HDMI-A-1", disabled: false }, { name: "DP-1", disabled: false }];
    const intents = { "HDMI-A-1": Object.assign({}, DESK["HDMI-A-1"], { disabled: true }), "DP-1": DESK["DP-1"] };
    const off = Object.assign({}, DESK["DP-1"], { disabled: true });
    assert.ok(Rules.violation(Rules.guardSpecs(outputs, intents, [off])));
});

test("with every live screen on, one turn-off is fine", () => {
    const outputs = [{ name: "HDMI-A-1", disabled: false }, { name: "DP-1", disabled: false }];
    const off = Object.assign({}, DESK["DP-1"], { disabled: true });
    assert.strictEqual(Rules.violation(Rules.guardSpecs(outputs, DESK, [off])), "");
});

function reportedScreen(over) {
    return Object.assign({
        name: "DP-1", description: "", id: 1, x: 0, y: 0, width: 1920, height: 1080, refreshRate: 60,
        scale: 1, transform: 0, vrr: false, availableModes: [], focused: false, disabled: false, mirror: ""
    }, over);
}

function writtenEntry(spec) {
    const line = HyprlandLua.composeEntry(null, Rules.newEntry(spec));
    return HyprlandLua.scanLua(`hl.monitor(${line})\n`).monitors[0];
}

test.describe("specFor, a screen that is on", () => {
    test.it("writes the mode, place, scale and turn the screen reports, and keeps it on", () => {
        const spec = Rules.specFor(reportedScreen({ name: "DP-1", width: 1920, height: 1080, refreshRate: 60, x: 0, y: 0 }), null);
        assert.deepStrictEqual(spec, { output: "DP-1", mode: "1920x1080@60", position: "0x0", scale: 1, transform: 0, vrr: 0, disabled: false, mirror: "" });
        assert.strictEqual(writtenEntry(spec).disabled, undefined, "no disabled key is written for a screen that is on");
    });

    test.it("keeps a fractional scale exactly as Hyprland reports it, in the config too", () => {
        for (const scale of [1.25, 1.333333, 1.6, 1.5]) {
            const spec = Rules.specFor(reportedScreen({ scale }), null);
            assert.strictEqual(spec.scale, scale);
            assert.strictEqual(writtenEntry(spec).scale, scale, `scale ${scale}`);
        }
    });

    test.it("writes a negative position with its minus signs", () => {
        const left = Rules.specFor(reportedScreen({ x: -1920, y: -240 }), null);
        assert.strictEqual(left.position, "-1920x-240");
        assert.strictEqual(writtenEntry(left).position, "-1920x-240");
        assert.strictEqual(writtenEntry(Rules.specFor(reportedScreen({ x: 0, y: -1080 }), null)).position, "0x-1080");
    });

    test.it("rounds a decimal refresh rate to whole hertz", () => {
        assert.strictEqual(Rules.specFor(reportedScreen({ refreshRate: 59.951 }), null).mode, "1920x1080@60");
        assert.strictEqual(Rules.specFor(reportedScreen({ width: 2560, height: 1440, refreshRate: 143.86 }), null).mode, "2560x1440@144");
        assert.strictEqual(Rules.specFor(reportedScreen({ width: 5120, height: 1440, refreshRate: 143.987 }), null).mode, "5120x1440@144");
    });

    test.it("writes the size and rate the screen runs at, whatever mode the config names", () => {
        assert.strictEqual(Rules.specFor(reportedScreen({ width: 1920, height: 1200, refreshRate: 59.95 }), { mode: "1920x1200@144" }).mode, "1920x1200@60");
        assert.strictEqual(Rules.specFor(reportedScreen({ width: 2560, height: 1440, refreshRate: 144 }), { mode: "1920x1200@144" }).mode, "2560x1440@144");
        assert.strictEqual(Rules.specFor(reportedScreen({}), { mode: "preferred" }).mode, "1920x1080@60");
    });

    test.it("writes a mirroring screen with its own mode and place, and the screen it follows", () => {
        const spec = Rules.specFor(reportedScreen({ name: "DP-1", width: 1920, height: 1200, refreshRate: 59.95, x: 1200, y: 240, mirror: "HDMI-A-1" }), null);
        assert.deepStrictEqual({ mode: spec.mode, position: spec.position, mirror: spec.mirror }, { mode: "1920x1200@60", position: "1200x240", mirror: "HDMI-A-1" });
        assert.strictEqual(writtenEntry(spec).mirror, "HDMI-A-1");
    });
});

test.describe("specFor, a screen that is off", () => {
    test.it("writes an off screen as off, with the mode and place its config entry gives it", () => {
        const config = { output: "DP-1", mode: "1920x1200@60", position: "0x0", scale: 1, transform: 1, vrr: 0 };
        const spec = Rules.specFor(reportedScreen({ name: "DP-1", width: 0, height: 0, refreshRate: 0, disabled: true, transform: 1 }), config);
        assert.deepStrictEqual(spec, { output: "DP-1", mode: "1920x1200@60", position: "0x0", scale: 1, transform: 1, vrr: 0, disabled: true, mirror: "" });
        const written = writtenEntry(spec);
        assert.strictEqual(written.disabled, true);
        assert.strictEqual(written.mode, "1920x1200@60");
    });

    test.it("writes an off screen with no mirror, even when Hyprland still reports one", () => {
        const spec = Rules.specFor(reportedScreen({ name: "DP-1", disabled: true, mirror: "HDMI-A-1" }), null);
        assert.strictEqual(spec.disabled, true);
        const written = writtenEntry(spec);
        assert.strictEqual(written.disabled, true);
        assert.strictEqual(written.mirror, undefined);
    });
});

test.describe("specFor, monitor names", () => {
    test.it("keeps a monitor name with spaces as the output it is written under", () => {
        const spec = Rules.specFor(reportedScreen({ name: "Dell Screen 1" }), null);
        assert.strictEqual(spec.output, "Dell Screen 1");
        assert.strictEqual(writtenEntry(spec).output, "Dell Screen 1");
    });

    test.it("writes a desc: output name whole, quotes included", () => {
        const name = "desc:Dell Inc. \"U2720Q\" 1A2B3C";
        assert.strictEqual(writtenEntry(Rules.specFor(reportedScreen({ name }), null)).output, name);
    });
});

test.describe("entryFile", () => {
    test.it("puts a new screen in the file that holds the host's outputs, else in monitors.lua", () => {
        assert.strictEqual(Rules.entryFile({ file: "lua/hosts.lua" }, [{ file: "lua/other.lua" }]), "lua/hosts.lua");
        assert.strictEqual(Rules.entryFile(null, [{ file: "lua/other.lua" }]), "lua/other.lua");
        assert.strictEqual(Rules.entryFile(null, []), "lua/monitors.lua");
        assert.strictEqual(Rules.entryFile(undefined, undefined), "lua/monitors.lua");
    });
});

test.describe("reached", () => {
    test.it("counts a write as reached once Hyprland reports the same mode, place, scale, turn and sync", () => {
        const want = Rules.specFor(reportedScreen({ scale: 1.25, x: 1920, transform: 1, vrr: true }), null);
        const live = Rules.specFor(reportedScreen({ scale: 1.2500001, x: 1920, transform: 1, vrr: true }), null);
        assert.strictEqual(Rules.reached(want, live), true);
    });

    test.it("keeps a write pending while any of mode, place, scale, turn or sync still differs", () => {
        const base = { scale: 1.25, x: 1920, transform: 1, vrr: true };
        const want = Rules.specFor(reportedScreen(base), null);
        for (const change of [{ refreshRate: 144 }, { x: 0 }, { scale: 1.5 }, { transform: 0 }, { vrr: false }]) {
            const live = Rules.specFor(reportedScreen(Object.assign({}, base, change)), null);
            assert.strictEqual(Rules.reached(want, live), false, JSON.stringify(change));
        }
    });

    test.it("settles an off screen whatever mirror was asked for before it went off", () => {
        const want = Rules.specFor(reportedScreen({ disabled: true, mirror: "HDMI-A-1" }), null);
        assert.strictEqual(Rules.reached(want, Rules.specFor(reportedScreen({ disabled: true, mirror: "" }), null)), true);
        assert.strictEqual(Rules.reached(want, Rules.specFor(reportedScreen({ disabled: false }), null)), false);
    });
});

test.describe("parseMode and modeString", () => {
    test.it("reads a mode Hyprland lists, with its decimal refresh rate", () => {
        assert.deepStrictEqual(Rules.parseMode("5120x1440@143.99Hz"), { w: 5120, h: 1440, hz: 143.99 });
        assert.deepStrictEqual(Rules.parseMode("1920x1080@59.94Hz"), { w: 1920, h: 1080, hz: 59.94 });
        assert.strictEqual(Rules.parseMode("1920x1080@60"), null);
        assert.strictEqual(Rules.parseMode("preferred"), null);
        assert.strictEqual(Rules.parseMode(undefined), null);
    });

    test.it("writes a mode as width, x, height, @ and the rate in whole hertz", () => {
        assert.strictEqual(Rules.modeString(1920, 1080, 59.94), "1920x1080@60");
        assert.strictEqual(Rules.modeString(2560, 1440, 143.86), "2560x1440@144");
        assert.strictEqual(Rules.modeString(1920, 1200, 59.4), "1920x1200@59");
    });
});
