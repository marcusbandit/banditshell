import QtQuick
import qs.config
import qs.components

StyledText {
    x: Appearance.padding.card
    y: parent.height - Appearance.padding.normal - height
    width: parent.width - Appearance.padding.card * 2
    color: Appearance.colour.textFaint
    elide: Text.ElideRight
}
