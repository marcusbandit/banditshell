const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/system-upgrade.js"), "utf8");
const Upgrade = new Function(src + "\nreturn { plan, create, feed, clean, stages, stageIndex, fraction, describe, brief, cancellable, outcome, explain, headline, proceeds };")();

const fixture = name => fs.readFileSync(path.join(ROOT, "tests/fixtures/system-upgrade", name), "latin1");

function run(text, size, tool) {
    const state = Upgrade.create(tool);
    if (!size)
        return Upgrade.feed(state, text);
    for (let i = 0; i < text.length; i += size)
        Upgrade.feed(state, text.slice(i, i + size));
    return state;
}

test("a recorded upgrade reads as three packages installed", () => {
    const state = run(fixture("upgrade.log"));
    assert.strictEqual(state.phase, "install");
    assert.strictEqual(state.total, 3);
    assert.deepStrictEqual(state.packages, ["expat", "feh", "less"]);
    assert.deepStrictEqual(state.install, { index: 3, total: 3, verb: "upgrading", name: "less", fraction: 1 });
    assert.ok(state.sizes.download.endsWith("MiB"));
    assert.strictEqual(state.question, null);
    assert.strictEqual(Upgrade.outcome(state, 0), "done");
    assert.strictEqual(Upgrade.headline(state, "done"), "System updated");
});

test("chunks cut anywhere, even inside an escape code, read the same", () => {
    const whole = run(fixture("upgrade.log"));
    for (const size of [1, 7, 13, 64]) {
        const cut = run(fixture("upgrade.log"), size);
        assert.deepStrictEqual(cut.install, whole.install, `size ${size}`);
        assert.deepStrictEqual(cut.packages, whole.packages, `size ${size}`);
        assert.strictEqual(cut.phase, whole.phase, `size ${size}`);
    }
});

test("progress only moves forward through a real run", () => {
    const text = fixture("upgrade.log");
    const state = Upgrade.create();
    let last = 0;
    for (let i = 0; i < text.length; i += 40) {
        Upgrade.feed(state, text.slice(i, i + 40));
        const now = Upgrade.fraction(state, false);
        assert.ok(now + 1e-9 >= last, `went back from ${last} to ${now} at byte ${i}`);
        last = now;
    }
    assert.ok(last > 0.89);
});

test("the proceed prompt is a question until it is answered", () => {
    const text = fixture("upgrade.log");
    const at = text.indexOf("Proceed with installation?");
    const end = text.indexOf("\x1b[?25h", at);
    const state = run(text.slice(0, end));
    assert.strictEqual(state.question.kind, "yesno");
    assert.strictEqual(state.question.text, "Proceed with installation?");
    assert.strictEqual(state.question.yes, true);
    const id = state.question.id;
    Upgrade.feed(state, "\x1b[?25h");
    assert.strictEqual(state.question.id, id, "the same prompt is not a new question");
    Upgrade.feed(state, "y\r\n");
    assert.strictEqual(state.question, null);
});

test("cancel is offered until pacman starts checking packages", () => {
    const text = fixture("upgrade.log");
    const download = run(text.slice(0, text.indexOf("Retrieving packages") + 40));
    assert.strictEqual(download.phase, "download");
    assert.ok(Upgrade.cancellable(download));
    const check = run(text.slice(0, text.indexOf("checking package integrity") + 60));
    assert.strictEqual(check.phase, "check");
    assert.ok(!Upgrade.cancellable(check));
    assert.ok(!Upgrade.cancellable(run(text)));
});

test("a recorded cancel during the download changes nothing", () => {
    const state = run(fixture("cancel.log"));
    assert.strictEqual(state.phase, "download");
    assert.ok(state.interrupted);
    assert.ok(!state.committing);
    assert.strictEqual(Upgrade.outcome(state, 130), "cancelled");
    assert.strictEqual(Upgrade.explain(state, 130), "Stopped before anything was installed. Nothing changed.");
});

test("an interrupt once packages are being replaced is a failure even when pacman exits 0", () => {
    const state = run(":: Processing package changes...\r\n( 1/14) installing linux-api-headers   [######] 100%\r\r\n^C\r\nInterrupt signal received\r\n");
    assert.strictEqual(Upgrade.outcome(state, 0), "failed");
    assert.match(Upgrade.explain(state, 0), /partway/);
});

test("hooks report which one runs and what mkinitcpio is doing", () => {
    const state = run(":: Processing package changes...\r\n(1/1) upgrading linux  [###] 100%\r\r\n:: Running post-transaction hooks...\r\n(1/4) Arming ConditionNeedsUpdate...\r\n(2/4) Updating linux initcpios...\r\n==> Building image from preset: /etc/mkinitcpio.d/linux.preset: 'default'\r\n");
    assert.strictEqual(state.phase, "hooks");
    assert.deepStrictEqual(state.hooks, { index: 2, total: 4, text: "Updating linux initcpios" });
    assert.strictEqual(Upgrade.describe(state), "Building image from preset: /etc/mkinitcpio.d/linux.preset: 'default'");
    assert.strictEqual(Upgrade.stageIndex(state), 3);
    assert.strictEqual(Upgrade.stages(state, false)[3].fill, 0.25);
});

test("a provider choice is a numbered question with its default", () => {
    const state = run(":: Starting full system upgrade...\r\n:: There are 2 providers available for vulkan-driver:\r\n:: Repository extra\r\n   1) amdvlk  2) vulkan-radeon\r\n\r\nEnter a number (default=1): ");
    assert.strictEqual(state.question.kind, "number");
    assert.strictEqual(state.question.fallback, 1);
    assert.deepStrictEqual(state.question.choices, [{ number: 1, name: "amdvlk" }, { number: 2, name: "vulkan-radeon" }]);
    assert.strictEqual(state.question.text, "Choose what provides vulkan-driver");
});

test("a conflict question defaults to no", () => {
    const state = run(":: iptables-nft and iptables are in conflict. Remove iptables? [y/N] ");
    assert.strictEqual(state.question.text, "iptables-nft and iptables are in conflict. Remove iptables?");
    assert.strictEqual(state.question.yes, false);
});

test("nothing to do is up to date", () => {
    const state = run(":: Synchronizing package databases...\r\n core is up to date\r\n:: Starting full system upgrade...\r\n there is nothing to do\r\n");
    assert.strictEqual(Upgrade.outcome(state, 0), "current");
    assert.strictEqual(Upgrade.headline(state, "current"), "Already up to date");
});

test("failures are put in plain words", () => {
    const locked = run("error: failed to init transaction (unable to lock database)\r\nerror: could not lock database: File exists\r\n");
    assert.strictEqual(Upgrade.outcome(locked, 1), "failed");
    assert.match(Upgrade.explain(locked, 1), /Another package manager/);
    const offline = run("error: failed retrieving file 'core.db' from mirror : Could not resolve host: mirror\r\nerror: failed to synchronize all databases (failed to retrieve some files)\r\n");
    assert.match(Upgrade.explain(offline, 1), /package mirrors/);
    const refused = run("Error executing command as another user: Not authorized\r\n\r\nThis incident has been reported.\r\n");
    assert.strictEqual(Upgrade.outcome(refused, 127), "failed");
    assert.match(Upgrade.explain(refused, 127), /refused/);
    const dismissed = run("Error executing command as another user: Request dismissed\r\n");
    assert.strictEqual(Upgrade.outcome(dismissed, 126), "cancelled");
    assert.match(Upgrade.explain(dismissed, 126), /password prompt was closed/);
    const odd = run("error: something nobody planned for\r\n");
    assert.strictEqual(Upgrade.explain(odd, 1), "Something nobody planned for.");
});

test("the download line names progress, speed and time left", () => {
    const state = run(":: Retrieving packages...\r\n Total ( 3/87)   12.5 MiB  5.00 MiB/s 00:12 [######----]  45%\r");
    assert.strictEqual(state.download.done, 3);
    assert.strictEqual(state.download.fraction, 0.45);
    assert.strictEqual(Upgrade.describe(state), "Downloading 4 of 87 · 5.00 MiB/s · 0:12 left");
    assert.strictEqual(Upgrade.brief(state), "Downloading 4 of 87");
});

test("a line break split between \\r and \\n is still one break", () => {
    const text = "Packages (3) expat-2.9.0-1  feh-3.13.1-1\r\n              less-1:710-1\r\n\r\nTotal Download Size:  1.00 MiB\r\n";
    for (let cut = 1; cut < text.length; cut++) {
        const state = Upgrade.create();
        Upgrade.feed(state, text.slice(0, cut));
        Upgrade.feed(state, text.slice(cut));
        assert.deepStrictEqual(state.packages, ["expat", "feh", "less"], `cut at ${cut}`);
    }
});

test("answering no to a question that stops pacman is a cancel, not a failure", () => {
    const state = run(":: iptables-nft and iptables are in conflict. Remove iptables? [y/N] ");
    state.declined = true;
    Upgrade.feed(state, "n\r\nerror: unresolvable package conflicts detected\r\nerror: failed to prepare transaction (conflicting dependencies)\r\n");
    assert.strictEqual(Upgrade.outcome(state, 1), "cancelled");
    assert.match(Upgrade.explain(state, 1), /answered no/);
});

test("escape codes and stray control bytes are cleaned away", () => {
    assert.strictEqual(Upgrade.clean("\x1b[1;34m::\x1b[0;1m Proceed\x1b[0m\x1b[?25h\x07"), ":: Proceed");
});

test("a plain pacman full upgrade runs in the island, anything else keeps the terminal", () => {
    assert.deepStrictEqual(Upgrade.plan("sudo pacman -Syu"), { plain: true, noconfirm: false });
    assert.deepStrictEqual(Upgrade.plan("sudo pacman -Suy --noconfirm"), { plain: true, noconfirm: true });
    assert.deepStrictEqual(Upgrade.plan("doas /usr/bin/pacman --sync --refresh --sysupgrade"), { plain: true, noconfirm: false });
    assert.deepStrictEqual(Upgrade.plan("pacman -S -yy -u"), { plain: true, noconfirm: false });
    for (const other of ["paru -Syu", "yay", "sudo pacman -Sy", "sudo pacman -Syu --overwrite '*'", "sudo pacman -Syu; reboot", "", "sudo"])
        assert.strictEqual(Upgrade.plan(other).plain, false, other);
});

function replay(tool, name) {
    const text = fixture(name);
    const state = Upgrade.create(tool);
    const seen = [];
    let last = 0;
    for (let i = 0; i < text.length; i += 61) {
        Upgrade.feed(state, text.slice(i, i + 61));
        const now = Upgrade.fraction(state, false);
        assert.ok(now >= last - 1e-9, `${name} went back from ${last} to ${now} in ${state.phase}`);
        last = now;
        if (seen[seen.length - 1] !== state.phase)
            seen.push(state.phase);
    }
    return { state, seen };
}

test("a recorded apt upgrade asks once, downloads, then unpacks and sets up", () => {
    const log = fixture("apt-upgrade.log");
    const asked = run(log.slice(0, log.indexOf("[Y/n] ") + 6), 0, "apt");
    assert.strictEqual(asked.question.text, "Do you want to continue?");
    assert.ok(Upgrade.proceeds(asked.question));
    assert.ok(Upgrade.cancellable(asked));
    const { state, seen } = replay("apt", "apt-upgrade.log");
    assert.deepStrictEqual(seen, ["auth", "resolve", "download", "install"]);
    assert.deepStrictEqual(state.packages, ["tzdata"]);
    assert.strictEqual(state.total, 1);
    assert.strictEqual(state.sizes.download, "268 kB");
    assert.strictEqual(Upgrade.describe(state), "Setting up tzdata · 1 of 1");
    assert.strictEqual(Upgrade.cancellable(state), false);
    assert.strictEqual(Upgrade.outcome(state, 0), "done");
});

test("apt stopped during the download is a cancel, and nothing to upgrade is up to date", () => {
    const cancelled = run(fixture("apt-cancel.log"), 0, "apt");
    assert.strictEqual(cancelled.committing, false);
    assert.strictEqual(Upgrade.outcome(cancelled, 130), "cancelled");
    assert.match(Upgrade.explain(cancelled, 130), /Nothing changed/);
    const current = run(fixture("apt-nothing.log"), 0, "apt");
    assert.strictEqual(Upgrade.outcome(current, 0), "current");
});

test("a recorded dnf upgrade downloads, verifies, then counts the transaction", () => {
    const log = fixture("dnf-upgrade.log");
    assert.ok(Upgrade.proceeds(run(log.slice(0, log.indexOf("[y/N]: ") + 7), 0, "dnf").question));
    const { state, seen } = replay("dnf", "dnf-upgrade.log");
    assert.deepStrictEqual(seen, ["auth", "sync", "resolve", "download", "check", "install"]);
    assert.deepStrictEqual(state.packages, ["curl", "libcurl", "libsolv", "sqlite-libs", "tzdata"]);
    assert.strictEqual(state.total, 5);
    assert.strictEqual(state.sizes.download, "3 MiB");
    assert.strictEqual(Upgrade.describe(state), "Removing libsolv · 12 of 12");
    assert.strictEqual(Upgrade.outcome(state, 0), "done");
});

test("dnf mid-download reads as a count with speed and can still be stopped", () => {
    const text = fixture("dnf-upgrade.log");
    const state = run(text.slice(0, text.indexOf("[4/5] Total")), 0, "dnf");
    assert.strictEqual(state.phase, "download");
    assert.match(Upgrade.describe(state), /^Downloading 4 of 5 · [\d.]+ (B|KiB|MiB)\/s$/);
    assert.ok(Upgrade.cancellable(state));
});

test("dnf answered no is a cancel, and nothing to do is up to date", () => {
    const declined = run(fixture("dnf-declined.log"), 0, "dnf");
    declined.declined = true;
    assert.strictEqual(Upgrade.outcome(declined, 1), "cancelled");
    assert.strictEqual(Upgrade.explain(declined, 1), "You answered no, so dnf stopped before changing anything.");
    assert.strictEqual(Upgrade.outcome(run(fixture("dnf-nothing.log"), 0, "dnf"), 0), "current");
});

test("failures from apt and dnf are put in plain words naming the tool", () => {
    const words = (tool, text, code) => Upgrade.explain(run(text, 0, tool), code);
    assert.match(words("apt", "E: Could not get lock /var/lib/dpkg/lock-frontend. It is held by process 812 (apt-get)\r\n", 100), /Another package manager is busy/);
    assert.match(words("apt", "E: dpkg was interrupted, you must manually run 'dpkg --configure -a' to correct the problem.\r\n", 100), /dpkg --configure -a/);
    assert.match(words("apt", "E: Failed to fetch http://deb.debian.org/debian/pool/main/t/tzdata.deb  Temporary failure resolving 'deb.debian.org'\r\n", 100), /mirrors/);
    assert.match(words("dnf", "Error: GPG check FAILED\r\n", 1), /signature did not check out\. The log names/);
    assert.strictEqual(words("dnf", "", 3), "dnf stopped with code 3.");
});

test("the confirm question of every tool proceeds on its own, other questions wait", () => {
    for (const [tool, prompt, text] of [["pacman", ":: Proceed with installation? [Y/n] ", "Proceed with installation?"], ["apt", "Do you want to continue? [Y/n] ", "Do you want to continue?"], ["dnf", "Is this ok [y/N]: ", "Is this ok"], ["zypper", "Continue? [y/n/v/...? shows all options] (y): ", "Continue?"]]) {
        const state = run(prompt, 0, tool);
        assert.strictEqual(state.question?.text, text, tool);
        assert.ok(Upgrade.proceeds(state.question), tool);
    }
    const other = run(":: Replace iptables with extra/iptables-nft? [Y/n] ");
    assert.strictEqual(Upgrade.proceeds(other.question), false);
});

test("off Arch the stock pacman command means the system's own tool, anything else keeps the terminal", () => {
    assert.deepStrictEqual(Upgrade.plan("sudo pacman -Syu", "apt"), { plain: true, noconfirm: false });
    assert.deepStrictEqual(Upgrade.plan("", "dnf"), { plain: true, noconfirm: false });
    assert.strictEqual(Upgrade.plan("sudo apt upgrade && flatpak update", "apt").plain, false);
});

test.describe("the runner", () => {
    const RUNNER = path.join(ROOT, "scripts/system-upgrade.sh");

    function system(tools, release) {
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), "system-upgrade-"));
        const bin = path.join(dir, "bin");
        fs.mkdirSync(bin);
        for (const tool of ["grep", "head"])
            fs.symlinkSync(spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim(), path.join(bin, tool));
        for (const tool of tools) {
            fs.writeFileSync(path.join(bin, tool), "#!/bin/sh\nexit 0\n");
            fs.chmodSync(path.join(bin, tool), 0o755);
        }
        fs.writeFileSync(path.join(dir, "os-release"), release ?? "ID=debian\n");
        return { dir, bin };
    }

    function command(tools, args, release) {
        const { dir, bin } = system(tools, release);
        const out = spawnSync(process.env.BASH ?? "/bin/bash", [RUNNER, "command", path.join(dir, "run"), ...args], { encoding: "utf8", env: { PATH: bin, BANDITSHELL_OS_RELEASE: path.join(dir, "os-release") } });
        fs.rmSync(dir, { recursive: true, force: true });
        return { code: out.status, text: out.stdout.replaceAll(bin, "BIN") };
    }

    test.it("builds each tool's full upgrade under pkexec", () => {
        assert.deepStrictEqual(command(["pkexec", "pacman"], []), { code: 0, text: "pacman\npkexec BIN/pacman -Syu --color always\n" });
        assert.deepStrictEqual(command(["pkexec", "pacman"], ["--noconfirm"]), { code: 0, text: "pacman\npkexec BIN/pacman -Syu --color always --noconfirm\n" });
        assert.deepStrictEqual(command(["pkexec", "apt-get"], []), { code: 0, text: "apt\npkexec /bin/sh -c 'BIN/apt-get update && exec env DEBIAN_FRONTEND=noninteractive BIN/apt-get -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold full-upgrade'\n" });
        assert.deepStrictEqual(command(["pkexec", "dnf"], ["--noconfirm"]), { code: 0, text: "dnf\npkexec BIN/dnf upgrade --refresh -y\n" });
        assert.deepStrictEqual(command(["pkexec", "zypper"], [], 'ID="opensuse-tumbleweed"\n'), { code: 0, text: "zypper\npkexec BIN/zypper dist-upgrade --download-in-advance\n" });
        assert.deepStrictEqual(command(["pkexec", "zypper"], [], 'ID="opensuse-leap"\n'), { code: 0, text: "zypper\npkexec BIN/zypper update --download-in-advance\n" });
    });

    test.it("hands back to the terminal where it has no pkexec or knows no tool", () => {
        assert.strictEqual(command(["pacman"], []).code, 4);
        assert.strictEqual(command(["pkexec", "xbps-install"], []).code, 4);
        assert.strictEqual(command(["pkexec", "apk"], []).code, 4);
    });

    function cancel(log) {
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), "system-upgrade-"));
        const sleeper = spawn("sleep", ["30"]);
        const stat = fs.readFileSync(`/proc/${sleeper.pid}/stat`, "utf8");
        fs.writeFileSync(path.join(dir, "pid"), `${sleeper.pid} ${stat.slice(stat.lastIndexOf(") ") + 2).split(" ")[19]}\n`);
        fs.writeFileSync(path.join(dir, "log"), log, "latin1");
        fs.writeFileSync(path.join(dir, "input"), "");
        const out = spawnSync(process.env.BASH ?? "/bin/bash", [RUNNER, "cancel", dir], { encoding: "utf8" });
        const sent = fs.readFileSync(path.join(dir, "input"), "latin1");
        sleeper.kill();
        fs.rmSync(dir, { recursive: true, force: true });
        return { code: out.status, sent };
    }

    test.it("stops a download with Ctrl-C and refuses once any tool starts changing packages", () => {
        for (const [name, before, start] of [["apt-upgrade.log", "Fetched", "Preconfiguring packages"], ["dnf-upgrade.log", "[5/5] Total", "Running transaction"], ["upgrade.log", "Retrieving packages", "checking keys in keyring"]]) {
            const log = fixture(name);
            assert.deepStrictEqual(cancel(log.slice(0, log.indexOf(before))), { code: 0, sent: "\x03" }, `${name} before ${before}`);
            assert.deepStrictEqual(cancel(log.slice(0, log.indexOf(start) + start.length + 2)), { code: 5, sent: "" }, `${name} from ${start}`);
        }
    });
});
