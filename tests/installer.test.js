const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const ASKPASS = path.join(ROOT, "installer/askpass.sh");
const roots = [];

test.after(() => {
    for (const dir of roots) {
        try { process.kill(Number(fs.readFileSync(path.join(dir, "run/ui.pid"), "utf8"))); } catch {}
        fs.rmSync(dir, { recursive: true, force: true });
    }
});

function world(tools = {}) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "installer-"));
    roots.push(dir);
    fs.mkdirSync(path.join(dir, "bin"));
    fs.mkdirSync(path.join(dir, "home"));
    for (const [name, body] of Object.entries(tools)) {
        fs.writeFileSync(path.join(dir, "bin", name), `#!/usr/bin/env bash\n${body}\n`);
        fs.chmodSync(path.join(dir, "bin", name), 0o755);
    }
    return dir;
}

const WINDOW = 'd="$BANDITSHELL_ASKPASS_DIR"; touch "$d/ready"; read -r line <"$d/req"';

function env(dir, extra = {}) {
    return { PATH: `${dir}/bin:${process.env.PATH}`, HOME: `${dir}/home`, BANDITSHELL_ASKPASS_DIR: `${dir}/run`, ...extra };
}

function askpass(dir, extra) {
    const started = Date.now();
    const out = spawnSync("bash", [ASKPASS], { encoding: "utf8", timeout: 15000, env: env(dir, extra) });
    return { ...out, seconds: (Date.now() - started) / 1000 };
}

function installer(dir, snippet, extra = {}) {
    return spawnSync("bash", ["-c", `source "${path.join(ROOT, "install.sh")}"; REPO="${dir}"; OMARCHY_SYSTEM="${dir}/system-omarchy"; ${snippet}`],
        { encoding: "utf8", timeout: 15000, env: env(dir, { LANG: "C.UTF-8", ...extra }) });
}

function omarchy(dir, where = "home/.local/share/omarchy") {
    fs.mkdirSync(path.join(dir, where, "bin"), { recursive: true });
    fs.writeFileSync(path.join(dir, where, "bin/omarchy-version"), "");
}

test.describe("the password window", () => {
    test.it("hands back what the window answered", () => {
        const dir = world({ qs: `${WINDOW}; printf 'hunter 2\\n' >"$d/rsp"; exec sleep 30` });
        const out = askpass(dir);
        assert.strictEqual(out.status, 0, out.stderr);
        assert.strictEqual(out.stdout, "hunter 2\n");
    });

    test.it("gives up at once when the window dies after taking the request", () => {
        const dir = world({ qs: `${WINDOW}; exit 0` });
        const out = askpass(dir);
        assert.strictEqual(out.status, 1);
        assert.ok(out.seconds < 5, `took ${out.seconds}s`);
        assert.strictEqual(out.stdout, "");
        assert.match(fs.readFileSync(path.join(dir, "run/why"), "utf8"), /closed without an answer/);
    });

    test.it("says so when the window never opens", () => {
        const out = askpass(world({ qs: "exit 0" }));
        assert.strictEqual(out.status, 1);
        assert.match(out.stderr, /the password window did not open/);
    });

    test.it("stops waiting on a window that never answers", () => {
        const dir = world({ qs: `${WINDOW}; exec sleep 30` });
        const out = askpass(dir, { BANDITSHELL_ASKPASS_WAIT: "2" });
        assert.strictEqual(out.status, 1);
        assert.ok(out.seconds < 6, `took ${out.seconds}s`);
        assert.match(out.stderr, /no answer from the password window in 2 seconds/);
    });

    test.it("tells the installer why, then falls back to the terminal", () => {
        const dir = world({
            qs: `${WINDOW}; exit 0`,
            sudo: '[ "$1" = -A ] && { "$SUDO_ASKPASS" >/dev/null || exit 1; exit 0; }\nexit 1'
        });
        const out = installer(dir, `UI_DIR="${ROOT}/installer"; ASKPASS_RUN="${dir}/run"; need_root; echo "root $?"`, { WAYLAND_DISPLAY: "wayland-test" });
        assert.match(out.stdout, /the password window closed without an answer\n.*falling back to the terminal/);
        assert.match(out.stdout, /authentication failed \(3 of 3\)\nroot 1\n$/);
    });
});

test.describe("Omarchy", () => {
    test.it("without a terminal it stops with exit 1 and both next commands", () => {
        const dir = world();
        omarchy(dir);
        const out = installer(dir, `REPO="${dir}/home/banditshell"; main </dev/null`);
        assert.strictEqual(out.status, 1);
        assert.match(out.stdout, /both try to show your\nnotifications/);
        assert.match(out.stdout, /omarchy plugin remove banditshell\.island/);
        assert.match(out.stdout, /To add the island:\n {4}omarchy plugin add https:\/\/github\.com\/marcusbandit\/banditshell-island\.git --enable\n/);
        assert.match(out.stdout, /Or the full shell anyway:\n {4}~\/banditshell\/install\.sh --beside-omarchy\n$/);
    });

    test.it("finds the packaged install and the one OMARCHY_PATH names", () => {
        const dir = world();
        omarchy(dir, "system-omarchy");
        omarchy(dir, "elsewhere");
        assert.match(installer(dir, "omarchy_present; echo $?").stdout, /^0$/m);
        fs.rmSync(path.join(dir, "system-omarchy"), { recursive: true });
        assert.match(installer(dir, "omarchy_present; echo $?").stdout, /^1$/m);
        assert.match(installer(dir, "omarchy_present; echo $?", { OMARCHY_PATH: `${dir}/elsewhere` }).stdout, /^0$/m);
    });

    test.it("adds the island on Enter, and says how to hand it notifications and remove it", () => {
        const dir = world({ omarchy: 'echo "$*" >>"$HOME/omarchy.log"' });
        omarchy(dir);
        const out = installer(dir, `can_ask() { true; }; omarchy_check <<<""; echo "go $?"`);
        assert.strictEqual(fs.readFileSync(path.join(dir, "home/omarchy.log"), "utf8"), "plugin add https://github.com/marcusbandit/banditshell-island.git --enable\n");
        assert.match(out.stdout, /omarchy plugin disable omarchy\.notifications && omarchy restart shell\nTo remove it again:\n {4}omarchy plugin remove banditshell\.island\ngo 2\n$/);
        assert.strictEqual(installer(dir, `can_ask() { true; }; main <<<1 >/dev/null`).status, 0);
    });

    test.it("prints the island command when adding it fails or omarchy is missing", () => {
        const failing = world({ omarchy: "exit 1" });
        omarchy(failing);
        assert.match(installer(failing, `can_ask() { true; }; omarchy_check <<<1; echo "go $?"`).stdout, /did not work.*\n {4}omarchy plugin add \S+ --enable\ngo 1\n$/);
        const missing = world();
        omarchy(missing);
        assert.match(installer(missing, `can_ask() { true; }; omarchy_check <<<1; echo "go $?"`).stdout, /not on your PATH.*\n {4}omarchy plugin add \S+ --enable\ngo 1\n$/);
    });

    test.it("installs the full shell on 2, names the flag, and cancels on anything else", () => {
        const dir = world();
        omarchy(dir);
        const full = installer(dir, `can_ask() { true; }; omarchy_check <<<2; echo "go $? $BESIDE_OMARCHY"`);
        assert.match(full.stdout, /install\.sh --beside-omarchy\n\ngo 0 1\n$/);
        assert.match(installer(dir, `can_ask() { true; }; omarchy_check <<<3; echo "go $? $BESIDE_OMARCHY"`).stdout, /--beside-omarchy\ngo 1 0\n$/);
        assert.strictEqual(installer(dir, `can_ask() { true; }; main <<<3 >/dev/null`).status, 1);
        assert.strictEqual(installer(dir, `BESIDE_OMARCHY=1; omarchy_check; echo "go $?"`).stdout, "go 0\n");
    });

    test.it("only shows the tip on a dry run, and never asks a checkout that already installed", () => {
        const dir = world();
        omarchy(dir);
        const dry = installer(dir, `DRY_RUN=1; omarchy_check </dev/null; echo "go $?"`);
        assert.match(dry.stdout, /adds nothing\.\n\ngo 0\n$/);
        fs.mkdirSync(path.join(dir, "cli"));
        fs.writeFileSync(path.join(dir, "cli/banditshell"), "", { mode: 0o755 });
        fs.symlinkSync("../cli/banditshell", path.join(dir, "bin/banditshell"));
        assert.strictEqual(installer(dir, `omarchy_check </dev/null; echo "go $?"`).stdout, "go 0\n");
    });

    test.it("asks anyway when the environment says something other than 1", () => {
        const dir = world();
        omarchy(dir);
        assert.match(installer(dir, `omarchy_check </dev/null; echo "go $?"`, { BANDITSHELL_BESIDE_OMARCHY: "yes" }).stdout, /go 1\n$/);
    });

    test.it("keeps the choice across the move to the release, which may not know the flag", () => {
        const dir = world();
        omarchy(dir);
        fs.writeFileSync(path.join(dir, "install.sh"), 'echo "args [$*] beside $BANDITSHELL_BESIDE_OMARCHY release $BANDITSHELL_ON_RELEASE"\n');
        const out = installer(dir, `REPO="${dir}"; INSTALL_ARGS=(--dry-run --beside-omarchy); BESIDE_OMARCHY=1; checkout_release() { return 0; }; main`);
        assert.strictEqual(out.stdout, "args [--dry-run] beside 1 release 1\n");
    });

    test.it("says nothing where there is no Omarchy", () => {
        const out = installer(world(), `omarchy_check </dev/null; echo "go $?"`);
        assert.strictEqual(out.stdout, "go 0\n");
    });
});
