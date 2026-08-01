pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Bluetooth. This one is real.
//
// Discovery, like wifi scanning, runs while the menu is open and stops when it
// closes. Unlike wifi it is also visible to other people's devices, so leaving
// it on in the background would be rude as well as wasteful.
Column {
    id: root

    spacing: Appearance.padding.small

    Component.onCompleted: if (Bluetooth.enabled)
        Bluetooth.setDiscovering(true)
    Component.onDestruction: Bluetooth.setDiscovering(false)

    MenuRow {
        width: root.width
        icon: Bluetooth.statusIcon()
        label: "Bluetooth"
        detail: !Bluetooth.available ? "no adapter" : Bluetooth.anyConnected ? `${Bluetooth.connectedDevices.length} connected` : Bluetooth.discovering ? "scanning" : "on, nothing connected"
        interactive: Bluetooth.available
        onActivated: Bluetooth.setEnabled(!Bluetooth.enabled)

        Toggle {
            checked: Bluetooth.enabled
            onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
        }
    }

    Separator {
        width: parent.width
        visible: Bluetooth.enabled
    }

    Repeater {
        model: Bluetooth.enabled ? Bluetooth.devices.slice(0, Appearance.sizes.deviceListMax) : []

        delegate: MenuRow {
            required property var modelData

            width: root.width
            icon: Bluetooth.icon(modelData)
            label: modelData.name || modelData.address
            detail: Bluetooth.stateLabel(modelData)
            selected: modelData.connected

            onActivated: Bluetooth.toggleDevice(modelData)

            // A paired device you can forget. Only offered once it is paired,
            // because forgetting something you have never met is meaningless.
            Icon {
                visible: modelData.paired || modelData.bonded
                name: "close"
                color: Appearance.colour.textFaint

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Appearance.padding.small
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.forget()
                }
            }
        }
    }

    StyledText {
        visible: Bluetooth.enabled && !Bluetooth.devices.length
        text: Bluetooth.discovering ? "scanning" : "nothing paired"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    StyledText {
        visible: !Bluetooth.available
        text: "no bluetooth adapter on this machine"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }
}
