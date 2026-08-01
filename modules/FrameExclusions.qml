pragma ComponentBehavior: Bound

import Quickshell
import qs.config

// Space for the chassis.
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

    // Edge -> how much it reserves. The left edge carries the sidebar as well as
    // the band; when the sidebar becomes toggleable, that entry drops back to
    // just the band while it is hidden.
    readonly property var reserve: ({
            top: Appearance.sizes.border,
            right: Appearance.sizes.border,
            bottom: Appearance.sizes.border,
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
