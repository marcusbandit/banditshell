pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "powerprofile.js" as Logic

Singleton {
    id: root

    property string daemon: ""
    property string profile: "balanced"
    property var names: []

    property bool probed: false
    property bool rereadWanted: false

    readonly property bool available: root.daemon !== ""
    readonly property var choices: Logic.choices(root.daemon, root.names)

    readonly property string trouble: root.probed && !root.available ? "no power profile daemon installed · power-profiles-daemon does this" : ""

    function set(profile: string): void {
        const name = Logic.nameFor(root.daemon, profile);
        if (!name)
            return;
        root.profile = profile;
        setter.command = root.daemon === "tuned" ? ["tuned-adm", "profile", name] : ["powerprofilesctl", "set", name];
        setter.running = true;
    }

    function refresh(): void {
        if (!root.available)
            return;
        if (reader.running) {
            root.rereadWanted = true;
            return;
        }
        reader.command = root.daemon === "tuned" ? ["tuned-adm", "active"] : ["powerprofilesctl", "get"];
        reader.running = true;
    }

    Process {
        id: setter

        onExited: root.refresh()
    }

    Process {
        id: reader

        onExited: if (root.rereadWanted) {
            root.rereadWanted = false;
            root.refresh();
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const name = Logic.parseActive(root.daemon, text);
                if (name)
                    root.profile = Logic.profileFor(root.daemon, name);
            }
        }
    }

    Process {
        id: probe

        running: true
        command: ["sh", "-c", `
if command -v powerprofilesctl >/dev/null 2>&1 && powerprofilesctl get >/dev/null 2>&1; then
  echo "daemon ppd"
  powerprofilesctl list 2>/dev/null | sed -n 's/^[* ] \\([a-z-]*\\):$/name \\1/p'
elif command -v tuned-adm >/dev/null 2>&1 && tuned-adm active >/dev/null 2>&1; then
  echo "daemon tuned"
fi
`]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = Logic.parseProbe(text);
                root.names = found.names;
                root.daemon = found.daemon;
                root.probed = true;
                root.refresh();
            }
        }
    }

    Process {
        id: watcher

        command: root.daemon === "tuned" ? ["gdbus", "monitor", "--system", "--dest", "com.redhat.tuned"] : ["gdbus", "monitor", "--system", "--dest", "net.hadess.PowerProfiles"]

        stdout: SplitParser {
            onRead: line => root.refresh()
        }

        onRunningChanged: if (!watcher.running && root.available)
            watcherRestart.restart()
    }

    onAvailableChanged: watcher.running = root.available

    Timer {
        id: watcherRestart

        interval: 5000
        onTriggered: watcher.running = true
    }

    Timer {
        interval: 30000
        running: root.available
        repeat: true
        onTriggered: root.refresh()
    }
}
