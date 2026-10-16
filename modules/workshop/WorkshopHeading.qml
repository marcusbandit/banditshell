import QtQuick
import qs.config
import qs.components

Column {
    id: root

    property string text: ""

    width: parent ? parent.width : 0
    topPadding: Appearance.padding.card

    StyledText {
        x: Appearance.padding.normal
        text: root.text.toUpperCase()
        color: Appearance.colour.textDim
    }

    Item {
        width: parent.width
        height: Appearance.padding.normal + 1 + Appearance.padding.small

        Rectangle {
            y: Appearance.padding.normal
            width: parent.width
            height: 1
            color: Appearance.colour.separator
        }
    }
}
