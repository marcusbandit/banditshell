import QtQuick
import qs.config

Text {
    id: root

    font.family: Appearance.font.family

    font.pixelSize: Appearance.font.size.small
    renderType: Text.NativeRendering
    color: Appearance.colour.text

    lineHeight: Math.round(font.pixelSize * 4 / 3)
    lineHeightMode: Text.FixedHeight

    readonly property real inkOffsetX: root.width / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
    readonly property real inkOffsetY: root.height / 2 - (root.baselineOffset + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)

    readonly property real inkWidth: ink.tightBoundingRect.width
    readonly property real inkHeight: ink.tightBoundingRect.height

    TextMetrics {
        id: ink

        font: root.font
        text: root.text
    }
}
