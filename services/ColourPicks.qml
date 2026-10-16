pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "colour-picks.js" as Picks
import "projects.js" as Shells

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/colours.json`
    readonly property int limit: Math.max(1, Config.values.launcher.powerTools.colourHistory)

    property var history: []
    property bool loaded: false

    property bool found: false
    property bool probed: false
    property string installing: ""
    property string screen: ""

    readonly property var packages: ["pacman:hyprpicker", "apt:hyprpicker", "dnf:hyprpicker", "zypper:hyprpicker", "xbps:hyprpicker", "apk:hyprpicker"]
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`

    function probe(): void {
        if (!prober.running)
            prober.running = true;
    }

    Process {
        id: prober

        running: true
        command: ["sh", "-c", "command -v hyprpicker"]
        onExited: code => {
            root.found = code === 0;
            root.probed = true;
            if (root.found)
                root.installing = "";
        }
    }

    function pick(screenName: string): void {
        if (!root.found || picker.running)
            return;
        root.screen = screenName;
        delay.restart();
    }

    Timer {
        id: delay

        interval: 280
        onTriggered: picker.running = true
    }

    Process {
        id: picker

        property string out: ""

        command: ["hyprpicker", "--format=hex", "--no-fancy"]
        stdout: StdioCollector {
            onStreamFinished: picker.out = text
        }
        onExited: code => {
            const hex = Picks.readPicked(picker.out);
            picker.out = "";
            if (code === 0 && hex)
                root.picked(hex);
        }
    }

    function picked(hex: string): void {
        root.keep(Picks.remember(root.history, hex, Date.now(), root.limit));
        Clipboard.copy({
            text: hex
        });
        const launcher = Shell.forScreen(root.screen)?.launcher ?? null;
        if (!launcher)
            return;
        launcher.show();
        const input = launcher.concept?.input ?? null;
        if (input) {
            input.text = hex;
            input.cursorPosition = hex.length;
        }
    }

    function remove(hex: string): void {
        root.keep(Picks.forget(root.history, hex));
    }

    function keep(next: var): void {
        root.history = next;
        if (root.loaded)
            store.setText(JSON.stringify({
                picks: next
            }, null, 4) + "\n");
    }

    FileView {
        id: store

        path: root.path
        printErrors: false
        onLoaded: {
            root.history = Picks.readHistory(store.text(), root.limit);
            root.loaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.loaded = true;
        }
    }

    function install(): void {
        if (root.installing === "trying" || root.found)
            return;
        root.installing = "trying";
        quietInstall.running = true;
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
            Polkit.expect("Install hyprpicker", "");
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
            if (code === 126) {
                root.installing = "";
                return;
            }
            if (code !== 4 && code !== 127) {
                root.installing = "failed";
                return;
            }
            root.installing = "terminal";
            Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `${Shells.quote(root.installer)} --ask ${root.packages.map(Shells.quote).join(" ")}`]);
            watch.restart();
        }
    }

    Timer {
        id: watch

        interval: 3000
        repeat: true
        onTriggered: {
            if (root.found || root.installing !== "terminal")
                watch.stop();
            else
                root.probe();
        }
    }
}
