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
    property var opened: ({})

    signal pick(string path)
    signal browse
    signal cancel

    width: parent.width
    leftPadding: Appearance.padding.normal
    rightPadding: Appearance.padding.normal
    topPadding: Appearance.padding.small
    bottomPadding: Appearance.padding.small
    spacing: Appearance.padding.small

    Button {
        visible: root.canBrowse && root.browsing
        style: "plate"
        icon: "close"
        text: "Close file picker"
        onClicked: root.cancel()
    }

    StyledText {
        width: root.width - root.leftPadding - root.rightPadding
        visible: root.canBrowse && root.browsing
        text: "Pick the file in the file picker window. It may be behind this menu."
        wrapMode: Text.Wrap
        color: Appearance.colour.textDim
        font.pixelSize: Appearance.font.size.small
    }

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

            FileChoiceGroup {
                required property var modelData

                width: parent.width
                row: modelData
                picked: root.picked
                opened: !!root.opened[modelData.path]
                onChosen: path => root.pick(path)
                onToggled: root.opened = Object.assign({}, root.opened, {
                    [modelData.path]: !root.opened[modelData.path]
                })
            }
        }
    }

    Button {
        visible: root.canBrowse && !root.browsing
        size: 0
        style: "plate"
        icon: "folder_open"
        interactive: !root.choosing
        text: "Browse…"
        onClicked: root.browse()
    }
}
