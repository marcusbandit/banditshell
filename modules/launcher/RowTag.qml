import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string text: ""

    width: label.implicitWidth + Appearance.padding.normal * 2
    height: label.implicitHeight + Appearance.padding.small

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colour.fill
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        text: root.text
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textDim
    }
}
