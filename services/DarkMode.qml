pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string scheme: ""

    readonly property bool available: root.scheme !== ""

    readonly property bool dark: root.scheme === "prefer-dark"

    function take(text: string): void {
        const m = /'([a-z-]+)'/.exec(text);
        if (m)
            root.scheme = m[1];
    }

    function set(on: bool): void {
        root.scheme = on ? "prefer-dark" : "default";
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", root.scheme]);
    }

    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"]
        stdout: StdioCollector {
            onStreamFinished: root.take(text)
        }
    }

    Process {
        running: root.available
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        stdout: SplitParser {
            onRead: line => root.take(line)
        }
    }
}
