import QtQuick
import "theme.js" as Theme

Text {
    id: root

    font.family: Theme.fontFamily
    font.pixelSize: Theme.small
    renderType: Text.NativeRendering
    color: Theme.text

    lineHeight: Math.round(font.pixelSize * 4 / 3)
    lineHeightMode: Text.FixedHeight
}
