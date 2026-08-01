import Quickshell
import Quickshell.Wayland
import qs.config

// The full-screen surface that hosts every summon zone.
//
// It is transparent and click-through except where `mask` says otherwise, so one
// window can own every edge zone and summon target on a screen. This is
// deliberately NOT one window per widget (see DESIGN.md section 7): the mask must
// stay contiguous, otherwise the cursor crosses dead pixels between a zone and
// the thing it summoned and the widget flickers away.
PanelWindow {
    id: win

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    // Reserve nothing, and ignore what others reserve. Without Ignore, the
    // sidebar's exclusive zone would shrink this surface and the ring would stop
    // hugging the physical screen edges.
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    readonly property int border: Appearance.sizes.border

    // The input region. Mask gates INPUT, opacity gates VISUALS: keep them apart.
    //
    //   whole screen
    //     MINUS the middle          -> a `border`-wide ring only the edges can hit
    //     PLUS the clock, when open -> so hovering it doesn't count as leaving
    mask: Region {
        width: win.width
        height: win.height

        Region {
            intersection: Intersection.Subtract
            x: win.border
            y: win.border
            width: win.width - win.border * 2
            height: win.height - win.border * 2
        }

        Region {
            intersection: Intersection.Combine
            item: topClock.active ? topClock.maskItem : null
        }
    }

    TopClock {
        id: topClock

        anchors.fill: parent
        border: win.border
    }
}
