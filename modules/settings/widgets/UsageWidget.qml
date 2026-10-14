import QtQuick
import qs.config
import qs.components
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    width: parent ? parent.width : 0

    SettingsRowFrame {
        width: root.width
        interactive: false
        icon: "hourglass_empty"
        label: `${SettingsState.usedLabel} in front of the screen today`
        detail: "time per app is not counted yet"
        onPointed: SettingsView.hovered = root.row
    }
}
