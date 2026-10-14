pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var list: SettingsState.planned.tunnels ?? []

    width: parent ? parent.width : 0

    Component.onCompleted: probe.running = true

    Process {
        id: probe

        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                for (const line of text.split("\n")) {
                    const parts = line.split(":");
                    if (parts.length < 2 || !/vpn|wireguard/.test(parts[1]))
                        continue;
                    found.push({
                        name: parts[0],
                        kind: parts[1].indexOf("wireguard") >= 0 ? "wireguard" : "vpn",
                        on: !!parts[2]
                    });
                }
                const known = root.list.map(t => t.name);
                const merged = root.list.map(t => {
                    const live = found.find(f => f.name === t.name);
                    return live ? Object.assign({}, t, {
                        on: live.on
                    }) : t;
                }).concat(found.filter(t => known.indexOf(t.name) < 0));
                if (JSON.stringify(merged) !== JSON.stringify(root.list))
                    SettingsState.plan("tunnels", merged);
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: root.list.length === 0
        interactive: false
        icon: "vpn_lock"
        label: "No tunnels yet"
        detail: "import one below"
        onPointed: SettingsView.hovered = root.row
    }

    Repeater {
        model: root.list

        delegate: SettingsRowFrame {
            id: tunnel

            required property var modelData
            required property int index

            width: root.width
            icon: "vpn_lock"
            label: tunnel.modelData.name
            detail: tunnel.modelData.kind
            onActivated: flip()
            onPointed: SettingsView.hovered = root.row

            function flip(): void {
                const next = root.list.slice();
                next[tunnel.index] = Object.assign({}, tunnel.modelData, {
                    on: !tunnel.modelData.on
                });
                SettingsState.plan("tunnels", next);
            }

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: !!tunnel.modelData.on
                onToggled: tunnel.flip()
            }
        }
    }
}
