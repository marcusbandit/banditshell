import QtQuick
import qs.config

ShaderEffect {
    id: root

    required property GlassSource backdrop
    property point origin: Qt.point(0, 0)

    property real radius: Appearance.rounding.large
    property real power: Appearance.rounding.power
    property real bezel: Math.min(Appearance.padding.large * 1.25, Math.min(root.width, root.height) * 0.3)
    property real bend: root.bezel * 0.9
    property real frosting: 0
    property real spread: 0.05
    property real ceiling: 0.5
    property real sheen: 0.14
    property real shade: 1
    property real lift: 0.03
    property real saturation: 0.9

    readonly property vector4d area: Qt.vector4d(root.origin.x, root.origin.y, root.width, root.height)
    readonly property vector2d view: Qt.vector2d(Math.max(1, root.backdrop.width), Math.max(1, root.backdrop.height))
    readonly property real bleed: 0
    readonly property variant soft: root.backdrop.soft
    readonly property variant frost: root.backdrop.frost

    visible: root.backdrop.ready && root.width > 0 && root.height > 0 && root.opacity > 0
    blending: true
    fragmentShader: Qt.resolvedUrl("glass.frag.qsb")
}
