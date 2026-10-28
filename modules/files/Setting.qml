pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property string label: ""
    property string detail: ""

    default property alias control: slot.data

    implicitHeight: Math.max(text.implicitHeight, slot.childrenRect.height)

    Column {
        id: text

        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: Appearance.padding.large
        anchors.verticalCenter: parent.verticalCenter

        spacing: 0

        StyledText {
            width: parent.width
            text: root.label
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            wrapMode: Text.Wrap
        }

        StyledText {
            width: parent.width
            visible: root.detail !== ""
            text: root.detail
            font.pixelSize: Math.min(Appearance.font.size.small, Files.zoomed(Appearance.font.size.small))
            color: Appearance.colour.textFaint
            wrapMode: Text.Wrap
        }
    }

    Item {
        id: slot

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
