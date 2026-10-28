import QtQuick
import qs.config
import qs.components

Column {
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
    topPadding: Appearance.padding.small
    bottomPadding: Appearance.padding.small
    spacing: Appearance.padding.small

    StyledText {
        visible: !!root.lead && root.files.length > 0
        text: root.lead
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Flow {
        width: root.width - root.leftPadding - root.rightPadding
        visible: root.files.length > 0
        spacing: Appearance.padding.small

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
    }

    Button {
        size: 0
        style: "plate"
        icon: "folder_open"
        interactive: !root.choosing
        text: root.browsing ? "Choosing…" : "Browse…"
        onClicked: root.browse()
    }
}
