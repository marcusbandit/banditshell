const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Load = lib("modules/desktop/load.js", ["cpuTimes", "cpuShare", "coreTimes", "coreShares", "memoryShare", "memoryDetail", "gpuShare", "gpuStats", "swapDevices", "pushCoreHistories", "tempShare", "pushHistory", "linePath", "areaPath", "tipPoint", "tipValue"]);

test("cpu share is the busy part of the time between two samples", () => {
    const before = Load.cpuTimes("cpu  100 0 100 700 100 0 0 0 0 0\ncpu0 1 2 3 4");
    const after = Load.cpuTimes("cpu  200 0 200 1300 200 0 0 0 0 0\n");
    assert.deepStrictEqual(before, { idle: 800, total: 1000 });
    assert.strictEqual(Load.cpuShare(before, after), 200 / 900);
});

test("cpu share is zero without two good samples", () => {
    assert.strictEqual(Load.cpuTimes("intr 1 2 3"), null);
    assert.strictEqual(Load.cpuShare(null, { idle: 1, total: 2 }), 0);
    const same = { idle: 5, total: 10 };
    assert.strictEqual(Load.cpuShare(same, same), 0);
});

test("memory share counts what is not available", () => {
    const m = Load.memoryShare("MemTotal:       16777216 kB\nMemFree:  1000 kB\nMemAvailable:    4194304 kB\n");
    assert.strictEqual(m.share, 0.75);
    assert.strictEqual(m.totalGb, 16);
    assert.strictEqual(m.usedGb, 12);
    assert.deepStrictEqual(Load.memoryShare("garbage"), { share: 0, usedGb: 0, totalGb: 0 });
});

test("gpu share reads single or multi-gpu percentages", () => {
    assert.strictEqual(Load.gpuShare("35\n"), 0.35);
    assert.strictEqual(Load.gpuShare("12\n88\n"), 0.88);
    assert.strictEqual(Load.gpuShare("not a number"), null);
    const stats = Load.gpuStats("75, 6144, 24576, 68.9, NVIDIA GeForce RTX 3090\n");
    assert.deepStrictEqual(stats, { share: 0.75, vramUsedGb: 6, vramTotalGb: 24, vramShare: 0.25, tempC: 69, name: "NVIDIA GeForce RTX 3090" });
    assert.strictEqual(Load.gpuStats("35\n").share, 0.35);
    assert.strictEqual(Load.gpuStats("garbage"), null);
});

test("per-core cpu shares and memory breakdown parse cleanly", () => {
    const before = Load.coreTimes("cpu 0 0 0 0\ncpu0 100 0 0 100 0 0 0 0\ncpu1 50 0 50 100 0 0 0 0\n");
    const after = Load.coreTimes("cpu 0 0 0 0\ncpu0 200 0 0 100 0 0 0 0\ncpu1 50 0 50 200 0 0 0 0\n");
    assert.deepStrictEqual(Load.coreShares(before, after), [{ id: 0, share: 1 }, { id: 1, share: 0 }]);
    const d = Load.memoryDetail("MemTotal: 16777216 kB\nMemAvailable: 4194304 kB\nCached: 2097152 kB\nBuffers: 1048576 kB\nSwapTotal: 8388608 kB\nSwapFree: 6291456 kB\n");
    assert.strictEqual(d.usedGb, 12);
    assert.strictEqual(d.availableGb, 4);
    assert.strictEqual(d.cachedGb, 3);
    assert.strictEqual(d.swapUsedGb, 2);
    assert.strictEqual(d.swapTotalGb, 8);
    assert.strictEqual(d.swapShare, 0.25);
});

test("swap devices sort by priority and core histories update in lockstep", () => {
    const swaps = Load.swapDevices("Filename Type Size Used Priority\n/swapfile file 16777216 1048576 -1\n/dev/zram0 partition 8388608 4194304 100\n");
    assert.strictEqual(swaps.length, 2);
    assert.strictEqual(swaps[0].name, "zram0");
    assert.strictEqual(swaps[0].share, 0.5);
    assert.strictEqual(swaps[1].name, "/swapfile");
    assert.strictEqual(swaps[1].totalGb, 16);
    const h1 = Load.pushCoreHistories([], [{ id: 0, share: 0.2 }, { id: 1, share: 0.8 }], 3);
    const h2 = Load.pushCoreHistories(h1, [{ id: 0, share: 0.4 }, { id: 1, share: 0.6 }], 3);
    assert.deepStrictEqual(h2, [[0.2, 0.4], [0.8, 0.6]]);
    assert.strictEqual(Load.tempShare(68), 0.68);
});

test("history ring clamps values and caps length", () => {
    let h = [];
    for (const v of [-0.2, 0.5, 1.4, 0.25])
        h = Load.pushHistory(h, v, 3);
    assert.deepStrictEqual(h, [0.5, 1, 0.25]);
});

test("line, area and tip map samples cleanly to the right edge", () => {
    assert.strictEqual(Load.linePath([0.5], 100, 50, 5), "");
    assert.strictEqual(Load.areaPath([0.5], 100, 50, 5), "");
    assert.strictEqual(Load.linePath([0, 1], 100, 50, 5, 1), "M75.0 50.0 L100.0 0.0");
    assert.strictEqual(Load.areaPath([0, 1], 100, 50, 5, 1), "M75.0 50.0 L100.0 0.0 L100.0 50.0 L75.0 50.0 Z");
    assert.ok(Load.linePath([0, 0.5, 1], 100, 50, 3, 1).startsWith("M0.0 50.0 C"));
    assert.ok(Load.linePath([0, 0.5, 1], 100, 50, 3, 1).endsWith("100.0 0.0"));
    assert.deepStrictEqual(Load.tipPoint([0.2, 0.75], 100, 40, 24, 1), { x: 100, y: 10 });
    assert.strictEqual(Load.tipPoint([], 100, 40, 24, 1), null);
});

test("one-tick delayed interpolation eases smoothly and stays continuous across tick boundaries", () => {
    assert.strictEqual(Load.tipValue([0.2, 0.8], 0), 0.2);
    assert.ok(Load.tipValue([0.2, 0.8], 0.25) < 0.35);
    assert.ok(Math.abs(Load.tipValue([0.2, 0.8], 0.5) - 0.5) < 1e-9);
    assert.ok(Load.tipValue([0.2, 0.8], 0.75) > 0.65);
    assert.strictEqual(Load.tipValue([0.2, 0.8], 1), 0.8);
    assert.strictEqual(Load.linePath([0, 0.5, 1], 100, 50, 3, 1), Load.linePath([0, 0.5, 1, 0.2], 100, 50, 3, 0));
    assert.strictEqual(Load.areaPath([0, 0.5, 1], 100, 50, 3, 1), Load.areaPath([0, 0.5, 1, 0.2], 100, 50, 3, 0));
    assert.deepStrictEqual(Load.tipPoint([0, 0.5, 1], 100, 50, 3, 1), Load.tipPoint([0, 0.5, 1, 0.2], 100, 50, 3, 0));
});

const Month = lib("modules/desktop/month.js", ["cells", "keyOf", "title", "shifted"]);

test("a month grid starts on the Monday before the first", () => {
    const grid = Month.cells(2026, 10, 1);
    assert.strictEqual(grid.length, 42);
    assert.deepStrictEqual(grid.slice(0, 7).map(c => c.day), [26, 27, 28, 29, 30, 31, 1]);
    assert.strictEqual(grid[6].inMonth, true);
    assert.strictEqual(grid[5].inMonth, false);
    assert.strictEqual(grid.filter(c => c.inMonth).length, 30);
    assert.strictEqual(grid[6].key, Month.keyOf(new Date(2026, 10, 1)));
});

test("a month that starts on a Monday has no lead days", () => {
    const grid = Month.cells(2026, 5, 1);
    assert.strictEqual(grid[0].day, 1);
    assert.strictEqual(grid[0].inMonth, true);
});

test("a month grid starts on whichever weekday the week starts on", () => {
    const sunday = Month.cells(2026, 10, 0);
    assert.deepStrictEqual(sunday.slice(0, 7).map(c => c.day), [1, 2, 3, 4, 5, 6, 7]);
    const saturday = Month.cells(2026, 10, 6);
    assert.deepStrictEqual(saturday.slice(0, 7).map(c => c.day), [31, 1, 2, 3, 4, 5, 6]);
    assert.deepStrictEqual(sunday.filter(c => c.rowStart).length, 6);
});

test("paging months crosses years", () => {
    assert.deepStrictEqual(Month.shifted(2026, 11, 1), { year: 2027, month: 0 });
    assert.deepStrictEqual(Month.shifted(2026, 0, -1), { year: 2025, month: 11 });
    assert.strictEqual(Month.title(2026, 10), "November 2026");
});

const Backdrop = lib("modules/desktop/backdrop.js", ["placement", "shrunk", "luminance", "contrast", "judge"]);

function patch(pixels) {
    return pixels.flatMap(([r, g, b]) => [r, g, b, 255]);
}

const WHITE_INK = Backdrop.luminance(240, 240, 240);
const BLACK_INK = Backdrop.luminance(20, 20, 20);

test("a picture is placed the way the wallpaper crops it to fill the screen", () => {
    assert.deepStrictEqual(Backdrop.placement(1, 320, 90), { x: 0, y: -115, width: 320, height: 320 });
    assert.deepStrictEqual(Backdrop.placement(16, 320, 90), { x: -560, y: 0, width: 1440, height: 90 });
    assert.strictEqual(Backdrop.placement(0, 320, 90), null);
});

test("the clock's spot shrinks with the canvas and stays inside it", () => {
    assert.deepStrictEqual(Backdrop.shrunk({ x: 3600, y: 24, width: 468, height: 400 }, 320 / 5120, 320, 90), { x: 225, y: 1, width: 30, height: 25 });
    assert.deepStrictEqual(Backdrop.shrunk({ x: 5000, y: 1300, width: 468, height: 400 }, 320 / 5120, 320, 90), { x: 312, y: 81, width: 8, height: 9 });
    assert.strictEqual(Backdrop.shrunk({ x: 6000, y: 0, width: 10, height: 10 }, 320 / 5120, 320, 90), null);
});

test("dark pictures get light figures and bright ones dark figures", () => {
    assert.deepStrictEqual(Backdrop.judge(patch(Array(16).fill([10, 10, 30])), WHITE_INK, BLACK_INK), { light: true, busy: false });
    assert.deepStrictEqual(Backdrop.judge(patch(Array(16).fill([250, 250, 245])), WHITE_INK, BLACK_INK), { light: false, busy: false });
});

test("a picture half black and half white is too busy for bare figures", () => {
    const half = patch([...Array(8).fill([0, 0, 0]), ...Array(8).fill([255, 255, 255])]);
    assert.strictEqual(Backdrop.judge(half, WHITE_INK, BLACK_INK).busy, true);
});

test("one flat colour always suits one of the two inks", () => {
    for (const v of [0, 64, 110, 128, 160, 200, 255])
        assert.strictEqual(Backdrop.judge(patch(Array(16).fill([v, v, v])), WHITE_INK, BLACK_INK).busy, false, String(v));
    assert.strictEqual(Backdrop.judge(patch(Array(16).fill([128, 128, 128])), WHITE_INK, BLACK_INK).light, true);
});

test("see-through parts of a picture count as the black behind them", () => {
    const clear = Array(16).fill([255, 255, 255]).flatMap(([r, g, b]) => [r, g, b, 0]);
    assert.deepStrictEqual(Backdrop.judge(clear, WHITE_INK, BLACK_INK), { light: true, busy: false });
});

test("no picture at all reads as the black desktop", () => {
    assert.deepStrictEqual(Backdrop.judge([], WHITE_INK, BLACK_INK), { light: true, busy: false });
});
