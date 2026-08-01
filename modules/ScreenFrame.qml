pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components

// Rounds the corners of the display itself.
//
// Four black pieces filling what a rounded desktop leaves over at the physical
// screen corners, so the whole desktop reads as a framed panel rather than a
// rectangle that happens to end. Matches the compositor's own rounding, so the
// frame and the windows inside it agree.
//
// Its own surface, for two reasons. It must sit ABOVE everything including the
// sidebar, or the sidebar's flare would cover the two left corners. And it must
// take no input at all: the mask is empty, so every click falls straight
// through. Pure decoration, no behaviour.
PanelWindow {
    id: win

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    // Above fullscreen windows: the frame is the frame, always.
    WlrLayershell.layer: WlrLayer.Overlay

    // Empty input region. Nothing here is clickable, ever.
    mask: Region {
        width: 0
        height: 0
    }

    // Positions computed from the corner key, so there is one piece of code
    // rather than four hand-placed items.
    Repeater {
        model: ["tl", "tr", "br", "bl"]

        delegate: ScreenCorner {
            required property string modelData

            corner: modelData
            radius: Appearance.sizes.outerRadius
            color: Appearance.colour.frame

            x: modelData === "tr" || modelData === "br" ? win.width - extent : 0
            y: modelData === "bl" || modelData === "br" ? win.height - extent : 0
        }
    }
}
