const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const SCRIPT = path.resolve(__dirname, "../scripts/install-package.sh");

function bin(tools) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "install-package-"));
    for (const [name, body] of Object.entries(tools)) {
        fs.writeFileSync(path.join(dir, name), `#!/bin/sh\n${body}\n`);
        fs.chmodSync(path.join(dir, name), 0o755);
    }
    return dir;
}

function run(args, tools) {
    const dir = bin(tools);
    const out = spawnSync("bash", [SCRIPT, ...args], { env: { PATH: `${dir}:/usr/bin:/bin`, BANDITSHELL_SYSTEM_PATH: `${dir}:/usr/bin:/bin` }, encoding: "utf8" });
    fs.rmSync(dir, { recursive: true, force: true });
    return out;
}

function runBare(args, tools) {
    const dir = bin(tools);
    const core = fs.mkdtempSync(path.join(os.tmpdir(), "install-package-core-"));
    fs.symlinkSync(spawnSync("sh", ["-c", "command -v id"], { encoding: "utf8" }).stdout.trim(), path.join(core, "id"));
    const out = spawnSync("/bin/bash", [SCRIPT, ...args], { env: { PATH: `${dir}:${core}`, BANDITSHELL_SYSTEM_PATH: `${dir}:${core}` }, encoding: "utf8" });
    fs.rmSync(dir, { recursive: true, force: true });
    fs.rmSync(core, { recursive: true, force: true });
    return out;
}

test.describe("install-package.sh", () => {
    test.it("writes the install line for the first package manager it finds", () => {
        const out = runBare(["--command", "zypper:qalculate", "apt:qalc", "pacman:libqalculate"], { "apt-get": "exit 0", sudo: "exit 0" });
        assert.strictEqual(out.status, 0);
        assert.strictEqual(out.stdout.trim(), "sudo apt-get install -y qalc");
    });

    test.it("tries sudo without a password when asked to stay quiet", () => {
        const out = run(["--quiet", "dnf:qalculate"], { dnf: "exit 0", sudo: "printf '%s\\n' \"$*\"; exit 1" });
        assert.strictEqual(out.status, 10);
        assert.strictEqual(out.stdout.trim(), "-n dnf install -y -- qalculate");
    });

    test.it("asks for the password through pkexec, quietly for apt", () => {
        const out = run(["--polkit", "apt:qalc"], { "apt-get": "exit 0", pkexec: "printf '%s\\n' \"$*\"" });
        assert.strictEqual(out.status, 0);
        assert.match(out.stdout.trim(), /^\/\S*\/env DEBIAN_FRONTEND=noninteractive apt-get install -y qalc$/);
    });

    test.it("hands pkexec a program found in the system folders, never one from the user's PATH", () => {
        const out = run(["--polkit", "pacman:qalc"], { pacman: "exit 0", pkexec: "printf '%s\\n' \"$1\"" });
        assert.strictEqual(out.status, 0);
        assert.ok(out.stdout.trim().startsWith("/"), out.stdout);
        assert.ok(out.stdout.trim().endsWith("/pacman"), out.stdout);
    });

    test.it("says so when no package manager is there", () => {
        const out = runBare(["--command", "zypper:qalculate", "xbps:libqalculate"], {});
        assert.strictEqual(out.status, 3);
    });

    test.it("installs a flatpak into the installation it came from, without pkexec", () => {
        const out = run(["--polkit", "flatpak:user/flathub/com.spotify.Client"], { flatpak: "printf '%s\\n' \"$*\"", pkexec: "echo pkexec; exit 9", sudo: "exit 9" });
        assert.strictEqual(out.status, 0);
        assert.strictEqual(out.stdout.trim(), "install -y --noninteractive --user -- flathub com.spotify.Client");
        const line = run(["--command", "flatpak:system/flathub/org.mozilla.firefox"], { flatpak: "exit 0", sudo: "exit 0" });
        assert.strictEqual(line.stdout.trim(), "flatpak install -y --noninteractive --system -- flathub org.mozilla.firefox");
    });

    test.it("builds from the AUR only in a terminal, where the helper shows the PKGBUILD", () => {
        assert.strictEqual(runBare(["--polkit", "aur:paru-bin"], { yay: "echo built; exit 0", pkexec: "exit 0" }).status, 4);
        assert.strictEqual(runBare(["--quiet", "aur:paru-bin"], { paru: "echo built; exit 0", sudo: "exit 0" }).status, 4);
        assert.strictEqual(runBare(["--command", "aur:thing"], { paru: "exit 0", yay: "exit 0", sudo: "exit 0" }).stdout.trim(), "paru -S thing");
        assert.strictEqual(runBare(["--command", "aur:thing"], { yay: "exit 0" }).stdout.trim(), "yay -S thing");
        assert.strictEqual(runBare(["--command", "aur:thing"], { pacman: "exit 0" }).status, 3);
    });

    test.it("refuses names that are not package names", () => {
        for (const bad of ["pacman:-rf", "pacman:a b", "pacman:", "aur:$(id)", "flatpak:system/flathub/-x", "flatpak:root/flathub/x"])
            assert.strictEqual(run(["--command", bad], { pacman: "exit 0", yay: "exit 0", flatpak: "exit 0", sudo: "exit 0" }).status, 2, bad);
        assert.strictEqual(run(["--command", "pacman:gtk3+extra_1.2@x:y"], { pacman: "exit 0", sudo: "exit 0" }).status, 0);
    });

    test.it("keeps the manager's own failures apart from the script's answers", () => {
        assert.strictEqual(run(["--polkit", "zypper:thing"], { zypper: "exit 3", pkexec: 'shift 0; "$@"' }).status, 10);
        assert.strictEqual(run(["--polkit", "zypper:thing"], { zypper: "exit 4", pkexec: '"$@"' }).status, 10);
        assert.strictEqual(run(["--polkit", "pacman:thing"], { pacman: "exit 0", pkexec: "exit 126" }).status, 126);
        assert.strictEqual(run(["--polkit", "flatpak:system/flathub/com.x.App"], { flatpak: "exit 1" }).status, 10);
    });
});
