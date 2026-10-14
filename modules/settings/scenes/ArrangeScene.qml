import QtQuick
import qs.modules.settings

Item {
    id: root

    readonly property bool editing: SettingsView.current === "screens"
    readonly property real stageHeight: root.editing ? 420 : 260
    readonly property bool fills: root.editing

    ScreenCanvas {
        anchors.fill: parent
        editable: root.editing
    }
}
