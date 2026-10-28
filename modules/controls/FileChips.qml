import QtQuick
import qs.config
import qs.components

Flow {
    id: root

    property var files: []
    property string lead: ""
    property bool browsing: false
    property bool choosing: false

    signal picked(string path)
    signal browse

    width: parent.width
    leftPadding: Appearance.padding.normal
    rightPadding: Appearance.padding.normal
    spacing: Appearance.padding.small

    StyledText {
        visible: !!root.lead && root.files.length > 0
        height: browseButton.height
        verticalAlignment: Text.AlignVCenter
        text: root.lead
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Repeater {
        model: root.files

        Button {
            required property string modelData

            size: 0
            style: "bare"
            icon: "description"
            text: modelData.slice(modelData.lastIndexOf("/") + 1)
            onClicked: root.picked(modelData)
        }
    }

    Button {
        id: browseButton

        size: 0
        style: "bare"
        icon: "folder_open"
        interactive: !root.choosing
        text: root.browsing ? "Choosing…" : "Browse…"
        onClicked: root.browse()
    }
}
