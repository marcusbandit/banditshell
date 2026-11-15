const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/mixer.js"), "utf8");
const M = new Function(src + "\nreturn { isPlumbing, identity, title, group, byName, state, label, headline, summary, meter, routeCommand, volumeOf, mutedAll };")();
const audio = fs.readFileSync(path.join(ROOT, "services/audio.js"), "utf8");
const { isMeter } = new Function(audio + "\nreturn { isMeter };")();

function stream(id, props, extra) {
    return Object.assign({ id: id, props: props, volume: 1, muted: false }, extra || {});
}

test("two browser tabs are one app, keyed by the binary", () => {
    const apps = M.group([
        stream(1, { "application.name": "Zen", "application.process.binary": "zen-bin", "media.name": "A video" }),
        stream(2, { "application.name": "Zen", "application.process.binary": "zen-bin", "media.name": "Another tab" }),
        stream(3, { "application.name": "Spotify", "media.name": "Spotify" })
    ]);
    assert.deepStrictEqual(apps.map(a => [a.key, a.ids]), [["zen-bin", [1, 2]], ["spotify", [3]]]);
    assert.strictEqual(apps[0].name, "Zen");
    assert.strictEqual(apps[0].named, true);
});

test("an ALSA client is named after the program inside the brackets", () => {
    const who = M.identity({ "application.name": "PipeWire ALSA [python3.12]" });
    assert.deepStrictEqual(who, { key: "python3.12", binary: "python3.12", name: "python3.12", named: false });
});

test("an app whose name is its binary asks the desktop entry for a name", () => {
    assert.strictEqual(M.identity({ "application.name": "vesktop", "application.process.binary": "vesktop" }).named, false);
});

test("tab titles show, stock stream names do not", () => {
    assert.strictEqual(M.title({ "media.name": "Some video - YouTube" }, "Zen"), "Some video - YouTube");
    for (const plain of ["Playback", "ALSA Capture", "-", "Spotify", "audio stream", "Simple DSP"])
        assert.strictEqual(M.title({ "media.name": plain, "application.name": "Spotify" }, "Spotify"), "", plain);
});

test("the shell's own peak meters never show as apps", () => {
    assert.ok(isMeter({ "application.name": "Quickshell Peak Detect", "media.name": "Peak detect", "stream.monitor": "true" }));
    assert.ok(isMeter({ "stream.monitor": "true", "application.name": "pavucontrol" }));
    assert.ok(!isMeter({ "application.name": "parec" }));
    assert.ok(!isMeter(undefined));
});

test("loopback splits are plumbing, real recorders are not", () => {
    assert.ok(M.isPlumbing({ "media.class": "Stream/Input/Audio/Internal" }));
    assert.ok(M.isPlumbing({ "node.virtual": "true", "node.passive": "true" }));
    assert.ok(!M.isPlumbing({ "media.class": "Stream/Input/Audio", "application.name": "pw-record" }));
});

test("an app is making sound only while it is heard and audible", () => {
    const s = [stream(7, {})];
    assert.strictEqual(M.state(s, { 7: true }, true), "sound");
    assert.strictEqual(M.state(s, {}, true), "silent");
    assert.strictEqual(M.state([stream(7, {}, { muted: true })], { 7: true }, true), "muted");
    assert.strictEqual(M.state([stream(7, {}, { volume: 0 })], {}, true), "muted");
    assert.strictEqual(M.state([stream(7, { "pulse.corked": "true" })], {}, true), "paused");
});

test("one loud tab makes the whole app count as making sound", () => {
    const s = [stream(1, { "pulse.corked": "true" }), stream(2, {})];
    assert.strictEqual(M.state(s, { 2: true }, true), "sound");
});

test("a muted tab does not count, even if its meter moved", () => {
    const s = [stream(1, {}, { muted: true }), stream(2, { "pulse.corked": "true" })];
    assert.strictEqual(M.state(s, { 1: true }, true), "paused");
});

test("without meters running nothing claims to be silent", () => {
    assert.strictEqual(M.state([stream(1, {})], {}, false), "open");
    assert.strictEqual(M.state([stream(1, {})], { 1: true }, false), "open");
});

test("state labels read differently for listeners", () => {
    assert.strictEqual(M.label("sound", false), "Making sound");
    assert.strictEqual(M.label("silent", true), "Listening");
});

test("the headline names who is making sound", () => {
    assert.strictEqual(M.headline([], 0), "No app has sound open");
    assert.strictEqual(M.headline([], 3), "Nothing is making sound");
    assert.strictEqual(M.headline(["Spotify"], 3), "Spotify is making sound");
    assert.strictEqual(M.headline(["Spotify", "Zen"], 3), "Spotify and Zen are making sound");
    assert.strictEqual(M.headline(["A", "B", "C", "D"], 4), "A, B and 2 more are making sound");
});

test("the summary counts states", () => {
    assert.strictEqual(M.summary(["sound", "muted", "silent"]), "3 apps · 1 making sound · 1 muted");
    assert.strictEqual(M.summary(["paused"]), "1 app · 1 paused");
});

test("the meter reads on a 60 dB scale", () => {
    assert.strictEqual(M.meter(0), 0);
    assert.strictEqual(M.meter(0.0005), 0);
    assert.strictEqual(M.meter(1), 1);
    assert.ok(Math.abs(M.meter(0.1) - 2 / 3) < 1e-9);
    assert.strictEqual(M.meter(2), 1);
});

test("volume is the loudest stream; muted only when every stream is", () => {
    const s = [stream(1, {}, { volume: 0.4 }), stream(2, {}, { volume: 0.9, muted: true })];
    assert.strictEqual(M.volumeOf(s), 0.9);
    assert.strictEqual(M.mutedAll(s), false);
    assert.strictEqual(M.mutedAll([]), false);
});

test("routing sets or clears the stream's target in the default metadata", () => {
    assert.deepStrictEqual(M.routeCommand(42, "alsa_output.usb"), ["pw-metadata", "-n", "default", "42", "target.object", "alsa_output.usb"]);
    assert.deepStrictEqual(M.routeCommand(42, ""), ["pw-metadata", "-n", "default", "-d", "42", "target.object"]);
});

test("apps sort by their shown name", () => {
    const apps = [{ key: "b", display: "zen" }, { key: "a", display: "Discord" }];
    assert.deepStrictEqual(M.byName(apps, a => a.display).map(a => a.key), ["a", "b"]);
});
