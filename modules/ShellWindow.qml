pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.modules.sidebar

// The shell. One surface per screen, and everything the shell draws lives in it.
//
// This is deliberately NOT one window per panel. The chassis (the band around
// the screen plus the sidebar) is a single shape, so two translucent panels can
// never overlap and double their opacity, and the whole contour rounds as one
// object. Summoned widgets join the same surface, which is also what keeps the
// input mask contiguous: the cursor can travel from an edge zone into the thing
// it summoned without crossing dead pixels and dismissing it.
//
// It is on the TOP layer, not Overlay. The chassis is part of the shell, not a
// decoration floating over the desktop, and it should give way to a fullscreen
// window the way a bar does.
//
// It reserves nothing itself: FrameExclusions does that, because an exclusive
// zone belongs to a surface anchored to one edge and this is anchored to four.
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

    // The compositor blurs this surface by name. Without that the chassis is a
    // flat translucent wash; with it, it is a material. See the myshell
    // layerrule in ~/.config/hypr/hyprland/rules.conf.
    WlrLayershell.namespace: "myshell"

    readonly property int border: Appearance.sizes.border

    // Mask gates INPUT, opacity gates VISUALS: keep them apart.
    //
    // The interactive region is exactly the chassis: everything except the
    // content area. That is the band and the sidebar in one contiguous piece, so
    // every edge is a summon zone and the sidebar is reachable, with nothing in
    // between that would drop the cursor.
    mask: Region {
        width: win.width
        height: win.height

        Region {
            intersection: Intersection.Subtract
            x: chassis.holeX
            y: chassis.holeY
            width: chassis.holeWidth
            height: chassis.holeHeight
        }

        Region {
            intersection: Intersection.Combine
            item: topClock.active ? topClock.maskItem : null
        }
    }

    Chassis {
        id: chassis
        anchors.fill: parent
    }

    // Sidebar contents, laid out in the chassis's left band. The band is one
    // material, so the content centres in the whole of it rather than in some
    // inner rectangle.
    Sidebar {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.topMargin: win.border
        anchors.bottomMargin: win.border
        width: chassis.barWidth
    }

    TopClock {
        id: topClock

        anchors.fill: parent
        border: win.border
    }

    // Black pieces rounding off the physical screen corners. Opaque, so they can
    // sit on top of the chassis without blending trouble.
    //
    // The radius is the window radius PLUS the band thickness, which makes the
    // outside of the frame concentric with the windows inside it. Corners that
    // are not concentric are the usual reason a frame looks subtly wrong.
    Repeater {
        model: Appearance.sizes.roundOuter ? ["tl", "tr", "br", "bl"] : []

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
