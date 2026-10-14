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

    readonly property var list: Tunnels.list

    width: parent ? parent.width : 0

    Connections {
        target: Tunnels

        function onImported(name: string): void {
            pathField.clear();
            SettingsView.drop(name ? `${name} imported` : "tunnel imported", "upload_file");
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
        model: ScriptModel {
            values: root.list
            objectProp: "uuid"
        }

        delegate: SettingsRowFrame {
            id: tunnel

            required property var modelData

            width: root.width
            icon: "vpn_lock"
            label: tunnel.modelData.name
            detail: tunnel.modelData.busy ? (tunnel.modelData.on ? "connecting" : "disconnecting") : tunnel.modelData.trouble || tunnel.modelData.kind
            detailColour: tunnel.modelData.trouble && !tunnel.modelData.busy ? Appearance.colour.alarm : Appearance.colour.textFaint
            interactive: !tunnel.modelData.busy
            onActivated: Tunnels.set(tunnel.modelData, !tunnel.modelData.on)
            onPointed: SettingsView.hovered = root.row

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: !!tunnel.modelData.on
                enabled: !tunnel.modelData.busy
                onToggled: Tunnels.set(tunnel.modelData, !tunnel.modelData.on)
            }
        }
    }

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "upload_file"
        label: "Add a tunnel"
        detail: Tunnels.importTrouble || ".conf or .ovpn"
        detailColour: Tunnels.importTrouble ? Appearance.colour.alarm : Appearance.colour.textFaint
        onPointed: SettingsView.hovered = root.row

        SettingsField {
            id: pathField

            anchors.verticalCenter: parent.verticalCenter
            placeholder: "file path"
            mono: true
            enabled: !Tunnels.importing
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            text: Tunnels.importing ? "Importing" : "Import"
            interactive: !Tunnels.importing
            onClicked: Tunnels.importFile(pathField.draft)
        }
    }
}
