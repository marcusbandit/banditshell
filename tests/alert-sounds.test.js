const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const SOUNDS = path.join(ROOT, "assets/sounds");
const SETS = ["soft", "clear", "wood"];
const KINDS = ["notification", "battery", "error"];

function read(set, kind) {
    const bytes = fs.readFileSync(path.join(SOUNDS, set, `${kind}.wav`));
    assert.strictEqual(bytes.toString("ascii", 0, 4), "RIFF");
    assert.strictEqual(bytes.toString("ascii", 8, 12), "WAVE");
    assert.strictEqual(bytes.toString("ascii", 12, 16), "fmt ");
    const format = { tag: bytes.readUInt16LE(20), channels: bytes.readUInt16LE(22), rate: bytes.readUInt32LE(24), bits: bytes.readUInt16LE(34) };
    assert.strictEqual(bytes.toString("ascii", 36, 40), "data");
    const length = bytes.readUInt32LE(40);
    const samples = [];
    for (let i = 0; i < length / 2; i++)
        samples.push(bytes.readInt16LE(44 + i * 2) / 32768);
    return { format, samples };
}

test("every set has a sound for every kind of alert", () => {
    for (const set of SETS)
        for (const kind of KINDS)
            assert.ok(fs.existsSync(path.join(SOUNDS, set, `${kind}.wav`)), `${set}/${kind}`);
});

test("the sounds are plain mono 16-bit PCM", () => {
    for (const set of SETS)
        for (const kind of KINDS) {
            const { format } = read(set, kind);
            assert.deepStrictEqual([format.tag, format.channels, format.bits], [1, 1, 16], `${set}/${kind}`);
            assert.ok(format.rate >= 22050 && format.rate <= 48000, `${set}/${kind} rate ${format.rate}`);
        }
});

test("the sounds are short, even in loudness, and start and end on silence", () => {
    for (const set of SETS)
        for (const kind of KINDS) {
            const { format, samples } = read(set, kind);
            const seconds = samples.length / format.rate;
            const peak = Math.max(...samples.map(Math.abs));
            const rms = Math.sqrt(samples.reduce((sum, x) => sum + x * x, 0) / samples.length);
            const label = `${set}/${kind}`;
            assert.ok(seconds >= 0.2 && seconds < 0.6, `${label} runs ${seconds.toFixed(2)} s`);
            assert.ok(peak > 0.3 && peak <= 0.9, `${label} peaks at ${peak.toFixed(2)}`);
            assert.ok(rms > 0.08 && rms < 0.14, `${label} sits at rms ${rms.toFixed(3)}`);
            assert.ok(Math.abs(samples[0]) < 0.01, `${label} starts with a click`);
            assert.ok(Math.abs(samples[samples.length - 1]) < 0.01, `${label} ends with a click`);
        }
});
