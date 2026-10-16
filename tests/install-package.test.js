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
    const out = spawnSync("bash", [SCRIPT, ...args], { env: { PATH: `${dir}:/usr/bin:/bin` }, encoding: "utf8" });
    fs.rmSync(dir, { recursive: true, force: true });
    return out;
}

function runBare(args, tools) {
    const dir = bin(tools);
    const core = fs.mkdtempSync(path.join(os.tmpdir(), "install-package-core-"));
    fs.symlinkSync(spawnSync("sh", ["-c", "command -v id"], { encoding: "utf8" }).stdout.trim(), path.join(core, "id"));
    const out = spawnSync("/bin/bash", [SCRIPT, ...args], { env: { PATH: `${dir}:${core}` }, encoding: "utf8" });
    fs.rmSync(dir, { recursive: true, force: true });
    fs.rmSync(core, { recursive: true, force: true });
    return out;
}

test.describe("install-package.sh", () => {
    test.it("writes the install line for the first package manager it finds", () => {
        const out = run(["--command", "zypper:qalculate", "apt:qalc", "pacman:libqalculate"], { "apt-get": "exit 0", sudo: "exit 0" });
        assert.strictEqual(out.status, 0);
        assert.strictEqual(out.stdout.trim(), "sudo apt-get install -y qalc");
    });

    test.it("tries sudo without a password when asked to stay quiet", () => {
        const out = run(["--quiet", "dnf:qalculate"], { dnf: "exit 0", sudo: "printf '%s\\n' \"$*\"; exit 1" });
        assert.strictEqual(out.status, 1);
        assert.strictEqual(out.stdout.trim(), "-n dnf install -y qalculate");
    });

    test.it("asks for the password through pkexec, quietly for apt", () => {
        const out = run(["--polkit", "apt:qalc"], { "apt-get": "exit 0", pkexec: "printf '%s\\n' \"$*\"" });
        assert.strictEqual(out.status, 0);
        assert.strictEqual(out.stdout.trim(), "env DEBIAN_FRONTEND=noninteractive apt-get install -y qalc");
    });

    test.it("says so when no package manager is there", () => {
        const out = run(["--command", "zypper:qalculate", "xbps:libqalculate"], {});
        assert.strictEqual(out.status, 3);
    });

    test.it("installs a flatpak into the installation it came from, without pkexec", () => {
        const out = run(["--polkit", "flatpak:user/flathub/com.spotify.Client"], { flatpak: "printf '%s\\n' \"$*\"", pkexec: "echo pkexec; exit 9", sudo: "exit 9" });
        assert.strictEqual(out.status, 0);
        assert.strictEqual(out.stdout.trim(), "install -y --noninteractive --user flathub com.spotify.Client");
        const line = run(["--command", "flatpak:system/flathub/org.mozilla.firefox"], { flatpak: "exit 0", sudo: "exit 0" });
        assert.strictEqual(line.stdout.trim(), "flatpak install -y --noninteractive --system flathub org.mozilla.firefox");
    });

    test.it("builds from the AUR as the user, with pkexec standing in for sudo", () => {
        const out = runBare(["--polkit", "aur:paru-bin"], { yay: "printf '%s\\n' \"$*\"", pkexec: "exit 0", sudo: "exit 9" });
        assert.strictEqual(out.status, 0);
        assert.strictEqual(out.stdout.trim(), "-S --needed --noconfirm --answerdiff None --answerclean None --answeredit None --sudo pkexec paru-bin");
        const paru = runBare(["--command", "aur:thing"], { paru: "exit 0", yay: "exit 0", sudo: "exit 0" });
        assert.strictEqual(paru.stdout.trim(), "paru -S --needed --noconfirm --skipreview thing");
    });

    test.it("hands an AUR build to the terminal when the helper cannot use pkexec", () => {
        assert.strictEqual(runBare(["--polkit", "aur:thing"], { pikaur: "exit 0", pkexec: "exit 0" }).status, 4);
        assert.strictEqual(runBare(["--polkit", "aur:thing"], { paru: "exit 0" }).status, 4);
        assert.strictEqual(runBare(["--command", "aur:thing"], { pacman: "exit 0" }).status, 3);
    });
});
