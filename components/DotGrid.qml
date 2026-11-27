import QtQuick
import qs.config

ShaderEffect {
    id: root

    property vector2d pitch: Qt.vector2d(32, 32)
    property point centre: Qt.point(0, 0)
    property color colour: Appearance.colour.rim
    property real dot: 1.25
    property real reach: 320

    readonly property vector2d size: Qt.vector2d(root.width, root.height)

    blending: true
    fragmentShader: Qt.resolvedUrl("dotgrid.frag.qsb")
}
