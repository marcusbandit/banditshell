pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "speedtest.js" as Speed

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.online ?? {}).speedtest !== false
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`
    readonly property var packages: ["pacman:speedtest-cli", "apt:speedtest-cli", "dnf:speedtest-cli", "zypper:python3-speedtest-cli", "xbps:speedtest-cli", "apk:speedtest-cli"]

    property bool found: false
    property bool probed: false
    property string installing: ""

    property var state: Speed.fresh()
    property var last: null
    property string failed: ""
    readonly property bool running: tester.running

    function probe(): void {
        if (!root.probed && !prober.running)
            prober.running = true;
    }

    function start(): void {
        if (tester.running || root.probed && !root.found)
            return;
        root.failed = "";
        root.state = Speed.fresh();
        tester.running = true;
    }

    function stop(): void {
        tester.running = false;
        root.failed = "";
    }

    function install(): void {
        if (root.installing === "trying")
            return;
        root.installing = "trying";
        Polkit.expect("Install speedtest-cli", "speedtest-cli");
        packageInstaller.running = true;
    }

    Process {
        id: prober

        command: ["sh", "-c", "command -v speedtest-cli"]
        onExited: code => {
            root.found = code === 0;
            root.probed = true;
        }
    }

    Process {
        id: tester

        command: ["speedtest-cli", "--secure"]
        environment: ({
                PYTHONUNBUFFERED: "1"
            })
        stdout: SplitParser {
            onRead: line => root.state = Speed.readLine(root.state, line)
        }
        stderr: SplitParser {
            onRead: line => root.state = Speed.readLine(root.state, line)
        }
        onExited: code => {
            if (root.state.phase !== "done") {
                root.failed = code === 0 || code === 143 || code === 15 ? "" : root.state.failed || "no connection";
                return;
            }
            root.last = Object.assign({}, root.state, {
                at: Date.now()
            });
            store.setText(JSON.stringify(root.last));
            Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "network-transmit-receive", "Speed test", Speed.summary(root.state)]);
        }
    }

    Process {
        id: packageInstaller

        command: [root.installer, "--polkit", ...root.packages]
        onExited: code => {
            Polkit.forget();
            if (code === 4 || code === 127) {
                root.installing = "terminal";
                Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.installer}' --ask ${root.packages.join(" ")}`]);
                return;
            }
            root.installing = code === 0 || code === 126 ? "" : "failed";
            root.probed = false;
            root.probe();
        }
    }

    FileView {
        id: store

        path: `${Config.stateDir}/speedtest.json`
        printErrors: false
        onLoaded: {
            try {
                root.last = JSON.parse(store.text());
            } catch (e) {}
        }
    }
}
