const test = require("node:test");
const assert = require("node:assert");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const SCRIPT = path.resolve(__dirname, "../scripts/pen-buttons.py");

const KEY = 1;
const PEN = 0x140;
const RUBBER = 0x141;
const LOWER = 0x14b;
const UPPER = 0x14c;

function remap(lower, upper, events) {
    const code = [
        "import importlib.util, json, sys",
        "spec = importlib.util.spec_from_file_location('pen_buttons', sys.argv[1])",
        "module = importlib.util.module_from_spec(spec)",
        "spec.loader.exec_module(module)",
        "remapper = module.Remapper(sys.argv[2], sys.argv[3])",
        "out = []",
        "for etype, code, value in json.loads(sys.argv[4]):",
        "    out.append(remapper.feed(etype, code, value))",
        "print(json.dumps({'identity': remapper.identity, 'out': out, 'release': remapper.release()}))"
    ].join("\n");
    const run = spawnSync("python3", ["-I", "-c", code, SCRIPT, lower, upper, JSON.stringify(events)], { encoding: "utf8" });
    assert.strictEqual(run.status, 0, run.stderr);
    return JSON.parse(run.stdout);
}

const press = code => [KEY, code, 1];
const lift = code => [KEY, code, 0];

test("the pen as it ships is left alone", () => {
    const r = remap("right click", "middle click", [press(LOWER), lift(LOWER), press(UPPER), lift(UPPER), [3, 0, 100], [0, 0, 0]]);
    assert.strictEqual(r.identity, true);
    assert.deepStrictEqual(r.out, [[[KEY, LOWER, 1]], [[KEY, LOWER, 0]], [[KEY, UPPER, 1]], [[KEY, UPPER, 0]], [[3, 0, 100]], [[0, 0, 0]]]);
});

test("swapping the buttons sends each one as the other", () => {
    const r = remap("middle click", "right click", [press(LOWER), lift(LOWER), press(UPPER), lift(UPPER)]);
    assert.strictEqual(r.identity, false);
    assert.deepStrictEqual(r.out, [[[KEY, UPPER, 1]], [[KEY, UPPER, 0]], [[KEY, LOWER, 1]], [[KEY, LOWER, 0]]]);
});

test("two buttons that both mean the same click hold it until both are up", () => {
    const r = remap("right click", "right click", [press(LOWER), press(UPPER), lift(LOWER), lift(UPPER)]);
    assert.deepStrictEqual(r.out, [[[KEY, LOWER, 1]], [], [], [[KEY, LOWER, 0]]]);
});

test("a button set to nothing sends nothing, and keeps repeats quiet", () => {
    const r = remap("nothing", "middle click", [press(LOWER), [KEY, LOWER, 2], lift(LOWER), press(UPPER)]);
    assert.deepStrictEqual(r.out, [[], [], [], [[KEY, UPPER, 1]]]);
});

test("erase turns the pen into its eraser while the button is held", () => {
    const r = remap("right click", "erase", [press(PEN), press(UPPER), lift(UPPER), [KEY, PEN, 0]]);
    assert.deepStrictEqual(r.out, [
        [[KEY, PEN, 1]],
        [[KEY, PEN, 0], [KEY, RUBBER, 1]],
        [[KEY, RUBBER, 0], [KEY, PEN, 1]],
        [[KEY, PEN, 0]]
    ]);
});

test("erase waits for the pen to arrive, and leaves with it", () => {
    const r = remap("right click", "erase", [press(UPPER), press(PEN), [KEY, PEN, 0], press(PEN), lift(UPPER)]);
    assert.deepStrictEqual(r.out, [
        [],
        [[KEY, RUBBER, 1]],
        [[KEY, RUBBER, 0]],
        [[KEY, RUBBER, 1]],
        [[KEY, RUBBER, 0], [KEY, PEN, 1]]
    ]);
});

test("the pen's own eraser end is never touched", () => {
    const r = remap("right click", "erase", [press(RUBBER), press(UPPER), lift(UPPER), [KEY, RUBBER, 0]]);
    assert.deepStrictEqual(r.out, [[[KEY, RUBBER, 1]], [], [], [[KEY, RUBBER, 0]]]);
});

test("a button set to erase sends no button of its own", () => {
    const r = remap("erase", "erase", [press(PEN), press(LOWER), press(UPPER), lift(LOWER), lift(UPPER)]);
    const sent = r.out.flat().filter(e => e[1] === LOWER || e[1] === UPPER);
    assert.deepStrictEqual(sent, []);
    assert.deepStrictEqual(r.out[3], []);
    assert.deepStrictEqual(r.out[4], [[KEY, RUBBER, 0], [KEY, PEN, 1]]);
});

test("stopping lets go of everything that was held", () => {
    const r = remap("middle click", "erase", [press(PEN), press(LOWER), press(UPPER)]);
    assert.deepStrictEqual(r.release.sort(), [[KEY, UPPER, 0], [KEY, RUBBER, 0]].sort());
});

test("a choice the helper does not know is refused", () => {
    const run = spawnSync("python3", ["-I", SCRIPT, "--device", "x", "--lower", "double click"], { encoding: "utf8" });
    assert.notStrictEqual(run.status, 0);
});

test("a device name matches whether it comes from evdev or from Hyprland", () => {
    const code = [
        "import importlib.util, sys",
        "spec = importlib.util.spec_from_file_location('pen_buttons', sys.argv[1])",
        "module = importlib.util.module_from_spec(spec)",
        "spec.loader.exec_module(module)",
        "print(module.plain('Wacom Intuos Pro M Pen') == module.plain('wacom-intuos-pro-m-pen'), module.plain('RDMCTMZT Galaxy100 2.4G Dongle Mouse') == module.plain('rdmctmzt-galaxy100-2.4g-dongle-mouse'), module.plain('Wacom Intuos Pro M Pad') == module.plain('wacom-intuos-pro-m-pen'))"
    ].join("\n");
    const run = spawnSync("python3", ["-I", "-c", code, SCRIPT], { encoding: "utf8" });
    assert.strictEqual(run.stdout.trim(), "True True False");
});
