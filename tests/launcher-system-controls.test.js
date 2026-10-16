const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync, spawn } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Asks = lib("modules/launcher/system-asks.js", ["brightnessAsk", "brightnessNear", "wifiAsk", "vpnAsk", "tailscaleAsk", "vpnNear", "recordAsk", "recordNear", "stopNear"]);
const Brightness = lib("services/brightness.js", ["parseBacklights", "clamp", "stepped", "rawLevel", "percentText"]);
const Ddcutil = lib("services/ddcutil.js", ["parseVcp"]);
const Tailscale = lib("services/tailscale.js", ["parseStatus", "stateText", "explain", "authUrlIn", "exitNodeCommand", "operatorCommand", "matches"]);
const Recording = lib("services/recording.js", ["fileName", "folderFor", "pickBackend", "geometryParts", "evenGeometry", "recorderCommand", "windowBoxes", "windowBox", "splitDocuments", "parseState", "parseResult", "modeLabel"]);

test.describe("brightness asks", () => {
    test.it("reads a list, a level and a step", () => {
        assert.deepStrictEqual(Asks.brightnessAsk("brightness"), { kind: "list" });
        assert.deepStrictEqual(Asks.brightnessAsk("Screen Brightness"), { kind: "list" });
        assert.deepStrictEqual(Asks.brightnessAsk("brightness 40"), { kind: "set", level: 40 });
        assert.deepStrictEqual(Asks.brightnessAsk("set brightness to 75%"), { kind: "set", level: 75 });
        assert.deepStrictEqual(Asks.brightnessAsk("brighter"), { kind: "step", direction: 1 });
        assert.deepStrictEqual(Asks.brightnessAsk("dimmer"), { kind: "step", direction: -1 });
        assert.deepStrictEqual(Asks.brightnessAsk("brightness down"), { kind: "step", direction: -1 });
    });

    test.it("ignores levels above 100 and unrelated words", () => {
        assert.strictEqual(Asks.brightnessAsk("brightness 140"), null);
        assert.strictEqual(Asks.brightnessAsk("bright eyes"), null);
        assert.strictEqual(Asks.brightnessAsk("dim"), null);
    });

    test.it("treats a partial word as ambient only from four letters", () => {
        assert.strictEqual(Asks.brightnessNear("bri"), false);
        assert.strictEqual(Asks.brightnessNear("brig"), true);
        assert.strictEqual(Asks.brightnessNear("brightness"), false);
        assert.strictEqual(Asks.brightnessNear("firefox"), false);
    });
});

test.describe("brightness levels", () => {
    test.it("reads brightnessctl machine output and keeps only backlights", () => {
        const text = "intel_backlight,backlight,12000,50%,24000\ninput9::capslock,leds,0,0%,1\nbad name,backlight,1,1%,2\n";
        assert.deepStrictEqual(Brightness.parseBacklights(text), [{ name: "intel_backlight", current: 12000, max: 24000 }]);
        assert.deepStrictEqual(Brightness.parseBacklights("Failed to read any devices of class 'backlight'."), []);
    });

    test.it("never goes below the floor so a typo cannot black out a screen", () => {
        assert.strictEqual(Brightness.clamp(0, 5), 0.05);
        assert.strictEqual(Brightness.clamp(-1, 5), 0.05);
        assert.strictEqual(Brightness.clamp(0.4, 5), 0.4);
        assert.strictEqual(Brightness.clamp(2, 5), 1);
        assert.strictEqual(Brightness.clamp(0, 0), 0.01);
        assert.strictEqual(Brightness.clamp(0.02, "junk"), 0.05);
    });

    test.it("steps to the next tenth either way", () => {
        assert.strictEqual(Brightness.stepped(0.43, 1, 5), 0.5);
        assert.strictEqual(Brightness.stepped(0.43, -1, 5), 0.4);
        assert.strictEqual(Brightness.stepped(0.5, 1, 5), 0.6);
        assert.strictEqual(Brightness.stepped(0.5, -1, 5), 0.4);
        assert.strictEqual(Brightness.stepped(0.1, -1, 5), 0.05);
        assert.strictEqual(Brightness.stepped(0.95, 1, 5), 1);
    });

    test.it("turns a fraction into a raw level of at least one", () => {
        assert.strictEqual(Brightness.rawLevel(0.5, 24000), 12000);
        assert.strictEqual(Brightness.rawLevel(0.001, 7), 1);
        assert.strictEqual(Brightness.percentText(0.456), "46%");
        assert.strictEqual(Brightness.percentText(-1), "");
    });

    test.it("reads a ddcutil brightness answer", () => {
        assert.deepStrictEqual(Ddcutil.parseVcp("VCP 10 C 50 100\n"), { current: 50, max: 100 });
        assert.strictEqual(Ddcutil.parseVcp("Display not found"), null);
        assert.strictEqual(Ddcutil.parseVcp("VCP 10 C 5 0"), null);
    });
});

test.describe("wifi asks", () => {
    test.it("lists, filters and joins", () => {
        assert.deepStrictEqual(Asks.wifiAsk("wifi"), { name: "" });
        assert.deepStrictEqual(Asks.wifiAsk("Wi-Fi networks"), { name: "" });
        assert.deepStrictEqual(Asks.wifiAsk("wifi cafe"), { name: "cafe" });
        assert.deepStrictEqual(Asks.wifiAsk("join Cafe Guest"), { name: "cafe guest", join: true });
        assert.deepStrictEqual(Asks.wifiAsk("wifi off"), { name: "", power: false });
        assert.deepStrictEqual(Asks.wifiAsk("wifi on"), { name: "", power: true });
        assert.strictEqual(Asks.wifiAsk("wifey"), null);
    });
});

test.describe("vpn and tailscale asks", () => {
    test.it("reads vpn with an optional name", () => {
        assert.deepStrictEqual(Asks.vpnAsk("vpn"), { name: "" });
        assert.deepStrictEqual(Asks.vpnAsk("vpn work"), { name: "work" });
        assert.deepStrictEqual(Asks.vpnAsk("wireguard"), { name: "" });
        assert.strictEqual(Asks.vpnAsk("vpnx"), null);
    });

    test.it("reads tailscale status, up, down and exit nodes", () => {
        assert.deepStrictEqual(Asks.tailscaleAsk("tailscale"), { kind: "status", name: "" });
        assert.deepStrictEqual(Asks.tailscaleAsk("tailscale up"), { kind: "up", name: "" });
        assert.deepStrictEqual(Asks.tailscaleAsk("tailscale off"), { kind: "down", name: "" });
        assert.deepStrictEqual(Asks.tailscaleAsk("tailscale exit node"), { kind: "exit", name: "" });
        assert.deepStrictEqual(Asks.tailscaleAsk("exit nodes"), { kind: "exit", name: "" });
        assert.deepStrictEqual(Asks.tailscaleAsk("exit node pi"), { kind: "exit", name: "pi" });
        assert.deepStrictEqual(Asks.tailscaleAsk("tailscale nemu"), { kind: "status", name: "nemu" });
        assert.strictEqual(Asks.tailscaleAsk("tail"), null);
        assert.strictEqual(Asks.vpnNear("tails"), true);
    });
});

test.describe("record asks", () => {
    test.it("reads the three modes, sound and stop", () => {
        assert.deepStrictEqual(Asks.recordAsk("record"), { stop: false, mode: "", sound: false });
        assert.deepStrictEqual(Asks.recordAsk("record screen"), { stop: false, mode: "screen", sound: false });
        assert.deepStrictEqual(Asks.recordAsk("record area"), { stop: false, mode: "area", sound: false });
        assert.deepStrictEqual(Asks.recordAsk("record a window"), { stop: false, mode: "window", sound: false });
        assert.deepStrictEqual(Asks.recordAsk("record screen with sound"), { stop: false, mode: "screen", sound: true });
        assert.deepStrictEqual(Asks.recordAsk("screen recording"), { stop: false, mode: "", sound: false });
        assert.deepStrictEqual(Asks.recordAsk("stop recording"), { stop: true, mode: "", sound: false });
    });

    test.it("never reads sound into a plain ask", () => {
        for (const text of ["record", "record screen", "record area", "record window"])
            assert.strictEqual(Asks.recordAsk(text).sound, false);
    });

    test.it("keeps short and unrelated words out", () => {
        assert.strictEqual(Asks.recordAsk("rec"), null);
        assert.strictEqual(Asks.recordAsk("records"), null);
        assert.strictEqual(Asks.recordNear("reco"), true);
        assert.strictEqual(Asks.recordNear("rec"), false);
        assert.strictEqual(Asks.stopNear("stop"), true);
        assert.strictEqual(Asks.stopNear("stop rec"), true);
        assert.strictEqual(Asks.stopNear("firefox"), false);
        assert.strictEqual(Asks.stopNear("sto"), false);
    });
});

const STATUS = JSON.stringify({
    BackendState: "Running",
    AuthURL: "",
    CurrentTailnet: { Name: "someone@example.com" },
    Self: { ID: "self", HostName: "desk", DNSName: "desk.tail.ts.net.", TailscaleIPs: ["100.1.1.1"], OS: "linux", Online: true },
    Peer: {
        a: { ID: "n1", HostName: "Phone Thing", DNSName: "phone.tail.ts.net.", TailscaleIPs: ["100.2.2.2", "fd7a::1"], OS: "android", Online: false },
        b: { ID: "n2", HostName: "pi", DNSName: "pi.tail.ts.net.", TailscaleIPs: ["100.3.3.3"], OS: "linux", Online: true, ExitNodeOption: true },
        c: { ID: "n3", HostName: "box", DNSName: "box.tail.ts.net.", TailscaleIPs: ["100.4.4.4"], OS: "linux", Online: true, ExitNodeOption: true, ExitNode: true }
    }
});

test.describe("tailscale status", () => {
    test.it("reads peers with the active exit node first, then online ones", () => {
        const status = Tailscale.parseStatus(STATUS);
        assert.strictEqual(status.running, true);
        assert.strictEqual(status.tailnet, "someone@example.com");
        assert.strictEqual(status.exitNode, "n3");
        assert.deepStrictEqual(status.peers.map(p => p.name), ["box", "pi", "phone"]);
        assert.strictEqual(status.peers[2].address, "100.2.2.2");
        assert.strictEqual(status.peers[2].dns, "phone.tail.ts.net");
        assert.strictEqual(status.self.address, "100.1.1.1");
        assert.strictEqual(Tailscale.parseStatus("not json"), null);
    });

    test.it("explains operator trouble so the row can offer pkexec", () => {
        const denied = Tailscale.explain("Error: changing settings via 'tailscale up' requires... Access denied: checkprefs access denied\nUse 'sudo tailscale up' or 'tailscale up --operator=$USER'");
        assert.strictEqual(denied.operator, true);
        assert.strictEqual(Tailscale.explain("failed to connect to local tailscaled; it doesn't appear to be running").text, "tailscaled is not running");
        assert.strictEqual(Tailscale.stateText("NeedsLogin"), "signed out");
    });

    test.it("finds the sign in link", () => {
        assert.strictEqual(Tailscale.authUrlIn("To authenticate, visit:\n\n\thttps://login.tailscale.com/a/abc123\n"), "https://login.tailscale.com/a/abc123");
        assert.strictEqual(Tailscale.authUrlIn("https://example.com/a/abc"), "");
    });

    test.it("builds fixed commands and refuses anything else", () => {
        assert.deepStrictEqual(Tailscale.exitNodeCommand("100.3.3.3"), ["tailscale", "set", "--exit-node=100.3.3.3"]);
        assert.deepStrictEqual(Tailscale.exitNodeCommand(""), ["tailscale", "set", "--exit-node="]);
        assert.deepStrictEqual(Tailscale.exitNodeCommand("1.2.3.4; rm -rf ~"), []);
        assert.deepStrictEqual(Tailscale.operatorCommand("/usr/bin/tailscale", "bandit"), ["pkexec", "/usr/bin/tailscale", "set", "--operator=bandit"]);
        assert.deepStrictEqual(Tailscale.operatorCommand("/usr/bin/tailscale", "a b"), []);
        assert.deepStrictEqual(Tailscale.operatorCommand("tailscale", "bandit"), []);
        assert.deepStrictEqual(Tailscale.operatorCommand("/home/u/.local/bin/tailscale", "bandit"), []);
        assert.deepStrictEqual(Tailscale.operatorCommand("/usr/sbin/tailscale", "bandit"), ["pkexec", "/usr/sbin/tailscale", "set", "--operator=bandit"]);
    });

    test.it("matches peers by name, host or address", () => {
        const peer = Tailscale.parseStatus(STATUS).peers[2];
        assert.strictEqual(Tailscale.matches(peer, "pho"), true);
        assert.strictEqual(Tailscale.matches(peer, "thing"), true);
        assert.strictEqual(Tailscale.matches(peer, "100.2"), true);
        assert.strictEqual(Tailscale.matches(peer, "pi"), false);
    });
});

test.describe("recording", () => {
    test.it("names files by the time and finds the folder", () => {
        assert.strictEqual(Recording.fileName(new Date(2026, 9, 16, 9, 5, 7)), "Recording 2026-10-16 09.05.07.mp4");
        assert.strictEqual(Recording.folderFor("", "/home/u/Videos", "/home/u"), "/home/u/Videos/Recordings");
        assert.strictEqual(Recording.folderFor("", "", "/home/u"), "/home/u/Videos/Recordings");
        assert.strictEqual(Recording.folderFor("~/Clips/", "/x", "/home/u"), "/home/u/Clips/");
        assert.strictEqual(Recording.folderFor("/data/rec/", "/x", "/home/u"), "/data/rec");
        assert.strictEqual(Recording.folderFor("Clips/new", "/x", "/home/u"), "/home/u/Clips/new");
    });

    test.it("prefers wf-recorder, then wl-screenrec, then gpu-screen-recorder", () => {
        assert.strictEqual(Recording.pickBackend(["slurp", "gpu-screen-recorder", "wl-screenrec"]), "wl-screenrec");
        assert.strictEqual(Recording.pickBackend(["wf-recorder", "wl-screenrec"]), "wf-recorder");
        assert.strictEqual(Recording.pickBackend(["slurp"]), "");
    });

    test.it("builds recorder commands without sound unless asked", () => {
        const file = "/home/u/Videos/Recordings/Recording.mp4";
        assert.deepStrictEqual(Recording.recorderCommand("wf-recorder", file, { output: "DP-1" }, false), ["wf-recorder", "-y", "-f", file, "-o", "DP-1"]);
        assert.deepStrictEqual(Recording.recorderCommand("wf-recorder", file, { geometry: "10,20 301x201" }, true), ["wf-recorder", "-y", "-f", file, "-g", "10,20 300x200", "--audio=@DEFAULT_MONITOR@"]);
        assert.deepStrictEqual(Recording.recorderCommand("wl-screenrec", file, { output: "HDMI-A-1" }, false), ["wl-screenrec", "-f", file, "-o", "HDMI-A-1"]);
        assert.deepStrictEqual(Recording.recorderCommand("gpu-screen-recorder", file, { geometry: "0,0 800x600" }, false), ["gpu-screen-recorder", "-w", "region", "-region", "800x600+0+0", "-f", "60", "-c", "mp4", "-o", file]);
        for (const backend of ["wf-recorder", "wl-screenrec", "gpu-screen-recorder"]) {
            const quiet = Recording.recorderCommand(backend, file, { output: "DP-1" }, false).join(" ");
            assert.ok(!/audio| -a /.test(quiet), `${backend} records sound unasked`);
        }
        assert.deepStrictEqual(Recording.recorderCommand("wf-recorder", file, { output: "DP-1; rm" }, false), []);
        assert.deepStrictEqual(Recording.recorderCommand("wf-recorder", file, { geometry: "nonsense" }, false), []);
        assert.deepStrictEqual(Recording.recorderCommand("other", file, { output: "DP-1" }, false), []);
    });

    test.it("offers only windows on visible workspaces to the picker", () => {
        const clients = [
            { address: "0xa", at: [0, 0], size: [800, 600], workspace: { id: 1 }, focusHistoryID: 2 },
            { address: "0xb", at: [800, 0], size: [400, 600], workspace: { id: 1 }, focusHistoryID: 0 },
            { address: "0xc", at: [0, 0], size: [100, 100], workspace: { id: 3 }, focusHistoryID: 1 },
            { address: "0xd", at: [5, 5], size: [100, 100], workspace: { id: 1 }, hidden: true },
            { address: "0xe", at: [5, 5], size: [100, 100], workspace: { id: -98 }, focusHistoryID: 4 }
        ];
        const monitors = [{ activeWorkspace: { id: 1 }, specialWorkspace: { id: -98 } }, { activeWorkspace: { id: 2 }, specialWorkspace: { id: 0 } }];
        assert.deepStrictEqual(Recording.windowBoxes(clients, monitors), ["800,0 400x600", "0,0 800x600", "5,5 100x100"]);
        assert.strictEqual(Recording.windowBox(clients, "a"), "0,0 800x600");
        assert.strictEqual(Recording.windowBox(clients, "0xc"), "0,0 100x100");
        assert.strictEqual(Recording.windowBox(clients, ""), "");
    });

    test.it("reads hyprctl output joined by a record separator", () => {
        const parts = Recording.splitDocuments('[{"a":1}]\u001e[{"b":2}]');
        assert.deepStrictEqual(parts, [[{ a: 1 }], [{ b: 2 }]]);
    });

    test.it("reads the state and result files the script writes", () => {
        assert.deepStrictEqual(Recording.parseState("4242\n1760600000000\n/home/u/Videos/Recordings/a.mp4\narea\nquiet\n"), {
            pid: 4242,
            started: 1760600000000,
            file: "/home/u/Videos/Recordings/a.mp4",
            mode: "area",
            sound: false
        });
        assert.strictEqual(Recording.parseState(""), null);
        assert.strictEqual(Recording.parseState("1\n5\n/a"), null);
        assert.deepStrictEqual(Recording.parseResult("0\n/a.mp4\n2048\nframes: 10\n"), { status: 0, file: "/a.mp4", size: 2048, complaint: "frames: 10" });
        assert.strictEqual(Recording.modeLabel("window"), "a window");
    });
});

test.describe("screen-record.sh", () => {
    const script = path.join(ROOT, "scripts/screen-record.sh");
    const made = [];

    test.after(() => {
        for (const dir of made)
            fs.rmSync(dir, { recursive: true, force: true });
    });

    function sandbox() {
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), "screen-record-"));
        made.push(dir);
        const bin = path.join(dir, "bin");
        fs.mkdirSync(bin);
        fs.writeFileSync(path.join(bin, "wf-recorder"), "#!/bin/sh\nfile=\"$3\"\ntrap 'printf done >\"$file\"; exit 0' INT\nprintf started >&2\nwhile :; do sleep 0.05; done\n", { mode: 0o755 });
        return { dir: dir, bin: bin, state: path.join(dir, "run") };
    }

    function waitFor(check, ms) {
        const until = Date.now() + ms;
        while (Date.now() < until) {
            if (check())
                return true;
            spawnSync("sleep", ["0.05"]);
        }
        return false;
    }

    test.it("refuses recorders it does not know", () => {
        const box = sandbox();
        const run = spawnSync(script, ["start", box.state, `${box.dir}/a.mp4`, "screen", "quiet", "sh", "-c", "true"]);
        assert.strictEqual(run.status, 2);
        assert.ok(!fs.existsSync(path.join(box.state, "recording")));
    });

    test.it("records until stopped, then leaves a result and removes its state", () => {
        const box = sandbox();
        const file = path.join(box.dir, "Videos", "Recordings", "Recording test.mp4");
        const env = Object.assign({}, process.env, { PATH: `${box.bin}:${process.env.PATH}` });
        const child = spawn(script, ["start", box.state, file, "area", "quiet", "wf-recorder", "-y", "-f", file, "-g", "0,0 10x10"], { env: env, stdio: "ignore" });
        const state = path.join(box.state, "recording");
        assert.ok(waitFor(() => fs.existsSync(state), 3000), "no state file appeared");
        const lines = fs.readFileSync(state, "utf8").split("\n");
        assert.strictEqual(lines[2], file);
        assert.strictEqual(lines[3], "area");
        assert.strictEqual(fs.statSync(state).mode & 0o777, 0o600);
        assert.strictEqual(fs.statSync(box.state).mode & 0o777, 0o700);
        const stop = spawnSync(script, ["stop", box.state]);
        assert.strictEqual(stop.status, 0);
        assert.ok(waitFor(() => !fs.existsSync(state), 3000), "state file stayed");
        const result = fs.readFileSync(path.join(box.state, "result"), "utf8").split("\n");
        assert.strictEqual(result[0], "0");
        assert.strictEqual(result[1], file);
        assert.strictEqual(fs.readFileSync(file, "utf8"), "done");
        child.kill();
    });
});
