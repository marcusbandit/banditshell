pragma ComponentBehavior: Bound

import Quickshell
import qs.config
import qs.services

// Space for the chassis, and for the tablet keyboard when it is docked.
//
// ShellWindow draws the chassis but cannot reserve room for it: a Wayland
// exclusive zone belongs to a surface anchored to ONE edge, and that window is
// anchored to all four. So these are four invisible one-edge surfaces whose only
// job is to say how much to keep clear.
//
// The compositor's own gap lands on top of what we reserve, so a window ends up
// that gap away from the chassis rather than jammed against it.
Scope {
    id: root

    required property ShellScreen screen

    // THE KEYBOARD REACHED THROUGH THE REGISTRY, not handed down.
    //
    // The board is drawn in ShellWindow and the room for it has to be reserved
    // here, and those two are siblings: neither can see the other, and threading
    // a reference through shell.qml would couple three files that otherwise have
    // nothing to say to each other. services/Shell.qml exists for exactly this,
    // and the lookup is by screen so a docked board on one monitor does not
    // shrink the windows on another.
    readonly property var win: Shell.forScreen(root.screen?.name ?? "")

    // Only while the board is BOTH open and docked. A floating board reserves
    // nothing, which is the whole difference between the two modes, and a docked
    // board that is closed would otherwise leave a strip of the screen
    // permanently unusable.
    readonly property int keyboard: root.win?.keyboard?.open && Tablet.docked ? root.win.keyboard.reserveHeight : 0

    // Edge -> how much it reserves. The left edge carries the sidebar as well as
    // the band; when the sidebar becomes toggleable, that entry drops back to
    // just the band while it is hidden.
    //
    // The bottom is a MAX rather than a sum: the board is drawn flush to the
    // screen's bottom edge, so it already covers the band's own strip. Adding
    // them would reserve that strip twice and leave a gap the width of the band
    // between the windows and the caps.
    readonly property var reserve: ({
            top: Appearance.sizes.border,
            right: Appearance.sizes.border,
            bottom: Math.max(Appearance.sizes.border, root.keyboard),
            left: Appearance.sizes.border + Appearance.sizes.sidebarWidth
        })

    Variants {
        model: ["top", "right", "bottom", "left"]

        PanelWindow {
            id: edge

            required property string modelData
            readonly property bool horizontal: modelData === "top" || modelData === "bottom"
            readonly property int size: root.reserve[modelData]

            screen: root.screen
            color: "transparent"

            anchors {
                top: edge.horizontal ? edge.modelData === "top" : true
                bottom: edge.horizontal ? edge.modelData === "bottom" : true
                left: edge.horizontal ? true : edge.modelData === "left"
                right: edge.horizontal ? true : edge.modelData === "right"
            }

            implicitWidth: edge.size
            implicitHeight: edge.size
            exclusiveZone: edge.size

            // Reserving space is the entire job. Nothing here is visible or
            // clickable.
            mask: Region {
                width: 0
                height: 0
            }
        }
    }
}
