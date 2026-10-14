const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const SCRIPT = path.join(ROOT, "scripts/pointing-devices.py");

function machine(devices) {
    const base = fs.mkdtempSync(path.join(os.tmpdir(), "pointing-devices-"));
    const sys = path.join(base, "sys");
    const udev = path.join(base, "udev");
    fs.mkdirSync(udev, { recursive: true });
    devices.forEach((d, n) => {
        const node = path.join(sys, `event${n}`);
        fs.mkdirSync(path.join(node, "device"), { recursive: true });
        fs.writeFileSync(path.join(node, "device", "name"), `${d.name}\n`);
        fs.writeFileSync(path.join(node, "dev"), `13:${64 + n}\n`);
        fs.writeFileSync(path.join(udev, `c13:${64 + n}`), d.properties.map(p => `E:${p}`).join("\n") + "\n");
    });
    return { sys, udev, base };
}

function listed(devices) {
    const m = machine(devices);
    try {
        const run = spawnSync("python3", ["-I", SCRIPT, "--sys-input", m.sys, "--udev-data", m.udev], { encoding: "utf8" });
        assert.strictEqual(run.status, 0, run.stderr);
        return JSON.parse(run.stdout);
    } finally {
        fs.rmSync(m.base, { recursive: true, force: true });
    }
}

test("touchpads come with the size udev reads off them, mice without one", () => {
    const found = listed([
        { name: "Synaptics Touchpad", properties: ["ID_INPUT=1", "ID_INPUT_TOUCHPAD=1", "ID_INPUT_WIDTH_MM=100", "ID_INPUT_HEIGHT_MM=60"] },
        { name: "Logitech G Pro", properties: ["ID_INPUT=1", "ID_INPUT_MOUSE=1"] }
    ]);
    assert.deepStrictEqual(found, [
        { name: "Synaptics Touchpad", kind: "touchpad", widthMm: 100, heightMm: 60 },
        { name: "Logitech G Pro", kind: "mouse", widthMm: null, heightMm: null }
    ]);
});

test("keyboards, unknown nodes and nonsense sizes are left out or null", () => {
    const found = listed([
        { name: "Keyboard", properties: ["ID_INPUT=1", "ID_INPUT_KEYBOARD=1"] },
        { name: "Pad", properties: ["ID_INPUT_TOUCHPAD=1", "ID_INPUT_WIDTH_MM=abc", "ID_INPUT_HEIGHT_MM=0"] },
        { name: "Stick", properties: ["ID_INPUT_POINTINGSTICK=1"] }
    ]);
    assert.deepStrictEqual(found.map(d => [d.name, d.kind, d.widthMm, d.heightMm]), [["Pad", "touchpad", null, null], ["Stick", "pointingstick", null, null]]);
});

test("a machine with no input nodes lists nothing", () => {
    assert.deepStrictEqual(listed([]), []);
});
