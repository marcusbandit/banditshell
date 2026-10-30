const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/pacman.js"), "utf8");
const Pacman = new Function(src + "\nreturn { report, updates, pretty, pending, verdict, listed, kernelUpdate, terminalCommand };")();

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

const lines = name => fs.readFileSync(path.join(ROOT, "tests/fixtures/system-upgrade", name), "utf8").split("\n");

test("apt, dnf and zypper update lists read as name, from and to", () => {
    assert.deepStrictEqual(Pacman.listed("apt", lines("apt-list.txt")), [{ name: "tzdata", from: "2026e-0+deb13u1", to: "2026f-0+deb13u1" }]);
    assert.deepStrictEqual(Pacman.listed("dnf", lines("dnf-list.txt")).map(u => `${u.name} ${u.to}`), ["curl 8.18.0-14.fc44", "libcurl 8.18.0-14.fc44", "libsolv 0.7.41-1.fc44", "sqlite-libs 3.51.2-2.fc44", "tzdata 2026e-1.fc44"]);
    assert.deepStrictEqual(Pacman.listed("zypper", lines("zypper-list.txt")), [{ name: "openSUSE-build-key", from: "1.0-68.1", to: "1.0-69.1" }]);
    assert.deepStrictEqual(Pacman.listed("dnf", ["python3-some-very-long-package-name.noarch", "        3.2.1-1.fc44   updates", "Obsoleting Packages", "grub2-tools.x86_64  1:2.12-9.fc44  updates"]), [{ name: "python3-some-very-long-package-name", from: "", to: "3.2.1-1.fc44" }]);
});

test("each tool's exit code says whether the list holds updates", () => {
    assert.deepStrictEqual(["0", "2", "1"].map(c => Pacman.verdict("pacman", c)), ["updates", "none", "error"]);
    assert.deepStrictEqual(["100", "0", "1"].map(c => Pacman.verdict("dnf", c)), ["updates", "none", "error"]);
    assert.deepStrictEqual(["0", "100", "4"].map(c => Pacman.verdict("zypper", c)), ["updates", "updates", "error"]);
    assert.deepStrictEqual(["0", "", "100"].map(c => Pacman.verdict("apt", c)), ["updates", "error", "error"]);
});

test("off Arch the kernel is the distro's kernel package, the meta package first", () => {
    const apt = [{ name: "linux-image-6.12.57+deb13-amd64", to: "6.12.57-1" }, { name: "linux-image-amd64", to: "6.12.57-1" }];
    assert.strictEqual(Pacman.kernelUpdate(apt, "apt", "").name, "linux-image-amd64");
    assert.strictEqual(Pacman.kernelUpdate([{ name: "kernel-core", to: "6.17.5-200.fc44" }, { name: "kernel", to: "6.17.5-200.fc44" }], "dnf", "").name, "kernel");
    assert.strictEqual(Pacman.kernelUpdate([{ name: "kernel-default", to: "6.17.5-1.1" }], "zypper", "").name, "kernel-default");
    assert.strictEqual(Pacman.kernelUpdate([{ name: "kernel-firmware", to: "1" }], "zypper", ""), null);
    assert.strictEqual(Pacman.kernelUpdate([{ name: "linux-lts", to: "6.12.1-1" }], "pacman", "linux-lts").name, "linux-lts");
    assert.strictEqual(Pacman.pretty("6.12.57+deb13-amd64"), "6.12.57");
    assert.strictEqual(Pacman.pretty("6.17.5-200.fc44"), "6.17.5");
});

test("the terminal fallback runs the system's own upgrade unless the command was changed", () => {
    assert.strictEqual(Pacman.terminalCommand("apt", "sudo pacman -Syu", false), "sudo sh -c 'apt-get update && apt-get full-upgrade'");
    assert.strictEqual(Pacman.terminalCommand("dnf", "", false), "sudo dnf upgrade --refresh");
    assert.strictEqual(Pacman.terminalCommand("zypper", "sudo pacman  -Syu", true), "sudo zypper dist-upgrade");
    assert.strictEqual(Pacman.terminalCommand("zypper", "sudo pacman -Syu", false), "sudo zypper update");
    assert.strictEqual(Pacman.terminalCommand("apt", "sudo nala upgrade", false), "sudo nala upgrade");
    assert.strictEqual(Pacman.terminalCommand("pacman", "paru", false), "paru");
});
