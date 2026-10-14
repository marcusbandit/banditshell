const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const HyprlandLua = new Function(fs.readFileSync(path.join(ROOT, "services/hyprland-lua.js"), "utf8")
    + "\nreturn { scanLua, composeEntry, entryReplacement, spliceLines };")();
const Rules = new Function(fs.readFileSync(path.join(ROOT, "services/monitor-rules.js"), "utf8")
    + "\nreturn { mirrorSource, restingFields, entryFields, violation, mirroring, plan, mirrorChoices };")();

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
