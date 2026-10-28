import QtQuick
import qs.config
import qs.components

Column {
    id: root

    property var files: []
    property string lead: ""
    property string picked: ""
    property bool canBrowse: true
    property bool browsing: false
    property bool choosing: false

    signal pick(string path)
    signal browse
    signal cancel

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

    Column {
        width: root.width - root.leftPadding - root.rightPadding
        visible: root.files.length > 0

        Repeater {
            model: root.files

            FileChoiceRow {
                required property var modelData

                width: parent.width
                path: modelData.path
                detail: modelData.detail ?? ""
                warn: !!modelData.warn
                picked: modelData.path === root.picked
                onChosen: root.pick(modelData.path)
            }
        }
    }

    Button {
        visible: root.canBrowse
        size: 0
        style: "plate"
        icon: root.browsing ? "close" : "folder_open"
        interactive: root.browsing || !root.choosing
        text: root.browsing ? "Cancel choosing" : "Browse…"
        onClicked: root.browsing ? root.cancel() : root.browse()
    }

    StyledText {
        width: root.width - root.leftPadding - root.rightPadding
        visible: root.canBrowse && root.browsing
        text: "Pick the file in the chooser window. It may be behind this menu."
        wrapMode: Text.Wrap
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }
}
