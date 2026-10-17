import QtQuick

Icon {
    id: root

    readonly property real inkOffsetX: root.contentWidth / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
    readonly property real inkOffsetY: root.height / 2 - (root.baselineOffset + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)

    TextMetrics {
        id: ink

        font: root.font
        text: root.text
    }
}
