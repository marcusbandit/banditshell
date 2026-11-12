import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string title: ""
    property string aside: ""
    property real pad: Appearance.padding.card

    default property alias content: body.data

    implicitHeight: body.implicitHeight + root.pad * 2 + (head.visible ? head.height + Appearance.padding.normal : 0)

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: Appearance.colour.surface
    }

    Item {
        id: head

        x: root.pad
        y: root.pad
        width: root.width - root.pad * 2
        height: label.implicitHeight
        visible: root.title !== ""

        StyledText {
            id: label

            width: parent.width - side.implicitWidth - Appearance.padding.normal
            text: root.title
            color: Appearance.colour.textDim
            elide: Text.ElideRight
        }

        StyledText {
            id: side

            anchors.right: parent.right
            text: root.aside
            color: Appearance.colour.textDim
        }
    }

    Column {
        id: body

        x: root.pad
        y: head.visible ? head.y + head.height + Appearance.padding.normal : root.pad
        width: root.width - root.pad * 2
        spacing: Appearance.padding.normal
    }
}
