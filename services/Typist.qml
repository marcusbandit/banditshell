pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property bool found: false
    property bool probed: false
    property string installing: ""

    readonly property var packages: ["pacman:wtype", "apt:wtype", "dnf:wtype", "zypper:wtype", "xbps:wtype", "apk:wtype"]
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`

    readonly property int patience: 1500
    readonly property int grace: 400
    readonly property int settle: 50
    readonly property int least: 90

    property var job: null
    property var queued: []

    function probe(): void {
        if (!prober.running)
            prober.running = true;
    }

    function type(text: string, back: int, address: string): void {
        root.start({
            kind: "text",
            text: text,
            back: Math.max(0, back),
            address: Hypr.windowAddress(address)
        });
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
        if (focused && released) {
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
        if (writer.running) {
            root.queued = root.queued.concat([job]);
            return;
        }
        if (job.kind === "paste") {
            writer.command = job.terminal ? ["wtype", "-M", "ctrl", "-M", "shift", "-k", "v", "-m", "shift", "-m", "ctrl"] : ["wtype", "-M", "ctrl", "-k", "v", "-m", "ctrl"];
            writer.stdinEnabled = false;
            writer.running = true;
            return;
        }
        const keys = [];
        for (let i = 0; i < job.back; i++)
            keys.push("-k", "Left");
        writer.command = ["wtype", "-"].concat(keys);
        writer.stdinEnabled = true;
        writer.running = true;
        writer.write(job.text);
        writer.stdinEnabled = false;
    }

    function giveUp(job: var, why: string): void {
        if (job.kind === "text" && job.text)
            Clipboard.copy({
                text: job.text
            });
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
        id: watch

        interval: 16
        repeat: true
        onTriggered: root.tick()
    }

    Process {
        id: writer

        environment: ({
                LC_CTYPE: "C.UTF-8"
            })

        stderr: SplitParser {
            onRead: line => console.warn("wtype:", line)
        }

        onRunningChanged: if (!running && root.queued.length) {
            const next = root.queued[0];
            root.queued = root.queued.slice(1);
            Qt.callLater(() => root.fire(next));
        }
    }

    Process {
        id: prober

        command: ["sh", "-c", "command -v wtype"]
        running: true
        onExited: code => {
            root.found = code === 0;
            root.probed = true;
            if (root.found)
                root.installing = "";
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
