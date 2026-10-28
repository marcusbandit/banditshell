pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import "keymap.js" as Logic

Singleton {
    id: root

    property var layouts: []
    property var variants: []
    property int index: 0
    property string name: ""
    property bool capsLock: false

    readonly property var codes: Logic.codes(root.layouts, root.variants)
    readonly property string layout: root.codes[root.index] ?? ""
    readonly property string tag: Logic.codes(root.layouts, root.variants, "")[root.index] ?? ""
    readonly property bool shared: Logic.shared(root.layouts, root.index)
    readonly property bool several: root.layouts.length > 1

    property bool stale: false

    function refresh(): void {
        if (!Compositor.isHyprland)
            return;
        if (reader.running)
            root.stale = true;
        else
            reader.running = true;
    }

    function next(): void {
        if (Compositor.isHyprland)
            switcher.running = true;
    }

    function read(text: string): void {
        const main = Logic.keyboard(text);
        if (!main)
            return;
        root.name = main.name;
        root.layouts = main.layouts;
        root.variants = main.variants;
        root.index = main.index;
        root.capsLock = main.capsLock;
    }

    Component.onCompleted: root.refresh()

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (event.name === "activelayout" || event.name === "configreloaded")
                root.refresh();
        }
    }

    Process {
        id: reader

        command: ["hyprctl", "devices", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.read(text)
        }

        onExited: {
            if (!root.stale)
                return;
            root.stale = false;
            reader.running = true;
        }
    }

    Process {
        id: switcher

        command: ["hyprctl", "switchxkblayout", "all", "next"]

        onExited: root.refresh()
    }
}
