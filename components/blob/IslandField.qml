import QtQuick
import qs.config

ShaderEffect {
    id: root

    property rect pillRect: Qt.rect(0, 0, 0, 0)
    property var budRects: []
    property var budReaches: []
    property real pillRadius: 0

    property real sheenWidth: Appearance.sizes.seam
    property color sheenColour: Appearance.colour.rim

    property color colour: Appearance.colour.island
    property color bandColour: Appearance.colour.surface

    property real edge: 0
    property real neck: 0

    property real smoothing: Appearance.sizes.melt / 2
    property real feather: Appearance.sizes.meltFeather
    property real power: Appearance.rounding.power

    property var source: null

    property Item backdrop: null
    property point origin: Qt.point(0, 0)
    property real raised: 0
    property real bandRaised: 0
    property real bezel: Appearance.padding.large * 1.25
    property real bend: root.bezel * 0.9
    property real spread: 0.05

    readonly property bool glassy: (root.backdrop?.ready ?? false) && root.width > 0 && root.height > 0
    readonly property real glass: root.glassy ? 1 : 0
    readonly property vector2d view: Qt.vector2d(Math.max(1, root.backdrop?.width ?? 1), Math.max(1, root.backdrop?.height ?? 1))
    readonly property variant soft: root.glassy ? root.backdrop.soft : blank
    readonly property variant frost: root.glassy ? root.backdrop.frost : blank

    Image {
        id: blank

        visible: false
    }

    readonly property vector4d size: Qt.vector4d(width, height, 0, 0)
    readonly property vector4d pill: Qt.vector4d(pillRect.x, pillRect.y, pillRect.width, pillRect.height)
    readonly property vector4d bud0: root.slot(0)
    readonly property vector4d bud1: root.slot(1)
    readonly property vector4d bud2: root.slot(2)
    readonly property vector4d bud3: root.slot(3)
    readonly property vector4d reaches: Qt.vector4d(root.budReaches[0] ?? 0, root.budReaches[1] ?? 0, root.budReaches[2] ?? 0, root.budReaches[3] ?? 0)
    readonly property vector4d radii: Qt.vector4d(pillRadius, 0, sheenWidth, 0)

    function slot(i: int): vector4d {
        const r = root.budRects[i];
        return r ? Qt.vector4d(r.x, r.y, r.width, r.height) : Qt.vector4d(0, 0, 0, 0);
    }

    fragmentShader: Qt.resolvedUrl("island.frag.qsb")
}
