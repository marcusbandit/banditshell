import QtQuick
import qs.config
import qs.components.blob

// The shell's body: the band around the screen, the sidebar slab, and every open
// panel, as ONE field.
//
// REWRITTEN 2026-08-01. It used to be one vector path with the content area cut
// out of it, and panels were separate shapes placed exactly against its edge with
// hand-built fillets at the joins. That got the picture roughly right and was a
// hack: the join was two shapes agreeing to touch, so it could not blend, could
// not react to the panel moving, and left a seam anywhere the agreement slipped.
//
// Now it is a signed distance field combined with a SMOOTH minimum. Where a
// panel comes near the body the two fields blend, and the fillet grows and
// shrinks by itself as the panel moves. Nothing places a joint; the melt is a
// property of the field. See components/blob/blob.frag.
//
// The bar is not a separate object at all: the cutout simply starts further in on
// the left, and whatever is left over IS the bar. There is no join to get right
// because there is no join.
Item {
    id: root

    // The band, and the sidebar's width beyond it.
    readonly property real band: Appearance.sizes.border
    readonly property real barWidth: band + Appearance.sizes.sidebarWidth

    // The content area: what the shell is drawn around.
    readonly property real holeX: barWidth
    readonly property real holeY: band
    readonly property real holeWidth: width - barWidth - band
    readonly property real holeHeight: height - band * 2

    // Open panels, as blobs. Fed in from outside, so this file does not need to
    // know what a menu is.
    property var panels: []

    BlobField {
        anchors.fill: parent

        panels: root.panels

        frame: Qt.vector4d(root.holeX, root.holeY, root.holeWidth, root.holeHeight)
        // (bottomRight, topRight, bottomLeft, topLeft). The right corners are the
        // window radius, so the chassis hugs the windows. The left ones are
        // bigger: that is the sidebar's edge sweeping into the band. They are
        // corners of the CUTOUT, so they read as concave on the body.
        frameRadius: Qt.vector4d(Appearance.rounding.base, Appearance.rounding.base, Appearance.sizes.sidebarFlare, Appearance.sizes.sidebarFlare)
    }
}
