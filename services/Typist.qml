pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property bool found: false
    property bool notifies: false
    property bool probed: false
    property string installing: ""

    readonly property var packages: ["pacman:wtype", "apt:wtype", "dnf:wtype", "zypper:wtype", "xbps:wtype", "apk:wtype"]
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`

    readonly property int patience: 1500
    readonly property int grace: 400
    readonly property int settle: 50
    readonly property int least: 90

    property var job: null

    readonly property var offKeymap: /[^\x20-\x7e\n\t]/

    property var restoring: null

    function probe(): void {
        if (!prober.running)
            prober.running = true;
    }

    function type(text: string, back: int, address: string): void {
        const job = {
            kind: "text",
            text: text,
            back: Math.max(0, back),
            address: Hypr.windowAddress(address),
            way: root.offKeymap.test(text) ? "" : "keys"
        };
        root.start(job);
        if (root.job === job && !job.way)
            root.askWay(job);
    }

    function askWay(job: var): void {
        const pid = Hypr.toplevelFor(job.address)?.lastIpcObject?.pid ?? 0;
        if (!pid) {
            job.way = "keys";
            return;
        }
        wayProbe.job = job;
        wayProbe.command = ["sh", "-c", 'd=$(dirname "$(readlink "/proc/$1/exe")") && { [ -e "$d/v8_context_snapshot.bin" ] || [ -e "$d/snapshot_blob.bin" ]; }', "sh", String(pid)];
        wayProbe.running = true;
    }

    function paste(address: string): void {
        const target = Hypr.windowAddress(address);
        root.start({
            kind: "paste",
            terminal: root.isTerminal(target),
            address: target
        });
    }

    function isTerminal(address: string): bool {
        const state = Hypr.toplevelFor(address)?.lastIpcObject ?? {};
        const name = state.class || state.initialClass || "";
        return !!name && (DesktopEntries.heuristicLookup(name)?.categories ?? []).includes("TerminalEmulator");
    }

    function start(job: var): void {
        if (!root.found) {
            root.giveUp(job, root.probed ? "wtype is not installed, so it was copied instead." : "Typing is not ready yet, so it was copied instead.");
            return;
        }
        if (!job.address) {
            root.giveUp(job, "No window was in front to type into.");
            return;
        }
        if (root.job)
            root.giveUp(root.job, "Something else was typed first.");
        job.at = Date.now();
        job.calm = 0;
        root.job = job;
        watch.restart();
    }

    function tick(): void {
        const job = root.job;
        if (!job) {
            watch.stop();
            return;
        }
        const now = Date.now();
        const focused = Hypr.focusedAddress === job.address || Hypr.windowAddress(Hyprland.activeToplevel?.address) === job.address;
        const released = Qt.application.state !== Qt.ApplicationActive || now - job.at >= root.grace;
        if (job.kind === "text" && !job.way && now - job.at >= root.patience / 2)
            job.way = "keys";
        if (focused && released && (job.kind !== "text" || job.way)) {
            if (!job.calm)
                job.calm = now;
            if (now - job.calm >= root.settle && now - job.at >= root.least) {
                watch.stop();
                root.job = null;
                root.fire(job);
            }
            return;
        }
        job.calm = 0;
        if (now - job.at >= root.patience) {
            watch.stop();
            root.job = null;
            root.giveUp(job, "The window did not come back into focus in time.");
        }
    }

    function fire(job: var): void {
        if (job.kind === "paste") {
            Keystrokes.send(job.terminal ? ["wtype", "-M", "ctrl", "-M", "shift", "-k", "v", "-m", "shift", "-m", "ctrl"] : ["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"]);
            return;
        }
        if (job.way === "paste") {
            root.pasteText(job);
            return;
        }
        Keystrokes.send(["wtype", "--", job.text]);
        root.stepBack(job.back);
    }

    function stepBack(back: int): void {
        if (back <= 0)
            return;
        const keys = ["wtype"];
        for (let i = 0; i < back; i++)
            keys.push("-k", "Left");
        Keystrokes.send(keys);
    }

    function pasteText(job: var): void {
        const before = Clipboard.entries.find(e => e.id === Clipboard.current) ?? null;
        Clipboard.copy({
            text: job.text
        });
        pasteLater.job = Object.assign({}, job, {
            terminal: root.isTerminal(job.address)
        });
        root.restoring = before && before.text !== job.text ? {
            entry: before,
            text: job.text
        } : null;
        pasteLater.restart();
    }

    function giveUp(job: var, why: string): void {
        if (job.kind === "text" && job.text)
            Clipboard.copy({
                text: job.text
            });
        if (!root.notifies)
            return;
        const summary = job.kind === "paste" ? "On the clipboard" : "Copied instead of typed";
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "content_paste", summary, job.kind === "paste" ? `${why} Paste it with Ctrl+V.` : why]);
    }

    function install(): void {
        if (root.installing === "trying" || root.found)
            return;
        root.installing = "trying";
        quietInstall.running = true;
    }

    Timer {
        id: pasteLater

        property var job: null

        interval: 120
        onTriggered: {
            const job = pasteLater.job;
            pasteLater.job = null;
            if (!job)
                return;
            root.fire({
                kind: "paste",
                terminal: job.terminal
            });
            root.stepBack(job.back);
            if (root.restoring)
                restoreLater.restart();
        }
    }

    Timer {
        id: restoreLater

        interval: 1500
        onTriggered: {
            const was = root.restoring;
            root.restoring = null;
            if (was && Clipboard.entries.find(e => e.id === Clipboard.current)?.text === was.text)
                Clipboard.copy(was.entry);
        }
    }

    Process {
        id: wayProbe

        property var job: null

        onExited: code => {
            if (root.job === wayProbe.job && !wayProbe.job.way)
                wayProbe.job.way = code === 0 ? "paste" : "keys";
            wayProbe.job = null;
        }
    }

    Timer {
        id: watch

        interval: 16
        repeat: true
        onTriggered: root.tick()
    }

    Process {
        id: prober

        command: ["sh", "-c", "command -v wtype >/dev/null && echo wtype; command -v notify-send >/dev/null && echo notify-send; true"]
        running: true

        stdout: StdioCollector {
            onStreamFinished: {
                const tools = text.split("\n");
                root.found = tools.includes("wtype");
                root.notifies = tools.includes("notify-send");
                root.probed = true;
                if (root.found)
                    root.installing = "";
            }
        }
    }

    Process {
        id: quietInstall

        command: [root.installer, "--quiet", ...root.packages]
        onExited: code => {
            if (code === 0) {
                root.probe();
                return;
            }
            if (code === 3) {
                root.installing = "nowhere";
                return;
            }
            Polkit.expect("Install wtype", "");
            askingInstall.running = true;
        }
    }

    Process {
        id: askingInstall

        command: [root.installer, "--polkit", ...root.packages]
        onExited: code => {
            Polkit.forget();
            if (code === 0) {
                root.probe();
                return;
            }
            root.installing = code === 126 ? "" : "failed";
        }
    }
}
