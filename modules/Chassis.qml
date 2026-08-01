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

        content: Qt.vector4d(root.holeX, root.holeY, root.holeWidth, root.holeHeight)

        // The BASE curve's radii, in (bottomRight, topRight, bottomLeft,
        // topLeft) order. On the right this is the window's own outer radius,
        // and the chassis's inner edge is that curve offset by the gap, so it
        // cups a window corner at a constant distance instead of merely being a
        // bigger radius near it.
        //
        // The left pair has no window behind it, only the sidebar, so the flare
        // is a design choice: given as the radius the OFFSET should end up at.
        baseRadius: Qt.vector4d(Appearance.sizes.windowRadius, Appearance.sizes.windowRadius, Math.max(0, Appearance.sizes.sidebarFlare - Appearance.sizes.gap), Math.max(0, Appearance.sizes.sidebarFlare - Appearance.sizes.gap))
    }
}
