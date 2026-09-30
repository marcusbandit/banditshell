import QtQuick
import qs.config

ShaderEffect {
    id: root

    readonly property int capacity: 12

    property var panels: []

    property color colour: Appearance.colour.surface

    property real smoothing: Appearance.sizes.melt
    property real feather: Appearance.sizes.meltFeather

    property real power: Appearance.rounding.power

    property vector4d content: Qt.vector4d(0, 0, 0, 0)
    property vector4d baseRadius: Qt.vector4d(0, 0, 0, 0)

    property real gap: Appearance.sizes.gap
    property real band: Appearance.sizes.band

    property real screenRadius: Appearance.sizes.windowRadius

    property real frameOn: Appearance.sizes.roundOuter ? 1 : 0
    property color frameColour: Appearance.colour.frame

    property real outlineWidth: 0
    property color outlineColour: Appearance.colour.accent

    property real sheenWidth: Appearance.sizes.seam
    property color sheenColour: Appearance.colour.seam
    property real pad2: 0
    property real pad3: 0

    readonly property vector4d size: Qt.vector4d(width, height, 0, 0)

    function slotRect(i: int): vector4d {
        const p = root.panels[i];
        return p ? Qt.vector4d(p.x, p.y, p.w, p.h) : Qt.vector4d(0, 0, 0, 0);
    }

    function slotRadius(i: int): real {
        return root.panels[i]?.radius ?? 0;
    }

    function slotSmooth(i: int): real {
        return root.panels[i]?.smooth ?? root.smoothing;
    }

    readonly property vector4d blob0: slotRect(0)
    readonly property vector4d blob1: slotRect(1)
    readonly property vector4d blob2: slotRect(2)
    readonly property vector4d blob3: slotRect(3)
    readonly property vector4d blob4: slotRect(4)
    readonly property vector4d blob5: slotRect(5)
    readonly property vector4d blob6: slotRect(6)
    readonly property vector4d blob7: slotRect(7)
    readonly property vector4d blob8: slotRect(8)
    readonly property vector4d blob9: slotRect(9)
    readonly property vector4d blob10: slotRect(10)
    readonly property vector4d blob11: slotRect(11)
    readonly property vector4d blobRadius: Qt.vector4d(slotRadius(0), slotRadius(1), slotRadius(2), slotRadius(3))
    readonly property vector4d blobRadius2: Qt.vector4d(slotRadius(4), slotRadius(5), slotRadius(6), slotRadius(7))
    readonly property vector4d blobRadius3: Qt.vector4d(slotRadius(8), slotRadius(9), slotRadius(10), slotRadius(11))
    readonly property vector4d blobSmooth: Qt.vector4d(slotSmooth(0), slotSmooth(1), slotSmooth(2), slotSmooth(3))
    readonly property vector4d blobSmooth2: Qt.vector4d(slotSmooth(4), slotSmooth(5), slotSmooth(6), slotSmooth(7))
    readonly property vector4d blobSmooth3: Qt.vector4d(slotSmooth(8), slotSmooth(9), slotSmooth(10), slotSmooth(11))

    onPanelsChanged: if (panels.length > capacity)
        console.warn(`BlobField: ${panels.length} panels but only ${capacity} slots; the rest will not be drawn.`)

    fragmentShader: Qt.resolvedUrl("blob.frag.qsb")
}
