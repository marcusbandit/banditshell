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

    readonly property var list: Network.enabled && !Hotspot.active ? Network.networks : []

    width: parent ? parent.width : 0

    Component.onCompleted: Network.setViewing(root, true)
    Component.onDestruction: {
        Network.setViewing(root, false);
        Network.setViewing(rescan, false);
    }

    SettingsRowFrame {
        width: root.width
        visible: !Network.enabled
        interactive: false
        label: "wi-fi is off"
        detail: "ethernet still works"
        onPointed: SettingsView.hovered = root.row
    }

    SettingsRowFrame {
        width: root.width
        visible: Network.enabled && Hotspot.active
        interactive: false
        icon: "wifi_tethering"
        label: "wi-fi is running your hotspot"
        detail: "it joins networks again once the hotspot is off"
        onPointed: SettingsView.hovered = root.row

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            text: "Stop it"
            onClicked: SettingsState.set("hotspot", false)
        }
    }

    Item {
        width: root.width
        height: tools.height
        visible: Network.enabled && !Hotspot.active

        Row {
            id: tools

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal

            SettingsTool {
                icon: "qr_code_scanner"
                tip: "scan a code"
                on: SettingsView.pin?.type === "scan"
                onClicked: SettingsView.openPin("scan", "scan", "scan a code")
            }

            SettingsTool {
                id: rescan

                icon: "refresh"
                tip: "look again"
                on: Network.scanning
                onClicked: {
                    Network.setViewing(rescan, true);
                    lookAgain.restart();
                }

                Timer {
                    id: lookAgain

                    interval: 4000
                    onTriggered: {
                        Network.setViewing(rescan, false);
                        SettingsView.drop(`${Network.networks.length} networks around`, "radar");
                    }
                }
            }
        }
    }

    Repeater {
        model: ScriptModel {
            values: root.list
            objectProp: "name"
        }

        delegate: SettingsRowFrame {
            id: net

            required property var modelData

            readonly property bool on: !!net.modelData.connected
            readonly property bool secured: Network.secured(net.modelData)

            width: root.width
            label: net.modelData.name
            detail: net.on ? (Network.captive ? "connected · sign in" : "connected") : net.modelData.known ? "saved" : net.secured ? "" : "open"
            selected: SettingsView.pin?.type === "net" && SettingsView.pin.id === net.modelData.name
            onActivated: SettingsView.openPin("net", net.modelData.name, net.modelData.name)
            onPointed: SettingsView.hovered = root.row
            lead: Component {
                Item {
                    width: Appearance.font.iconSize
                    height: Appearance.font.iconSize

                    SettingsBars {
                        anchors.centerIn: parent
                        lit: Network.bars(net.modelData)
                        colour: net.on || net.selected ? Appearance.colour.text : Appearance.colour.textDim
                    }
                }
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: net.secured
                name: "lock"
                color: Appearance.colour.textDim
            }

            SquircleRect {
                anchors.verticalCenter: parent.verticalCenter
                visible: net.on
                width: 6
                height: 6
                radius: 3
                cornerPower: 2
                color: Appearance.colour.accent
            }
        }
    }
}
