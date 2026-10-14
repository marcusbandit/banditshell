const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/pacman.js"), "utf8");
const Pacman = new Function(src + "\nreturn { report, updates, pretty, pending };")();

test("the report splits the probe's values from checkupdates' lines", () => {
    const got = Pacman.report("kernel=linux\nrunning=7.2.9-arch1-1\ncode=0\n|aom 3.15.1-1 -> 3.15.2-1\n|linux 7.2.9.arch1-1 -> 7.2.10.arch1-1\n");
    assert.deepStrictEqual(got.values, { kernel: "linux", running: "7.2.9-arch1-1", code: "0" });
    assert.deepStrictEqual(got.lines, ["aom 3.15.1-1 -> 3.15.2-1", "linux 7.2.9.arch1-1 -> 7.2.10.arch1-1"]);
});

test("a checkupdates line that looks like a value stays a line", () => {
    const got = Pacman.report("|==> ERROR: key=value in a message\n");
    assert.deepStrictEqual(got.values, {});
    assert.deepStrictEqual(got.lines, ["==> ERROR: key=value in a message"]);
});

test("only update lines become updates, epochs and all", () => {
    const got = Pacman.updates(["aom 3.15.1-1 -> 3.15.2-1", "==> ERROR: Cannot fetch updates", "", "discord 1:1.0.161-1 -> 1:1.0.162-1"]);
    assert.deepStrictEqual(got, [
        { name: "aom", from: "3.15.1-1", to: "3.15.2-1" },
        { name: "discord", from: "1:1.0.161-1", to: "1:1.0.162-1" }
    ]);
});

test("the kernel is found by its exact package name", () => {
    const list = Pacman.updates(["linux-firmware 20261001-1 -> 20261010-1", "linux-lts 6.12.50-1 -> 6.12.51-1"]);
    assert.strictEqual(Pacman.pending(list, "linux"), null);
    assert.strictEqual(Pacman.pending(list, "linux-lts").to, "6.12.51-1");
});

test("a version reads the way the kernel calls itself", () => {
    assert.strictEqual(Pacman.pretty("7.2.10.arch1-1"), "7.2.10");
    assert.strictEqual(Pacman.pretty("7.2.9-arch1-1"), "7.2.9");
    assert.strictEqual(Pacman.pretty("7.2.9.zen1-2"), "7.2.9");
    assert.strictEqual(Pacman.pretty("6.12.50-1"), "6.12.50");
    assert.strictEqual(Pacman.pretty("1:2.3-4"), "2.3");
    assert.strictEqual(Pacman.pretty(""), "");
});
