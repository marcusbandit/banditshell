import QtQuick
import qs.config

Text {
    id: root

    property string name: ""

    property string fallback: "question_mark"

    property string glyph: ""

    property real size: Appearance.font.iconSize

    property real fill: 0

    readonly property bool resolved: probe.width <= font.pixelSize * 1.7

    text: root.glyph || (resolved ? name : fallback)

    font.family: root.glyph ? Appearance.font.brand : Appearance.font.icon
    font.pixelSize: root.size
    color: Appearance.colour.text

    font.variableAxes: ({
            opsz: Math.max(20, Math.min(48, root.size)),
            FILL: root.fill
        })

    renderType: Text.CurveRendering

    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    readonly property real inkOffsetX: root.contentWidth / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
    readonly property real inkOffsetY: root.height / 2 - (root.baselineOffset + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)

    TextMetrics {
        id: probe

        font: root.font
        text: root.name
    }

    TextMetrics {
        id: ink

        font: root.font
        text: root.text
    }

    Timer {
        id: complaint

        interval: Appearance.anim.slow
        running: !root.resolved && root.name !== "" && root.glyph === ""

        onTriggered: console.warn(`Icon: "${root.name}" is not in ${Appearance.font.icon}; drawing ${root.fallback} instead.`)
    }
}
