import QtQuick
import qs.modules.settings

SettingsRowFrame {
    id: root

    property var row: ({})

    width: parent ? parent.width : 0
    interactive: false
    notice: true
    icon: "router"
    label: SettingsState.networkWhy
    detail: root.row.needs ?? ""
    detailLines: 2
    onPointed: SettingsView.hovered = root.row
}
