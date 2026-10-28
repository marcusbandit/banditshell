import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon: ""
    property string text: ""

    implicitWidth: row.implicitWidth + Appearance.padding.small * 2
    implicitHeight: row.implicitHeight + Appearance.padding.hair * 2

    SquircleRect {
        anchors.fill: parent

        pill: "object"
        color: Appearance.colour.fill
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.padding.hair

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.icon
            size: Appearance.icon.small
            color: Appearance.colour.textDim
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: Appearance.colour.text
        }
    }
}
