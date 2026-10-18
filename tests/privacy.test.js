const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/privacy.js"), "utf8");
const P = new Function(src + "\nreturn { usages, usageSpec, changes, micNews, micStep, listeners, unitOf, shortCommand, named };")();
const act = fs.readFileSync(path.join(ROOT, "services/activities.js"), "utf8");
const A = new Function(act + "\nreturn { push, itemOf };")();

function node(id, props) {
    return { id: id, props: props };
}

function link(source, target, active) {
    return { source: source, target: target, active: active !== false };
}

const microphone = node(1, { "media.class": "Audio/Source", "node.name": "alsa_input.usb-mic" });
const speakers = node(2, { "media.class": "Audio/Sink", "node.name": "alsa_output.speakers" });
const webcam = node(3, { "media.class": "Video/Source", "device.api": "v4l2" });
const cast = node(4, { "media.class": "Stream/Output/Video", "node.name": "xdph-streaming" });

function recorder(id, name, extra) {
    return node(id, Object.assign({ "media.class": "Stream/Input/Audio", "application.name": name }, extra || {}));
}

function watcher(id, name, extra) {
    return node(id, Object.assign({ "media.class": "Stream/Input/Video", "application.name": name }, extra || {}));
}

test.describe("microphone", () => {
    test.it("is in use when a capture stream is linked to a microphone", () => {
        const snap = { nodes: [microphone, recorder(10, "Firefox")], links: [link(1, 10)] };
        assert.deepStrictEqual(P.usages(snap), [{ kind: "mic", apps: ["Firefox"] }]);
    });

    test.it("is not in use when the link is not active", () => {
        const snap = { nodes: [microphone, recorder(10, "Firefox")], links: [link(1, 10, false)] };
        assert.deepStrictEqual(P.usages(snap), []);
    });

    test.it("is not in use when the stream records a speaker's monitor", () => {
        const snap = { nodes: [speakers, recorder(10, "OBS")], links: [link(2, 10)] };
        assert.deepStrictEqual(P.usages(snap), []);
        const flagged = { nodes: [microphone, recorder(10, "OBS", { "stream.capture.sink": "true" })], links: [link(1, 10)] };
        assert.deepStrictEqual(P.usages(flagged), []);
    });

    test.it("ignores the shell's own level meters and volume meters", () => {
        const snap = {
            nodes: [microphone, recorder(10, "quickshell", { "application.process.binary": "quickshell" }), recorder(11, "PulseAudio Volume Control", { "media.name": "Peak detect" })],
            links: [link(1, 10), link(1, 11)]
        };
        assert.deepStrictEqual(P.usages(snap), []);
    });

    test.it("lists each app once, sorted", () => {
        const snap = { nodes: [microphone, recorder(10, "Zoom"), recorder(11, "Discord"), recorder(12, "Zoom")], links: [link(1, 10), link(1, 11), link(1, 12)] };
        assert.deepStrictEqual(P.usages(snap)[0].apps, ["Discord", "Zoom"]);
    });

    test.it("stays quiet about what the shell already shows", () => {
        const snap = { nodes: [microphone, recorder(10, "gvoice")], links: [link(1, 10)] };
        assert.deepStrictEqual(P.usages(snap, { mic: true }), []);
        assert.strictEqual(P.usages(snap, { screen: true }).length, 1);
    });
});

test.describe("camera and screen", () => {
    test.it("calls a video stream fed by a webcam a camera", () => {
        const snap = { nodes: [webcam, watcher(20, "Chromium")], links: [link(3, 20)] };
        assert.deepStrictEqual(P.usages(snap), [{ kind: "camera", apps: ["Chromium"] }]);
    });

    test.it("calls a video stream fed by a screen cast a screen share", () => {
        const snap = { nodes: [cast, watcher(20, "OBS Studio")], links: [link(4, 20)] };
        assert.deepStrictEqual(P.usages(snap), [{ kind: "screen", apps: ["OBS Studio"] }]);
    });

    test.it("reads a camera role as a camera when the device api is unknown", () => {
        const odd = node(5, { "media.class": "Video/Source", "media.role": "Camera" });
        const snap = { nodes: [odd, watcher(20, "Meet")], links: [link(5, 20)] };
        assert.strictEqual(P.usages(snap)[0].kind, "camera");
    });

    test.it("a cast nobody watches is not shared", () => {
        assert.deepStrictEqual(P.usages({ nodes: [cast], links: [] }), []);
    });

    test.it("stays quiet about the shell's own screen recorder", () => {
        const snap = { nodes: [cast, watcher(20, "wf-recorder")], links: [link(4, 20)] };
        assert.deepStrictEqual(P.usages(snap, { screen: true }), []);
    });

    test.it("orders camera, screen, then microphone", () => {
        const snap = {
            nodes: [microphone, recorder(10, "Zoom"), webcam, watcher(20, "Zoom"), cast, watcher(21, "Zoom")],
            links: [link(1, 10), link(3, 20), link(4, 21)]
        };
        assert.deepStrictEqual(P.usages(snap).map(u => u.kind), ["camera", "screen", "mic"]);
    });

    test.it("has no usage on an empty graph", () => {
        assert.deepStrictEqual(P.usages({ nodes: [], links: [] }), []);
        assert.deepStrictEqual(P.usages(undefined), []);
    });
});

test.describe("posting", () => {
    test.it("makes a short registry entry; the camera and the screen keep their apps for hover", () => {
        const spec = P.usageSpec({ kind: "mic", apps: ["Firefox", "Zoom"] });
        assert.strictEqual(spec.id, "privacy:mic");
        assert.strictEqual(spec.text, "Microphone on");
        assert.strictEqual(spec.detail, "");
        assert.strictEqual(P.usageSpec({ kind: "camera", apps: ["Zoom", "OBS"] }).text, "Camera on");
        assert.strictEqual(P.usageSpec({ kind: "camera", apps: ["Zoom", "OBS"] }).detail, "Zoom, OBS");
        assert.strictEqual(P.usageSpec({ kind: "screen", apps: ["a"] }).text, "Screen shared");
        const out = A.push([], spec, 0);
        assert.ok(!out.error, out.error);
        const item = A.itemOf(out.entry);
        assert.strictEqual(item.key, "privacy:privacy:mic");
        assert.strictEqual(item.kind, "privacy");
        assert.strictEqual(item.pressable, true);
    });

    test.it("only the microphone opens a menu", () => {
        assert.strictEqual(P.usageSpec({ kind: "camera", apps: ["a"] }).pressable, false);
        assert.strictEqual(P.usageSpec({ kind: "screen", apps: ["a"] }).pressable, false);
    });

    test.it("a listener is news once; one that keeps listening is not", () => {
        assert.strictEqual(P.micNews([], ["voice"]), true);
        assert.strictEqual(P.micNews(["voice"], ["voice"]), false);
        assert.strictEqual(P.micNews(["voice", "Discord"], ["voice"]), false);
        assert.strictEqual(P.micNews(["voice"], ["Discord", "voice"]), true);
        assert.strictEqual(P.micNews(null, []), false);
    });

    test.it("an always-on listener is announced once, then stays quiet until someone new listens", () => {
        const voice = { kind: "mic", apps: ["voice"] };
        const call = { kind: "mic", apps: ["Discord", "voice"] };
        let s = P.micStep([], voice, false);
        assert.deepStrictEqual(s, { post: true, announce: true, heard: ["voice"] });
        s = P.micStep(s.heard, voice, false);
        assert.strictEqual(s.post, false);
        s = P.micStep(s.heard, call, false);
        assert.deepStrictEqual(s, { post: true, announce: true, heard: ["Discord", "voice"] });
        s = P.micStep(s.heard, voice, false);
        assert.deepStrictEqual(s, { post: false, announce: false, heard: ["voice"] });
        s = P.micStep(s.heard, null, false);
        assert.deepStrictEqual(s, { post: false, announce: false, heard: [] });
        assert.strictEqual(P.micStep(s.heard, voice, false).announce, true);
    });

    test.it("while the announcement shows, a listener leaving updates it without starting it again", () => {
        const s = P.micStep(["Discord", "voice"], { kind: "mic", apps: ["voice"] }, true);
        assert.deepStrictEqual(s, { post: true, announce: false, heard: ["voice"] });
    });

    test.it("posts what changed and ends what stopped", () => {
        const mic = { kind: "mic", apps: ["Zoom"] };
        const camera = { kind: "camera", apps: ["Zoom"] };
        assert.deepStrictEqual(P.changes([], [mic]), { push: [mic], end: [] });
        assert.deepStrictEqual(P.changes([mic], [mic]), { push: [], end: [] });
        assert.deepStrictEqual(P.changes([mic], [camera]), { push: [camera], end: ["privacy:mic"] });
        const other = { kind: "mic", apps: ["Discord", "Zoom"] };
        assert.deepStrictEqual(P.changes([mic], [other]), { push: [other], end: [] });
    });
});

test.describe("what is listening", () => {
    const dump = JSON.stringify([
        { id: 81, type: "PipeWire:Interface:Node", info: { props: { "media.class": "Audio/Source", "node.description": "Scarlett 2i2 USB Mic1" } } },
        { id: 50, type: "PipeWire:Interface:Node", info: { props: { "media.class": "Audio/Sink", "node.description": "Speakers" } } },
        { id: 97, type: "PipeWire:Interface:Client", info: { props: { "application.process.id": 1042, "application.process.binary": "python3.12" } } },
        { id: 98, type: "PipeWire:Interface:Node", info: { props: { "media.class": "Stream/Input/Audio", "application.name": "PipeWire ALSA [python3.12]", "client.id": 97 } } },
        { id: 99, type: "PipeWire:Interface:Node", info: { props: { "media.class": "Stream/Input/Audio", "application.name": "PipeWire ALSA [python3.12]", "client.id": 97 } } },
        { id: 103, type: "PipeWire:Interface:Node", info: { props: { "media.class": "Stream/Input/Audio", "application.name": "pw-record" } } },
        { id: 104, type: "PipeWire:Interface:Node", info: { props: { "media.class": "Stream/Input/Audio", "application.name": "quickshell", "application.process.binary": "quickshell" } } },
        { id: 105, type: "PipeWire:Interface:Node", info: { props: { "media.class": "Stream/Input/Audio", "application.name": "Discord" } } },
        { id: 1, type: "PipeWire:Interface:Link", info: { "output-node-id": 81, "input-node-id": 98, state: "active" } },
        { id: 2, type: "PipeWire:Interface:Link", info: { "output-node-id": 81, "input-node-id": 99, state: "active" } },
        { id: 3, type: "PipeWire:Interface:Link", info: { "output-node-id": 50, "input-node-id": 103, state: "active" } },
        { id: 4, type: "PipeWire:Interface:Link", info: { "output-node-id": 81, "input-node-id": 104, state: "active" } },
        { id: 5, type: "PipeWire:Interface:Link", info: { "output-node-id": 81, "input-node-id": 105, state: "paused" } }
    ]);

    test.it("finds the programs an active link feeds from a microphone, with their process", () => {
        const found = P.listeners(dump);
        assert.strictEqual(found.length, 2);
        assert.deepStrictEqual(found[0], { app: "PipeWire ALSA [python3.12]", binary: "python3.12", pid: 1042, device: "Scarlett 2i2 USB Mic1" });
    });

    test.it("leaves out a sink's monitor, the shell itself, a paused link and garbage", () => {
        const apps = P.listeners(dump).map(l => l.app);
        assert.ok(!apps.includes("pw-record") && !apps.includes("quickshell") && !apps.includes("Discord"));
        assert.deepStrictEqual(P.listeners("not json"), []);
        assert.deepStrictEqual(P.listeners("{}"), []);
    });

    test.it("names a program by the unit it runs in", () => {
        const base = "0::/user.slice/user-1000.slice/user@1000.service/app.slice/";
        assert.strictEqual(P.unitOf(base + "diablo-voice.service"), "diablo-voice");
        assert.strictEqual(P.unitOf(base + "app-Hyprland-discord-12345.scope"), "discord");
        assert.strictEqual(P.unitOf(base + "app-firefox-1234.scope"), "firefox");
        assert.strictEqual(P.unitOf(base + "app-Hyprland-kitty@a1b2.service"), "kitty");
        assert.strictEqual(P.unitOf("0::/user.slice/user-1000.slice/user@1000.service"), "");
        assert.strictEqual(P.unitOf("0::/user.slice/user-1000.slice/session-2.scope"), "");
        assert.strictEqual(P.unitOf(""), "");
    });

    test.it("shortens a command to its program and arguments", () => {
        assert.strictEqual(P.shortCommand("/home/x/.venv/bin/python -m voice "), "python -m voice");
        assert.strictEqual(P.shortCommand(""), "");
    });

    test.it("one row per program, named by its unit, then its binary, then what PipeWire calls it", () => {
        const found = P.listeners(dump);
        const table = "1042\t/home/x/.venv/bin/python -m voice\t0::/user.slice/user@1000.service/app.slice/diablo-voice.service\n";
        assert.deepStrictEqual(P.named(found, table), [{ name: "diablo-voice", command: "python -m voice", device: "Scarlett 2i2 USB Mic1", pid: 1042, processes: 1 }]);
        const helper = found.concat([{ app: "pw-record", binary: "pw-cat", pid: 2187, device: "Scarlett 2i2 USB Mic1" }]);
        const both = table + "2187\tpw-record --raw -\t0::/user.slice/user@1000.service/app.slice/diablo-voice.service\n";
        const rows = P.named(helper, both);
        assert.strictEqual(rows.length, 1);
        assert.strictEqual(rows[0].processes, 2);
        assert.strictEqual(P.named(found, "")[0].name, "python3.12");
        assert.strictEqual(P.named([{ app: "Zoom", binary: "", pid: 0, device: "" }], "")[0].name, "Zoom");
    });
});

