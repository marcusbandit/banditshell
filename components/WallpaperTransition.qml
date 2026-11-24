// Adapted from WallpaperFx.qml in pocket-dots by Diego Malagrida, GPL-3.0:
// https://github.com/diegoMalagrida/pocket-dots/blob/main/home/.config/quickshell/WallpaperFx.qml
import QtQuick

ShaderEffect {
    id: root

    property var source
    property Item underItem: null
    property Item field: null
    property Item line: null

    property real t: 0
    property bool outline: false
    property color ember: "orange"
    property color ink: "white"
    property real seed: 0

    readonly property var under: root.underItem ? capture : root.source
    readonly property var fieldTex: root.field
    readonly property var lineTex: root.line
    readonly property real mode: root.outline ? 1 : 0
    readonly property real sw: root.width
    readonly property real sh: root.height
    readonly property real fw: Math.max(root.field?.implicitWidth ?? 1, 1)
    readonly property real fh: Math.max(root.field?.implicitHeight ?? 1, 1)
    readonly property real lw: Math.max(root.line?.implicitWidth ?? 1, 1)
    readonly property real lh: Math.max(root.line?.implicitHeight ?? 1, 1)
    readonly property real glow: 0.9
    readonly property real lineW: 1.5
    readonly property real sdRange: 16
    readonly property real hasUnder: root.underItem ? 1 : 0
    readonly property vector4d cropMap: {
        const s = Math.max(root.sw / root.fw, root.sh / root.fh);
        const w = root.sw / (root.fw * s);
        const h = root.sh / (root.fh * s);
        return Qt.vector4d((1 - w) / 2, (1 - h) / 2, w, h);
    }

    ShaderEffectSource {
        id: capture

        sourceItem: root.underItem
        live: true
        hideSource: false
        visible: false
    }

    fragmentShader: Qt.resolvedUrl("wallpapertransition.frag.qsb")
}
