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

    // INK HONESTY. The item's edge is not the INK's edge: every glyph carries
    // a bearing, so text beside exact edges - a button's pill, a rule -
    // starts a pixel or two in, and the column reads ragged. alignInk shifts
    // the PAINT, never the item, so the ink lands on the line the boxes
    // share.
    property bool alignInk: false

    transform: Translate {
        x: root.alignInk ? -ink.tightBoundingRect.x : 0
    }

    readonly property real inkWidth: ink.tightBoundingRect.width
    readonly property real inkHeight: ink.tightBoundingRect.height

    TextMetrics {
        id: ink

        font: root.font
        text: root.text
    }
}
