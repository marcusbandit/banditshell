pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// ONE SETTING: what it is called, what it means, and the control that changes it.
//
// The control goes in as a child, so this file knows nothing about switches or
// segments and every row lines up with every other one regardless of what is on
// its right.
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
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: root.detail
            font.pixelSize: Appearance.sizes.filesText
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
