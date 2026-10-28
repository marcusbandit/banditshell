import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string text: ""
    property color hue: Appearance.colour.textDim
    property bool major: false
    property bool unread: false
    property real unreadBar: 3

    height: changeText.height

    SquircleRect {
        x: root.unread ? 0 : Math.round((Appearance.font.iconSize - width) / 2)
        y: root.unread ? 0 : Math.round((Appearance.font.line.small - height) / 2)
        width: root.unread ? root.unreadBar : Math.max(4, Math.round(Appearance.font.size.small / 4))
        height: root.unread ? root.height : width
        pill: "object"
        color: root.unread ? Appearance.colour.accent : Appearance.blend(Appearance.colour.textFaint, root.hue, 0.5)
    }

    StyledText {
        id: changeText

        x: Appearance.font.iconSize + Appearance.padding.small
        width: root.width - x
        text: root.text
        color: root.major || root.unread ? Appearance.colour.text : Appearance.colour.textDim
        wrapMode: Text.WordWrap
    }
}
