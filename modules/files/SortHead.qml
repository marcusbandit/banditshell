import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var head

    signal chose(string id)

    implicitWidth: words.visible ? words.x + words.implicitWidth : label.implicitWidth
    implicitHeight: label.implicitHeight
    width: implicitWidth
    height: implicitHeight

    StyledText {
        id: label

        text: root.head.label
        font.pixelSize: Files.zoomed(Appearance.font.size.small)
        color: root.head.active ? Appearance.colour.text : hover.hovered && root.head.sortable ? Appearance.colour.textDim : Appearance.colour.textFaint
    }

    StyledText {
        id: words

        x: label.implicitWidth + Appearance.padding.small
        visible: root.head.words !== ""
        text: `· ${root.head.words}`
        font.pixelSize: Files.zoomed(Appearance.font.size.small)
        color: Appearance.colour.textDim
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.hair
        enabled: root.head.sortable
        cursorShape: Qt.PointingHandCursor

        onClicked: root.chose(root.head.id)
    }
}
