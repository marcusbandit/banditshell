const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const load = (file, names) => new Function(fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "") + `\nreturn { ${names.join(", ")} };`)();
const Anomalies = load("modules/sidebar/anomalies.js", ["list", "merge", "without", "airplaneOn"]);
const Scrolling = load("modules/sidebar/scrolling.js", ["scrolled"]);

const calm = {
    micShown: true,
    micStreams: false,
    micMuted: false,
    recording: false,
    vpn: false,
    wifiAvailable: true,
    wifiOn: true,
    bluetoothAvailable: true,
    bluetoothOn: true,
    modeIcon: "",
    quiet: false,
    update: "idle",
    updateMode: "new",
    diverged: false
};

const keys = state => Anomalies.list(Object.assign({}, calm, state)).map(e => e.key);

test("a calm machine shows nothing", () => {
    assert.deepStrictEqual(keys({}), []);
    assert.deepStrictEqual(Anomalies.list(undefined), []);
    assert.deepStrictEqual(Anomalies.list({}), []);
});

test("the battery is never an anomaly, because the rail always shows it", () => {
    assert.deepStrictEqual(Anomalies.list({ battery: true, batteryPercent: 3 }), []);
});

test("the microphone shows only while something listens, live or muted", () => {
    assert.deepStrictEqual(keys({ micMuted: true }), []);
    assert.deepStrictEqual(keys({ micStreams: true }), ["mic"]);
    const live = Anomalies.list(Object.assign({}, calm, { micStreams: true }))[0];
    assert.deepStrictEqual([live.icon, live.tone], ["mic", "alarm"]);
    const muted = Anomalies.list(Object.assign({}, calm, { micStreams: true, micMuted: true }))[0];
    assert.deepStrictEqual([muted.icon, muted.tone], ["mic_off", "accent"]);
    assert.deepStrictEqual(keys({ micStreams: true, micShown: false }), []);
});

test("recording, vpn and quiet each show on their own", () => {
    assert.deepStrictEqual(keys({ recording: true }), ["recording"]);
    assert.deepStrictEqual(keys({ vpn: true }), ["vpn"]);
    assert.deepStrictEqual(keys({ quiet: true }), ["quiet"]);
});

test("a mode icon stands in for quiet instead of doubling it", () => {
    assert.deepStrictEqual(keys({ modeIcon: "target", quiet: true }), ["mode"]);
    assert.strictEqual(Anomalies.list(Object.assign({}, calm, { modeIcon: "target" }))[0].icon, "target");
});

test("airplane means every radio the machine has is off", () => {
    assert.ok(Anomalies.airplaneOn(Object.assign({}, calm, { wifiOn: false, bluetoothOn: false })));
    assert.ok(Anomalies.airplaneOn(Object.assign({}, calm, { wifiOn: false, bluetoothAvailable: false })));
    assert.ok(!Anomalies.airplaneOn(Object.assign({}, calm, { wifiOn: false })));
    assert.ok(!Anomalies.airplaneOn(Object.assign({}, calm, { wifiAvailable: false, wifiOn: false, bluetoothOn: false })));
    assert.deepStrictEqual(keys({ wifiOn: false, bluetoothOn: false }), ["airplane"]);
});

test("updates show by state, stuck ones as alarms, and never when the button is off", () => {
    assert.deepStrictEqual(keys({ update: "idle" }), []);
    assert.strictEqual(Anomalies.list(Object.assign({}, calm, { update: "downloaded" }))[0].icon, "download_done");
    assert.strictEqual(Anomalies.list(Object.assign({}, calm, { update: "downloading" }))[0].icon, "cloud_download");
    assert.strictEqual(Anomalies.list(Object.assign({}, calm, { update: "available" }))[0].icon, "system_update_alt");
    const stuck = Anomalies.list(Object.assign({}, calm, { update: "available", diverged: true }))[0];
    assert.deepStrictEqual([stuck.icon, stuck.tone], ["sync_problem", "alarm"]);
    assert.strictEqual(Anomalies.list(Object.assign({}, calm, { update: "failed" }))[0].tone, "alarm");
    assert.deepStrictEqual(keys({ update: "failed", updateMode: "never" }), []);
});

test("when too many things are unusual the alarms stay and the order holds", () => {
    const all = { micStreams: true, recording: true, vpn: true, wifiOn: false, bluetoothOn: false, quiet: true, update: "available" };
    const shown = keys(all);
    assert.strictEqual(shown.length, 4);
    assert.deepStrictEqual(shown, ["mic", "recording", "vpn", "airplane"]);
    const quietOnly = keys({ quiet: true, vpn: true, update: "failed", recording: true, micStreams: true });
    assert.ok(quietOnly.includes("update"));
    assert.ok(!quietOnly.includes("quiet"));
});

test("held marks fade out instead of vanishing, and come back in place", () => {
    const a = { key: "vpn", icon: "vpn_lock", tone: "accent" };
    const b = { key: "mic", icon: "mic", tone: "alarm" };
    let held = Anomalies.merge([], [a, b]);
    assert.deepStrictEqual(held.map(e => [e.key, e.present]), [["vpn", true], ["mic", true]]);
    held = Anomalies.merge(held, [b]);
    assert.deepStrictEqual(held.map(e => [e.key, e.present]), [["vpn", false], ["mic", true]]);
    held = Anomalies.merge(held, [a, b]);
    assert.deepStrictEqual(held.map(e => [e.key, e.present]), [["vpn", true], ["mic", true]]);
});

test("a settled ghost is dropped and a present mark never is", () => {
    const held = Anomalies.merge(Anomalies.merge([], [{ key: "vpn" }, { key: "mic" }]), [{ key: "mic" }]);
    assert.deepStrictEqual(Anomalies.without(held, "vpn").map(e => e.key), ["mic"]);
    assert.deepStrictEqual(Anomalies.without(held, "mic").map(e => e.key), ["vpn", "mic"]);
});

test("scrolling steps a level by notches, flips for natural scroll and stays in range", () => {
    assert.strictEqual(Scrolling.scrolled(0.5, 120, false, 0.05, 1), 0.55);
    assert.strictEqual(Scrolling.scrolled(0.5, -120, false, 0.05, 1), 0.45);
    assert.strictEqual(Scrolling.scrolled(0.5, 120, true, 0.05, 1), 0.45);
    assert.strictEqual(Scrolling.scrolled(0.98, 240, false, 0.05, 1), 1);
    assert.strictEqual(Scrolling.scrolled(0.02, -240, false, 0.05, 1), 0);
    assert.strictEqual(Scrolling.scrolled(1.4, 120, false, 0.05, 1.5), 1.45);
    assert.strictEqual(Scrolling.scrolled(0.5, 30, false, 0.04, 1), 0.51);
});
