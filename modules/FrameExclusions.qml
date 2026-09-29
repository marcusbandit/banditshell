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
    // the band, and asks services/SidebarState.qml which screens mean that: on one
    // whose sidebar is hidden it carries the band alone, and the sidebar's width
    // goes back to the windows the moment the config says so.
    //
    // BARE reserves nothing at all (the keyboard excepted, because a docked
    // board is an input surface and not chrome): every edge drops to zero and
    // the windows take the whole screen. The keyboard keeps its room on the
    // same line as the band's MAX, which in bare collapses to the keyboard
    // alone.
    readonly property bool bare: Appearance.bare
    readonly property var reserve: ({
            top: root.bare ? 0 : Appearance.sizes.border,
            right: root.bare ? 0 : Appearance.sizes.border,
            bottom: root.bare ? root.keyboard : Math.max(Appearance.sizes.border, root.keyboard),
            left: root.bare ? 0 : Appearance.sizes.border + (SidebarState.visibleOn(root.screen?.name ?? "") ? Appearance.sizes.sidebarWidth : 0)
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
