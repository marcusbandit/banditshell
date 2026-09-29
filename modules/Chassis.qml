import QtQuick
import Quickshell
import qs.config
import qs.components.blob
import qs.services

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

    // WHICH DISPLAY THIS CHASSIS IS ON, by output name, and WHETHER THE SIDEBAR
    // IS PART OF THE SHAPE THERE.
    //
    // Asked of the surface itself rather than handed down like `panels` below,
    // and the difference is what kind of fact the screen is: the screen is the
    // window's IDENTITY, and Quickshell attaches that to every item inside it
    // (modules/sidebar/Sidebar.qml makes this same argument at length). Nothing
    // above has to remember to pass it, and it cannot be passed wrong - which
    // is also why the LOCK gets this for free: LockFace instantiates this very
    // component on its own surface, and a monitor whose sidebar is hidden is
    // drawn that way with the machine locked too, because the machine still
    // looks like itself.
    //
    // Empty for the frame before the item is in a window (a preview harness),
    // and empty resolves to the default, which is the sidebar on.
    readonly property string screen: QsWindow.window?.screen?.name ?? ""

    // BARE outranks everything below it: no band, no sidebar, no hole inset.
    // The field becomes a full-screen hole with a zero inset and zero radius,
    // which is the one shape that draws nothing anywhere, and the frame's
    // screen-corner pieces go with it (they are border, by another name).
    readonly property bool bare: Appearance.bare
    readonly property bool sidebar: !root.bare && SidebarState.visibleOn(root.screen)

    // The band, and the sidebar's width beyond it. WITHOUT the sidebar the left
    // edge is the other three edges: the band alone, and the hole starting one
    // band in. Everything downstream of `barWidth` - the hole below, every
    // panel's `originX` in ShellWindow, the lock face's centring - moves with
    // it, because none of them restate the sum.
    readonly property real band: root.bare ? 0 : Appearance.sizes.border
    readonly property real barWidth: root.sidebar ? root.band + Appearance.sizes.sidebarWidth : root.band

    // The content area: what the shell is drawn around.
    readonly property real holeX: barWidth
    readonly property real holeY: band
    readonly property real holeWidth: width - barWidth - band
    readonly property real holeHeight: height - band * 2

    // THE RADIUS THE LEFT INNER CURVE ENDS UP AT: the sidebar's flare while the
    // sidebar is part of the shape, and the window's own radius when it is not,
    // which is what makes the hidden case the right edge's twin. Read as the
    // radius the OFFSET should end up at, per the note on `baseRadius` below.
    // Bare never reads it: the whole base curve is zeroed below.
    readonly property real leftFlare: root.sidebar ? Appearance.sizes.sidebarFlare : Appearance.sizes.windowRadius

    // Open panels, as blobs. Fed in from outside, so this file does not need to
    // know what a menu is.
    property var panels: []

    BlobField {
        anchors.fill: parent

        panels: root.panels

        content: Qt.vector4d(root.holeX, root.holeY, root.holeWidth, root.holeHeight)

        // BARE: with the hole at the full window, the inset that rounds the
        // hole's corners has to go too, or the field keeps filling the slivers
        // between a rounded hole and the screen's own square corners - four
        // patches of panel material painted over the wallpaper's corners, the
        // one piece of chrome this mode exists to lose. Zero inset and zero
        // radius is the only hole that draws nothing at all.
        gap: root.bare ? 0 : Appearance.sizes.gap

        // The BASE curve's radii, in (bottomRight, topRight, bottomLeft,
        // topLeft) order. On the right this is the window's own outer radius,
        // and the chassis's inner edge is that curve offset by the gap, so it
        // cups a window corner at a constant distance instead of merely being a
        // bigger radius near it.
        //
        // The left pair has no window behind it, only the sidebar, so the flare
        // is a design choice: given as the radius the OFFSET should end up at.
        // With the sidebar away there is nothing for a flare to be about, and
        // the left edge becomes the right edge's twin - the window's own radius,
        // the same offset, cupping nothing.
        baseRadius: root.bare ? Qt.vector4d(0, 0, 0, 0) : Qt.vector4d(Appearance.sizes.windowRadius, Appearance.sizes.windowRadius, Math.max(0, root.leftFlare - Appearance.sizes.gap), Math.max(0, root.leftFlare - Appearance.sizes.gap))

        // AND THE SCREEN-CORNER FRAME, which is border by another name: black
        // pieces rounding the physical corners off. Bare is bare.
        frameOn: Appearance.sizes.roundOuter && !root.bare ? 1 : 0
    }
}
