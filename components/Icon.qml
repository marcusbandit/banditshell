import QtQuick
import qs.config
import "font-axes.js" as FontAxes

Text {
    id: root

    property string name: ""

    property string fallback: "question_mark"

    property string glyph: ""

    property real size: Appearance.font.iconSize

    property real fill: 0

    readonly property bool resolved: probe.width <= font.pixelSize * 1.7

    readonly property bool lost: !root.resolved && root.name !== "" && root.glyph === ""

    text: root.glyph || (resolved ? name : fallback)

    font.family: root.glyph ? Appearance.font.brand : Appearance.font.icon
    font.pixelSize: root.size
    color: Appearance.colour.text

    font.variableAxes: ({
            opsz: FontAxes.opticalSize(Math.max(20, Math.min(48, root.size))),
            FILL: FontAxes.fill(root.fill)
        })

    renderType: Text.CurveRendering

    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    TextMetrics {
        id: probe

        font: root.font
        text: root.name
    }

    onLostChanged: if (root.lost)
        IconAudit.watch(root)
    Component.onCompleted: if (root.lost)
        IconAudit.watch(root)
}
