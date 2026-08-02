import QtQuick
import qs.config

// The workspace column's liquid. See beads.frag.
//
// Give it a rail, a list of beads and which one is active; it draws the smooth
// union of all of them and washes the accent out from the active one. Beads
// arrive as data and land in a fixed number of shader slots, because a uniform
// block cannot be a variable-length array. `capacity` is that limit; ask for
// more and the extras are dropped, loudly.
ShaderEffect {
    id: root

    readonly property int capacity: 10

    // [{ y, h, w, occupied }, ...] in this item's coordinates. Beads are centred
    // horizontally, so they carry no x.
    property var beads: []

    // x, y, w, h of the rail every bead grows out of.
    property vector4d rail: Qt.vector4d(0, 0, 0, 0)
    // The active bead, packed like the others: (y, h, w, occupied).
    property vector4d activeBead: Qt.vector4d(0, 0, 0, 0)
    // Where it was a moment ago. Melted into the active one, so the pair reads
    // as one bead stretching rather than two beads travelling.
    property vector4d trailBead: Qt.vector4d(0, 0, 0, 0)

    property color railColour: Appearance.colour.recess
    property color baseColour: Appearance.colour.fill
    property color strongColour: Appearance.colour.fillStrong
    property color accentColour: Appearance.colour.accentFill

    property real smoothing: Appearance.sizes.wsMelt
    property real feather: Appearance.sizes.meltFeather
    property real power: Appearance.rounding.power
    property real pad0: 0
    property real pad1: 0
    property real pad2: 0

    // The shader works in pixels, so it has to be told the size.
    readonly property vector4d size: Qt.vector4d(width, height, 0, 0)

    function slot(i: int): vector4d {
        const b = root.beads[i];
        return b ? Qt.vector4d(b.y, b.h, b.w, b.occupied ? 1 : 0) : Qt.vector4d(0, 0, 0, 0);
    }

    readonly property vector4d bead0: slot(0)
    readonly property vector4d bead1: slot(1)
    readonly property vector4d bead2: slot(2)
    readonly property vector4d bead3: slot(3)
    readonly property vector4d bead4: slot(4)
    readonly property vector4d bead5: slot(5)
    readonly property vector4d bead6: slot(6)
    readonly property vector4d bead7: slot(7)
    readonly property vector4d bead8: slot(8)
    readonly property vector4d bead9: slot(9)

    onBeadsChanged: if (beads.length > capacity)
        console.warn(`BeadField: ${beads.length} workspaces but only ${capacity} slots; the rest will not be drawn.`)

    fragmentShader: Qt.resolvedUrl("beads.frag.qsb")
}
