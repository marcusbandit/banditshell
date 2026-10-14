pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property string set: root.row.set ?? "shell"
    readonly property var keys: root.set === "shell" ? SettingsKeys.shell : SettingsKeys.files

    width: parent ? parent.width : 0

    SettingsRowFrame {
        width: root.width
        visible: root.keys.length === 0
        interactive: false
        label: root.set === "shell" ? "no binds found" : "no keys set"
        detail: root.set === "shell" ? "the shell reads them from hyprland’s config" : ""
        onPointed: SettingsView.hovered = root.row
    }

    Repeater {
        model: root.keys

        delegate: SettingsRowFrame {
            id: key

            required property var modelData

            readonly property string pinId: `${root.set}:${key.modelData.id}`

            width: root.width
            label: key.modelData.name
            selected: SettingsView.pin?.type === "key" && SettingsView.pin.id === key.pinId
            onActivated: SettingsView.openPin("key", key.pinId, key.modelData.name)
            onPointed: SettingsView.hovered = root.row

            KeyCaps {
                anchors.verticalCenter: parent.verticalCenter
                combo: key.modelData.combo
            }
        }
    }
}
