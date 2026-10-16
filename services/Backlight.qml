pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "brightness.js" as Brightness

Singleton {
    id: root

    property var devices: []
    property var levels: ({})
    property bool read: false

    readonly property bool available: root.devices.length > 0

    property var pending: ({})

    function refresh(): void {
        if (!ToolInstaller.has("brightnessctl") || listing.running)
            return;
        listing.running = true;
    }

    function levelOf(name: string): real {
        const known = root.levels[name];
        if (known !== undefined)
            return known;
        const device = root.devices.find(d => d.name === name);
        return device ? device.current / device.max : -1;
    }

    function setLevel(name: string, fraction: real): void {
        const device = root.devices.find(d => d.name === name);
        if (!device)
            return;
        const next = Object.assign({}, root.levels);
        next[name] = fraction;
        root.levels = next;
        const waiting = Object.assign({}, root.pending);
        waiting[name] = Brightness.rawLevel(fraction, device.max);
        root.pending = waiting;
        settle.restart();
    }

    function write(): void {
        if (writer.running) {
            settle.restart();
            return;
        }
        const names = Object.keys(root.pending);
        if (!names.length)
            return;
        const name = names[0];
        const raw = root.pending[name];
        const rest = Object.assign({}, root.pending);
        delete rest[name];
        root.pending = rest;
        writer.command = ["brightnessctl", "--quiet", "--device", name, "set", `${raw}`];
        writer.running = true;
    }

    Connections {
        target: ToolInstaller

        function onProbedChanged(): void {
            if (!root.read)
                root.refresh();
        }
    }

    Component.onCompleted: root.refresh()

    Timer {
        id: settle

        interval: 120
        onTriggered: root.write()
    }

    Process {
        id: listing

        command: ["brightnessctl", "--list", "--machine-readable", "--class", "backlight"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.devices = Brightness.parseBacklights(text);
                root.levels = ({});
                root.read = true;
            }
        }
    }

    Process {
        id: writer

        onExited: {
            if (Object.keys(root.pending).length)
                root.write();
        }
    }
}
