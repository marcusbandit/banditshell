const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const load = (file, names) => new Function(fs.readFileSync(path.join(ROOT, "services", file), "utf8") + `\nreturn { ${names.join(", ")} };`)();

const Battery = load("battery.js", ["lowStep", "countdownMessage", "afterResume", "nearlyEmptyFraction", "rearmMargin", "graceSeconds"]);
const Suspension = load("suspension.js", ["parseHibernate", "resolve", "commandFor"]);
const Lid = load("lid.js", ["internalOutput", "hasLid", "externalScreens", "chooseAction", "closedFrom", "closedFromProperty"]);
const Profile = load("powerprofile.js", ["nameFor", "profileFor", "parseProbe", "parseActive", "choices"]);
const Charge = load("chargelimit.js", ["parseProbe", "wanted", "shouldWrite", "trouble"]);

const onBattery = (percentage, extra) => Object.assign({ reading: true, onBattery: true, percentage, warnAt: 0.15, action: "suspend" }, extra);

test("the low battery steps warn once, count down at 5%, then act", () => {
    assert.deepStrictEqual(Battery.lowStep("ok", onBattery(0.5)), { stage: "ok", say: "" });
    assert.deepStrictEqual(Battery.lowStep("ok", onBattery(0.15)), { stage: "warned", say: "warn" });
    assert.deepStrictEqual(Battery.lowStep("warned", onBattery(0.1)), { stage: "warned", say: "" });
    assert.deepStrictEqual(Battery.lowStep("warned", onBattery(0.05)), { stage: "counting", say: "countdown" });
    assert.deepStrictEqual(Battery.lowStep("counting", onBattery(0.04)), { stage: "counting", say: "" });
});

test("a battery that goes straight under 5% only counts down, it does not warn twice", () => {
    assert.deepStrictEqual(Battery.lowStep("ok", onBattery(0.04)), { stage: "counting", say: "countdown" });
    assert.deepStrictEqual(Battery.lowStep("ok", onBattery(0.04, { warnAt: 0.05 })), { stage: "counting", say: "countdown" });
});

test("with nothing chosen the 5% step only warns", () => {
    assert.deepStrictEqual(Battery.lowStep("ok", onBattery(0.04, { action: "nothing" })), { stage: "warned", say: "warn" });
    assert.deepStrictEqual(Battery.lowStep("counting", onBattery(0.04, { action: "nothing" })), { stage: "warned", say: "" });
});

test("plugging in cancels the countdown and charging past the margin re-arms the warning", () => {
    assert.deepStrictEqual(Battery.lowStep("counting", onBattery(0.04, { onBattery: false })), { stage: "warned", say: "" });
    assert.deepStrictEqual(Battery.lowStep("acted", onBattery(0.04, { onBattery: false })), { stage: "warned", say: "" });
    assert.deepStrictEqual(Battery.lowStep("warned", onBattery(0.19, { onBattery: false })), { stage: "warned", say: "" });
    assert.deepStrictEqual(Battery.lowStep("warned", onBattery(0.21, { onBattery: false })), { stage: "ok", say: "" });
    assert.deepStrictEqual(Battery.lowStep("acted", onBattery(0.5)), { stage: "ok", say: "" });
});

test("after acting it waits for a resume before counting down again", () => {
    assert.deepStrictEqual(Battery.lowStep("acted", onBattery(0.03)), { stage: "acted", say: "" });
    assert.strictEqual(Battery.afterResume("acted"), "warned");
    assert.strictEqual(Battery.afterResume("counting"), "counting");
    assert.deepStrictEqual(Battery.lowStep(Battery.afterResume("acted"), onBattery(0.03)), { stage: "counting", say: "countdown" });
});

test("a battery that is not being read changes nothing", () => {
    assert.deepStrictEqual(Battery.lowStep("counting", onBattery(0.01, { reading: false })), { stage: "counting", say: "" });
});

test("the warning moves with the key", () => {
    assert.deepStrictEqual(Battery.lowStep("ok", onBattery(0.25, { warnAt: 0.3 })), { stage: "warned", say: "warn" });
    assert.deepStrictEqual(Battery.lowStep("warned", onBattery(0.3, { warnAt: 0.1 })), { stage: "ok", say: "" });
    assert.match(Battery.countdownMessage("hibernate", 30), /^Hibernating in 30 seconds/);
    assert.match(Battery.countdownMessage("suspend", 30), /^Suspending in 30 seconds/);
});

test("hibernate needs the disk state and a yes from logind, or swap when logind is silent", () => {
    const yes = '{"type":"s","data":["yes"]}';
    const swaps = "Filename\tType\tSize\tUsed\tPriority\n/swapfile\tfile\t16777212\t0\t-2\n";
    assert.strictEqual(Suspension.parseHibernate(`freeze mem disk\n---\n${swaps}---\n${yes}`), true);
    assert.strictEqual(Suspension.parseHibernate(`freeze mem\n---\n${swaps}---\n${yes}`), false);
    assert.strictEqual(Suspension.parseHibernate(`freeze mem disk\n---\n${swaps}---\n{"type":"s","data":["na"]}`), false);
    assert.strictEqual(Suspension.parseHibernate(`freeze mem disk\n---\n${swaps}---\n`), true);
    assert.strictEqual(Suspension.parseHibernate("freeze mem disk\n---\nFilename\tType\tSize\tUsed\tPriority\n---\n"), false);
    assert.strictEqual(Suspension.parseHibernate("freeze mem disk\n---\nFilename\tType\tSize\tUsed\tPriority\n/dev/zram0\tpartition\t100\t0\t100\n---\n"), false);
    assert.strictEqual(Suspension.parseHibernate(""), false);
});

test("a hibernate that cannot work falls back to suspend", () => {
    assert.strictEqual(Suspension.resolve("hibernate", false), "suspend");
    assert.strictEqual(Suspension.resolve("hibernate", true), "hibernate");
    assert.strictEqual(Suspension.resolve("lock", false), "lock");
    assert.deepStrictEqual(Suspension.commandFor("hibernate"), ["systemctl", "hibernate"]);
    assert.deepStrictEqual(Suspension.commandFor("lock"), []);
    assert.deepStrictEqual(Suspension.commandFor("nothing"), []);
});

const OUTPUTS = [{ name: "eDP-1" }, { name: "DP-1" }, { name: "HDMI-A-2", disabled: true }];
const ACTIONS = { onBattery: "suspend", pluggedIn: "lock", docked: "nothing" };

test("a lid is a lid switch or a built-in panel", () => {
    assert.strictEqual(Lid.hasLid(false, []), false);
    assert.strictEqual(Lid.hasLid(true, []), true);
    for (const name of ["eDP-1", "LVDS-1", "DSI-1"])
        assert.strictEqual(Lid.hasLid(false, [{ name }]), true, name);
    assert.strictEqual(Lid.hasLid(false, [{ name: "DP-1" }, { name: "HDMI-A-1" }]), false);
});

test("external screens count when they are on, and built-in panels never do", () => {
    assert.strictEqual(Lid.externalScreens(OUTPUTS), 1);
    assert.strictEqual(Lid.externalScreens([{ name: "eDP-1" }]), 0);
    assert.strictEqual(Lid.externalScreens([{ name: "HDMI-A-2", disabled: true }]), 0);
});

test("the lid does what the situation says, with screens attached ahead of power", () => {
    assert.strictEqual(Lid.chooseAction({ onBattery: true, external: 0 }, ACTIONS), "suspend");
    assert.strictEqual(Lid.chooseAction({ onBattery: false, external: 0 }, ACTIONS), "lock");
    assert.strictEqual(Lid.chooseAction({ onBattery: true, external: 1 }, ACTIONS), "nothing");
    assert.strictEqual(Lid.chooseAction({ onBattery: false, external: 2 }, ACTIONS), "nothing");
});

test("logind's lid word is read from a signal line or a property reply", () => {
    const line = "/org/freedesktop/login1: org.freedesktop.DBus.Properties.PropertiesChanged ('org.freedesktop.login1.Manager', {'LidClosed': <true>}, @as [])";
    assert.strictEqual(Lid.closedFrom(line), true);
    assert.strictEqual(Lid.closedFrom(line.replace("true", "false")), false);
    assert.strictEqual(Lid.closedFrom("/org/freedesktop/login1: org.freedesktop.DBus.Properties.PropertiesChanged ('org.freedesktop.login1.Manager', @a{sv} {}, ['LidClosed'])"), null);
    assert.strictEqual(Lid.closedFrom("/org/freedesktop/login1: org.freedesktop.login1.Manager.PrepareForSleep (true,)"), undefined);
    assert.strictEqual(Lid.closedFromProperty('{"type":"b","data":true}'), true);
    assert.strictEqual(Lid.closedFromProperty('{"type":"b","data":false}'), false);
    assert.strictEqual(Lid.closedFromProperty("nope"), undefined);
});

test("profiles map to each daemon's names and back", () => {
    assert.strictEqual(Profile.nameFor("ppd", "saver"), "power-saver");
    assert.strictEqual(Profile.nameFor("ppd", "fast"), "performance");
    assert.strictEqual(Profile.nameFor("tuned", "saver"), "powersave");
    assert.strictEqual(Profile.nameFor("tuned", "fast"), "throughput-performance");
    assert.strictEqual(Profile.nameFor("", "fast"), "");
    assert.strictEqual(Profile.profileFor("ppd", "power-saver"), "saver");
    assert.strictEqual(Profile.profileFor("ppd", "performance"), "fast");
    assert.strictEqual(Profile.profileFor("tuned", "balanced-battery"), "saver");
    assert.strictEqual(Profile.profileFor("tuned", "latency-performance"), "fast");
    assert.strictEqual(Profile.profileFor("tuned", "my-own"), "my-own");
});

test("the probe names the daemon and what it offers, and says nothing without one", () => {
    assert.deepStrictEqual(Profile.parseProbe("daemon ppd\nname performance\nname balanced\nname power-saver\n"), { daemon: "ppd", names: ["performance", "balanced", "power-saver"] });
    assert.deepStrictEqual(Profile.parseProbe("daemon tuned\n"), { daemon: "tuned", names: [] });
    assert.deepStrictEqual(Profile.parseProbe(""), { daemon: "", names: [] });
    assert.deepStrictEqual(Profile.choices("ppd", ["balanced", "power-saver"]), ["saver", "balanced"]);
    assert.deepStrictEqual(Profile.choices("ppd", ["performance", "balanced", "power-saver"]), ["saver", "balanced", "fast"]);
    assert.deepStrictEqual(Profile.choices("tuned", []), ["saver", "balanced", "fast"]);
    assert.deepStrictEqual(Profile.choices("", []), []);
});

test("the active profile is read from either daemon's output", () => {
    assert.strictEqual(Profile.parseActive("ppd", "balanced\n"), "balanced");
    assert.strictEqual(Profile.parseActive("ppd", "Error: no daemon\n"), "");
    assert.strictEqual(Profile.parseActive("tuned", "Current active profile: throughput-performance\n"), "throughput-performance");
    assert.strictEqual(Profile.parseActive("tuned", "No current active profile.\n"), "");
});

test("the charge probe tells whether the firmware has a limit, where it sits and whether the helper is in", () => {
    assert.deepStrictEqual(Charge.parseProbe("threshold 80\nhelper\n"), { supported: true, current: 80, helper: true });
    assert.deepStrictEqual(Charge.parseProbe("threshold 100\n"), { supported: true, current: 100, helper: false });
    assert.deepStrictEqual(Charge.parseProbe("threshold \n"), { supported: true, current: -1, helper: false });
    assert.deepStrictEqual(Charge.parseProbe("helper\n"), { supported: false, current: -1, helper: true });
});

test("holding off the charge writes 100, and the hold stays inside what the helper takes", () => {
    assert.strictEqual(Charge.wanted(true, 80), 80);
    assert.strictEqual(Charge.wanted(false, 80), 100);
    assert.strictEqual(Charge.wanted(true, 20), 50);
    assert.strictEqual(Charge.wanted(true, 120), 100);
});

const base = { probed: true, supported: true, helper: true, current: 100, wanted: 80, refused: null, writing: false };

test("the limit is written when it is possible and different, and not twice for a firmware that says no", () => {
    assert.strictEqual(Charge.shouldWrite(base), true);
    assert.strictEqual(Charge.shouldWrite(Object.assign({}, base, { current: 80 })), false);
    assert.strictEqual(Charge.shouldWrite(Object.assign({}, base, { helper: false })), false);
    assert.strictEqual(Charge.shouldWrite(Object.assign({}, base, { supported: false })), false);
    assert.strictEqual(Charge.shouldWrite(Object.assign({}, base, { writing: true })), false);
    assert.strictEqual(Charge.shouldWrite(Object.assign({}, base, { current: -1 })), false);
    const stuck = { wanted: 80, got: 100, failed: false };
    assert.strictEqual(Charge.shouldWrite(Object.assign({}, base, { refused: stuck })), false);
    assert.strictEqual(Charge.shouldWrite(Object.assign({}, base, { refused: stuck, current: 95 })), true);
    assert.strictEqual(Charge.shouldWrite(Object.assign({}, base, { refused: stuck, wanted: 70 })), true);
});

test("the row says why the limit is not holding and what to run", () => {
    const command = "bash install.sh --charge-limit";
    assert.strictEqual(Charge.trouble(Object.assign({}, base, { probed: false }), command), "");
    assert.match(Charge.trouble(Object.assign({}, base, { supported: false }), command), /no charge limit/);
    assert.strictEqual(Charge.trouble(Object.assign({}, base, { helper: false }), command), "needs the helper · run bash install.sh --charge-limit");
    assert.strictEqual(Charge.trouble(base, command), "");
    assert.match(Charge.trouble(Object.assign({}, base, { refused: { wanted: 80, got: 100, failed: false } }), command), /kept it at 100%/);
    assert.match(Charge.trouble(Object.assign({}, base, { refused: { wanted: 80, got: 100, failed: true } }), command), /refused/);
});

test("the charge helper takes one number from 50 to 100 and nothing else", () => {
    const { spawnSync } = require("node:child_process");
    const helper = path.join(ROOT, "scripts/charge-limit.sh");
    for (const bad of [undefined, "", "49", "101", "-5", "8o", "080", "1000", "80 90", "$(id)"]) {
        const run = spawnSync("sh", bad === undefined ? [helper] : [helper, bad]);
        assert.strictEqual(run.status, 2, `${bad}`);
    }
});
