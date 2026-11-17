const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.join(path.resolve(__dirname, ".."), "services/audio.js"), "utf8");
const { uniqueLabels } = new Function(src + "\nreturn { uniqueLabels };")();

test("two outputs with the same profile name get their card name added", () => {
    const labels = uniqueLabels([
        { key: "a", label: "Analog Stereo", card: "Built-in Audio" },
        { key: "b", label: "Analog Stereo", card: "USB Audio Device" },
        { key: "c", label: "HDMI", card: "GPU" }
    ]);
    assert.deepStrictEqual(labels, { a: "Analog Stereo · Built-in Audio", b: "Analog Stereo · USB Audio Device", c: "HDMI" });
});

test("two identical headsets are numbered so no two rows read alike", () => {
    const labels = uniqueLabels([
        { key: "a", label: "Analog Stereo", card: "USB Headset" },
        { key: "b", label: "Analog Stereo", card: "USB Headset" },
        { key: "c", label: "Analog Stereo", card: "Built-in Audio" }
    ]);
    assert.deepStrictEqual(labels, { a: "Analog Stereo · USB Headset 1", b: "Analog Stereo · USB Headset 2", c: "Analog Stereo · Built-in Audio" });
    assert.strictEqual(new Set(Object.values(labels)).size, 3);
});

test("a device with no card name falls back to a number, and a unique label stays plain", () => {
    const labels = uniqueLabels([
        { key: "a", label: "Speakers", card: "" },
        { key: "b", label: "Speakers", card: "" },
        { key: "c", label: "Headphones", card: "Built-in Audio" }
    ]);
    assert.deepStrictEqual(labels, { a: "Speakers 1", b: "Speakers 2", c: "Headphones" });
});

test("twins are numbered by name, so the order devices appear in does not swap them", () => {
    const a = { key: "alsa_output.usb-1", label: "Analog Stereo", card: "USB Headset" };
    const b = { key: "alsa_output.usb-2", label: "Analog Stereo", card: "USB Headset" };
    assert.deepStrictEqual(uniqueLabels([a, b]), uniqueLabels([b, a]));
    assert.strictEqual(uniqueLabels([b, a])["alsa_output.usb-1"], "Analog Stereo · USB Headset 1");
});
