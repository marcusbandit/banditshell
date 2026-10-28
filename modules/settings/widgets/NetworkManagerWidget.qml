import QtQuick
import qs.modules.settings

SettingsRowFrame {
    id: root

    property var row: ({})

    width: parent ? parent.width : 0
    interactive: false
    notice: true
    icon: "info"
    label: SettingsState.networkMissing
    onPointed: SettingsView.hovered = root.row
}
