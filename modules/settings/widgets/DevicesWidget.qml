pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    function stateOf(d: var): string {
        if (d.blocked)
            return "blocked";
        if (d.connected)
            return "on";
        if (d.paired || d.bonded)
            return "paired";
        return "near";
    }

    readonly property var groups: [["on", "connected"], ["paired", "paired"], ["near", "nearby"], ["blocked", "blocked"]].map(g => ({
                key: g[0],
                name: g[1],
                list: Bluetooth.devices.filter(d => root.stateOf(d) === g[0])
            })).filter(g => g.list.length > 0)

    width: parent ? parent.width : 0

    property bool started: false

    function discover(): void {
        if (Bluetooth.enabled && !Bluetooth.discovering) {
            Bluetooth.setDiscovering(true);
            root.started = true;
        }
    }

    Component.onCompleted: root.discover()
    Component.onDestruction: if (root.started)
        Bluetooth.setDiscovering(false)

    Connections {
        target: Bluetooth

        function onEnabledChanged(): void {
            root.discover();
        }
    }

    SettingsRowFrame {
        width: root.width
        visible: !Bluetooth.enabled
        interactive: false
        label: "bluetooth is off"
        onPointed: SettingsView.hovered = root.row
    }

    Repeater {
        model: Bluetooth.enabled ? root.groups : []

        delegate: Column {
            id: group

            required property var modelData

            width: root.width

            StyledText {
                x: Appearance.padding.normal
                topPadding: Appearance.padding.normal
                bottomPadding: Appearance.padding.normal
                text: group.modelData.name
                color: Appearance.colour.textFaint
            }

            Repeater {
                model: ScriptModel {
                    values: group.modelData.list
                    objectProp: "address"
                }

                delegate: SettingsRowFrame {
                    id: dev

                    required property var modelData

                    readonly property bool busy: !!dev.modelData.pairing || Bluetooth.stateLabel(dev.modelData) === "connecting"
                    readonly property bool near: root.stateOf(dev.modelData) === "near"

                    width: root.width
                    icon: Bluetooth.icon(dev.modelData)
                    label: dev.modelData.name || dev.modelData.deviceName || dev.modelData.address
                    detail: dev.busy ? "connecting" : [dev.modelData.connected && dev.modelData.batteryAvailable ? `${Math.round(dev.modelData.battery * 100)}%` : "", dev.modelData.trusted ? "trusted" : ""].filter(Boolean).join(" · ")
                    selected: SettingsView.pin?.type === "dev" && SettingsView.pin.id === dev.modelData.address
                    onActivated: SettingsView.openPin("dev", dev.modelData.address, dev.label)
                    onPointed: SettingsView.hovered = root.row

                    Button {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: dev.near
                        size: 0
                        text: dev.busy ? "Pairing" : "Pair"
                        onClicked: Bluetooth.toggleDevice(dev.modelData)
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chevron_right"
                        color: Appearance.colour.textDim
                    }
                }
            }
        }
    }
}
