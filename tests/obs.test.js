const test = require("node:test");
const assert = require("node:assert");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const base64Src = fs.readFileSync(path.join(ROOT, "components/base64.js"), "utf8");
const Base64 = new Function(base64Src + "\nreturn { encode, decode, utf8 };")();
const src = fs.readFileSync(path.join(ROOT, "services/obs.js"), "utf8");
const Obs = new Function(src + "\nreturn { sha256, authentication, identify, request, role, sceneNames, health, duration, rate };")();

function nodeSha256(bytes) {
    return crypto.createHash("sha256").update(Buffer.from(bytes, "latin1")).digest("latin1");
}

function nodeAuthentication(password, salt, challenge) {
    const secret = crypto.createHash("sha256").update(password + salt, "utf8").digest("base64");
    return crypto.createHash("sha256").update(secret + challenge, "utf8").digest("base64");
}

test.describe("obs sha256", () => {
    test.it("hashes what node hashes across the padding boundaries", () => {
        for (const length of [0, 1, 3, 55, 56, 57, 63, 64, 65, 119, 120, 128, 300]) {
            const bytes = Buffer.from(Array.from({length}, (_, i) => (i * 37 + 11) & 255)).toString("latin1");
            assert.strictEqual(Obs.sha256(bytes), nodeSha256(bytes), `length ${length}`);
        }
    });

    test.it("hashes the classic vector", () => {
        assert.strictEqual(Buffer.from(Obs.sha256("abc"), "latin1").toString("hex"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    });
});

test.describe("obs authentication", () => {
    test.it("answers the challenge the way obs-websocket checks it", () => {
        const salt = "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI=";
        const challenge = "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=";
        for (const password of ["supersecretpassword", "", "pässwörd ✓"])
            assert.strictEqual(Obs.authentication(password, salt, challenge, Base64), nodeAuthentication(password, salt, challenge), password);
    });

    test.it("identifies without a password when the server asks for none", () => {
        const message = Obs.identify({rpcVersion: 1}, "ignored", Base64);
        assert.strictEqual(message.op, 1);
        assert.strictEqual(message.d.authentication, undefined);
    });

    test.it("identifies with the answer and the events the deck needs", () => {
        const message = Obs.identify({authentication: {salt: "s", challenge: "c"}}, "pw", Base64);
        assert.strictEqual(message.d.authentication, nodeAuthentication("pw", "s", "c"));
        for (const bit of [4, 8, 64, 128])
            assert.ok(message.d.eventSubscriptions & bit, `subscription ${bit}`);
    });

    test.it("wraps a request with its id", () => {
        assert.deepStrictEqual(Obs.request("GetSceneList", "7"), {op: 6, d: {requestType: "GetSceneList", requestId: "7", requestData: {}}});
    });
});

test.describe("obs roles", () => {
    test.it("sorts the sources a stream deck acts on", () => {
        assert.strictEqual(Obs.role("v4l2_input"), "camera");
        assert.strictEqual(Obs.role("av_capture_input_v2"), "camera");
        assert.strictEqual(Obs.role("pipewire-screen-capture-source"), "screen");
        assert.strictEqual(Obs.role("pulse_output_capture"), "desktop");
        assert.strictEqual(Obs.role("jack_output_capture"), "desktop");
        assert.strictEqual(Obs.role("pulse_input_capture"), "mic");
        assert.strictEqual(Obs.role("image_source"), "");
        assert.strictEqual(Obs.role(undefined), "");
    });

    test.it("lists scenes top first, the way OBS shows them", () => {
        assert.deepStrictEqual(Obs.sceneNames([{sceneName: "Digital camera", sceneIndex: 0}, {sceneName: "Scene", sceneIndex: 1}]), ["Scene", "Digital camera"]);
    });
});

test.describe("obs health", () => {
    test.it("has no rate until a second sample", () => {
        const first = Obs.health(null, {outputBytes: 1000, outputTotalFrames: 0, outputSkippedFrames: 0}, 1000);
        assert.strictEqual(first.kbps, 0);
        assert.strictEqual(first.dropped, 0);
    });

    test.it("measures the rate between samples and the share of dropped frames", () => {
        const first = Obs.health(null, {outputBytes: 0}, 0);
        const second = Obs.health(first, {outputBytes: 750000, outputTotalFrames: 1000, outputSkippedFrames: 5, outputCongestion: 0.2}, 1000);
        assert.strictEqual(second.kbps, 6000);
        assert.strictEqual(second.dropped, 0.005);
        assert.strictEqual(second.congestion, 0.2);
    });

    test.it("keeps the last rate when the byte count restarts", () => {
        const first = Obs.health({at: 0, bytes: 900, kbps: 42}, {outputBytes: 10}, 1000);
        assert.strictEqual(first.kbps, 42);
    });

    test.it("formats durations and rates", () => {
        assert.strictEqual(Obs.duration(0), "0:00");
        assert.strictEqual(Obs.duration(65000), "1:05");
        assert.strictEqual(Obs.duration(3723000), "1:02:03");
        assert.strictEqual(Obs.rate(6000), "6.0 Mb/s");
        assert.strictEqual(Obs.rate(850.4), "850 kb/s");
    });
});
