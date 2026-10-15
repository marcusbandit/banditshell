pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property var layouts: []
    property int index: 0
    property bool capsLock: false

    readonly property string layout: (root.layouts[root.index] ?? "").toUpperCase()
    readonly property bool several: root.layouts.length > 1

    function refresh(): void {
        if (Compositor.isHyprland)
            reader.running = true;
    }

    function next(): void {
        if (Compositor.isHyprland)
            switcher.running = true;
    }

    function read(text: string): void {
        let keyboards = [];
        try {
            keyboards = JSON.parse(text)?.keyboards ?? [];
        } catch (e) {
            return;
        }
        const main = keyboards.find(k => k.main) ?? keyboards[0];
        if (!main)
            return;
        root.layouts = String(main.layout ?? "").split(",").map(l => l.trim()).filter(l => l);
        root.index = main.active_layout_index ?? 0;
        root.capsLock = !!main.capsLock;
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "activelayout")
                root.refresh();
        }
    }

    Process {
        id: reader

        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.read(text)
        }
    }

    Process {
        id: switcher

        command: ["hyprctl", "switchxkblayout", "all", "next"]

        onExited: root.refresh()
    }
}
