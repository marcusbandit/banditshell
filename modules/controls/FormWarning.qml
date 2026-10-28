import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string text: ""

    width: parent.width
    implicitHeight: visible ? words.implicitHeight + Appearance.padding.small * 2 : 0

    Icon {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal
        y: Appearance.padding.small
        name: "warning"
        fill: 1
        size: Appearance.font.size.small * 1.4
        color: Appearance.colour.warning
    }

    StyledText {
        id: words

        anchors.left: mark.right
        anchors.leftMargin: Appearance.padding.small
        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.normal
        y: Appearance.padding.small
        wrapMode: Text.Wrap
        text: root.text
        color: Appearance.colour.warning
        font.pixelSize: Appearance.font.size.small
    }
}
