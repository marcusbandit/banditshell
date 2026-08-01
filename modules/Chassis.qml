import QtQuick
import QtQuick.Shapes
import qs.config
import "../components/squircle.js" as Squircle

// The shell's body: the band around the screen and the sidebar slab, as ONE
// shape.
//
// They are not two panels sitting next to each other. They are what is left when
// the content area is cut out of the screen, which is why there is no seam, no
// doubled translucency, and one continuous contour to round.
//
// The cutout's corners say what each edge is:
//   RIGHT corners  - the window corner radius, so the chassis hugs the windows.
//   LEFT corners   - the flare radius, which is the sidebar's free edge sweeping
//                    outward to meet the band at top and bottom. Concave on the
//                    sidebar is the same curve as convex on the hole.
Item {
    id: root

    // The band, and the sidebar's width beyond it.
    readonly property real band: Appearance.sizes.border
    readonly property real barWidth: band + Appearance.sizes.sidebarWidth

    readonly property real holeX: barWidth
    readonly property real holeY: band
    readonly property real holeWidth: width - barWidth - band
    readonly property real holeHeight: height - band * 2

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: Appearance.colour.surface
            strokeColor: Appearance.colour.separator
            strokeWidth: 1
            // The inner subpath is a hole, not a second filled shape.
            fillRule: ShapePath.OddEvenFill

            PathSvg {
                path: Squircle.cutoutPath(root.width, root.height, root.holeX, root.holeY, root.holeWidth, root.holeHeight, Appearance.sizes.sidebarFlare, Appearance.rounding.base, Appearance.rounding.base, Appearance.sizes.sidebarFlare, Appearance.rounding.smoothing)
            }
        }
    }
}
