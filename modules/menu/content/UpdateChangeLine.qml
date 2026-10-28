import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string text: ""
    property color hue: Appearance.colour.textDim
    property bool major: false
    property bool unread: false

    height: changeText.height

    SquircleRect {
        x: Math.round((Appearance.font.iconSize - width) / 2)
        y: Math.round((Appearance.font.line.small - height) / 2)
        width: root.unread ? Math.max(6, Math.round(Appearance.font.size.small / 2.5)) : Math.max(4, Math.round(Appearance.font.size.small / 4))
        height: width
        pill: "object"
        color: root.unread ? Appearance.colour.accent : Appearance.blend(Appearance.colour.textFaint, root.hue, 0.5)
    }

    StyledText {
        id: changeText

        x: Appearance.font.iconSize + Appearance.padding.small
        width: root.width - x
        text: root.text
        color: root.major ? Appearance.colour.text : Appearance.colour.textDim
        wrapMode: Text.WordWrap
    }
}
