import QtQuick

StyledText {
    id: root

    readonly property real inkOffsetX: root.width / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
    readonly property real inkOffsetY: root.height / 2 - (root.baselineOffset + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)

    property bool alignInk: false

    transform: Translate {
        x: root.alignInk ? -ink.tightBoundingRect.x : 0
    }

    TextMetrics {
        id: ink

        font: root.font
        text: root.text
    }
}
