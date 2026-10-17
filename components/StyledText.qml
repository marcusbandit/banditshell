import QtQuick
import qs.config

Text {
    id: root

    font.family: Appearance.font.family

    font.pixelSize: Appearance.font.size.small
    renderType: Text.NativeRendering
    color: Appearance.colour.text
    textFormat: Text.PlainText

    lineHeight: Math.round(font.pixelSize * Appearance.font.leading)
    lineHeightMode: Text.FixedHeight
}
