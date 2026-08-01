import QtQuick
import qs.config

// The shell's body, drawn as one signed distance field.
//
// Give it the CUTOUT (the content area it is left around) and a list of open
// panels. It draws everything that is not the cutout, smooth-unioned with each
// panel, so a panel near the body melts into it and the fillet grows and shrinks
// by itself as the panel moves. See blob.frag.
//
// Panels arrive as data and land in a fixed number of shader slots, because a
// uniform block cannot be a variable-length array. `capacity` is that limit; ask
// for more and the extras are dropped, loudly.
ShaderEffect {
    id: root

    readonly property int capacity: 8

    // [{ x, y, w, h, radius }, ...] in this item's coordinates. A zero width
    // means nothing is drawn for that slot, which is how a closed panel costs
    // nothing rather than leaving a stub behind.
    property var panels: []

    property color colour: Appearance.colour.surface
    // How wide the melt is, in pixels. 0 gives a hard crease.
    property real smoothing: Appearance.sizes.melt
    property real feather: Appearance.sizes.meltFeather

    // Superellipse exponent. 2 is circular; the compositor's own
    // `rounding_power` is what makes these corners the same curve as the windows
    // they frame rather than merely the same radius.
    property real power: Appearance.rounding.power

    // The content area, and the BASE curve's radii packed the way blob.frag
    // wants: (bottomRight, topRight, bottomLeft, topLeft).
    //
    // The radii are the WINDOW's, not the chassis's. Everything the chassis
    // draws is that curve offset outwards, so there is exactly one radius in the
    // system and the rest are distances.
    property vector4d content: Qt.vector4d(0, 0, 0, 0)
    property vector4d baseRadius: Qt.vector4d(0, 0, 0, 0)

    property real gap: Appearance.sizes.gap
    property real band: Appearance.sizes.band
    property real pad0: 0
    property bool frameOn: Appearance.sizes.roundOuter
    property color frameColour: Appearance.colour.frame

    // A hard edge exactly on the content boundary. 0 draws none.
    property real outlineWidth: 0
    property color outlineColour: Appearance.colour.accent
    property real pad1: 0
    property real pad2: 0
    property real pad3: 0

    // The shader works in pixels, so it has to be told the size.
    readonly property vector4d size: Qt.vector4d(width, height, 0, 0)

    function slotRect(i: int): vector4d {
        const p = root.panels[i];
        return p ? Qt.vector4d(p.x, p.y, p.w, p.h) : Qt.vector4d(0, 0, 0, 0);
    }

    function slotRadius(i: int): real {
        return root.panels[i]?.radius ?? 0;
    }

    readonly property vector4d blob0: slotRect(0)
    readonly property vector4d blob1: slotRect(1)
    readonly property vector4d blob2: slotRect(2)
    readonly property vector4d blob3: slotRect(3)
    readonly property vector4d blob4: slotRect(4)
    readonly property vector4d blob5: slotRect(5)
    readonly property vector4d blob6: slotRect(6)
    readonly property vector4d blob7: slotRect(7)
    readonly property vector4d blobRadius: Qt.vector4d(slotRadius(0), slotRadius(1), slotRadius(2), slotRadius(3))
    readonly property vector4d blobRadius2: Qt.vector4d(slotRadius(4), slotRadius(5), slotRadius(6), slotRadius(7))

    onPanelsChanged: if (panels.length > capacity)
        console.warn(`BlobField: ${panels.length} panels but only ${capacity} slots; the rest will not be drawn.`)

    fragmentShader: Qt.resolvedUrl("blob.frag.qsb")
}
