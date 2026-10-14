import QtQuick
import qs.config

ShaderEffect {
    id: root

    property rect pillRect: Qt.rect(0, 0, 0, 0)
    property rect budRect: Qt.rect(0, 0, 0, 0)
    property real pillRadius: 0
    property real budRadius: 0

    property real sheenWidth: Appearance.sizes.seam
    property color sheenColour: Appearance.colour.seam

    property color colour: Appearance.colour.ink
    property color bandColour: Appearance.colour.surface

    property real edge: 0
    property real neck: 0

    property real smoothing: Appearance.sizes.melt / 2
    property real feather: Appearance.sizes.meltFeather
    property real power: Appearance.rounding.power

    property var source: null

    readonly property vector4d size: Qt.vector4d(width, height, 0, 0)
    readonly property vector4d pill: Qt.vector4d(pillRect.x, pillRect.y, pillRect.width, pillRect.height)
    readonly property vector4d bud: Qt.vector4d(budRect.x, budRect.y, budRect.width, budRect.height)
    readonly property vector4d radii: Qt.vector4d(pillRadius, budRadius, sheenWidth, 0)

    fragmentShader: Qt.resolvedUrl("island.frag.qsb")
}
