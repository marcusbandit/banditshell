import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string path: ""
    property string detail: ""
    property bool warn: false
    property bool picked: false

    signal chosen

    implicitHeight: words.implicitHeight + Appearance.padding.small * 2

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: root.picked ? Appearance.colour.accentFill : press.containsMouse ? Appearance.colour.fill : "transparent"
    }

    Icon {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.small
        anchors.top: parent.top
        anchors.topMargin: Appearance.padding.small
        name: root.picked ? "check_circle" : "description"
        fill: root.picked ? 1 : 0
        color: root.picked ? Appearance.colour.accent : Appearance.colour.textDim
    }

    Column {
        id: words

        anchors.left: mark.right
        anchors.leftMargin: Appearance.padding.small
        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.small
        y: Appearance.padding.small

        StyledText {
            width: parent.width
            text: root.path.slice(root.path.lastIndexOf("/") + 1)
            elide: Text.ElideMiddle
            color: root.picked ? Appearance.colour.accent : Appearance.colour.text
            font.pixelSize: Appearance.font.size.small
        }

        StyledText {
            width: parent.width
            visible: !!root.detail
            text: root.detail
            wrapMode: Text.Wrap
            color: root.warn ? Appearance.colour.warning : Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }
    }

    MouseArea {
        id: press

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.chosen()
    }
}
