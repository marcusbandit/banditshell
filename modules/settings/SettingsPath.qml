import QtQuick
import qs.config
import qs.components

Row {
    id: root

    property string path: ""
    property bool readOnly: false

    signal opened
    signal browsed

    spacing: Appearance.padding.normal

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(230, implicitWidth)
        text: root.path
        color: Appearance.colour.textDim
        elide: Text.ElideLeft
    }

    SettingsTool {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.readOnly ? "open_in_new" : "folder_open"
        tip: root.readOnly ? "open" : "pick a folder"
        onClicked: root.readOnly ? root.opened() : root.browsed()
    }
}
