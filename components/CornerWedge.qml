import QtQuick
import QtQuick.Shapes
import qs.config
import "squircle.js" as Squircle

// The bit of a square corner that a rounded shape leaves over: a corner curve
// plus two straight runs back through the corner point.
//
// Two jobs, same shape:
//
//   FILLING IN  - four of these in black at the screen corners turn a
//                 rectangular display into a rounded one.
//   JOINING     - one in the panel material where two panels meet at a right
//                 angle fillets the join, so they read as one body separating
//                 rather than two rectangles touching.
//
// It uses the same corner geometry as everything else, so it matches exactly
// rather than approximating.
Item {
    id: root

    // "tl" | "tr" | "br" | "bl"
    required property string corner

    property real radius: Appearance.rounding.normal
    property real cornerSmoothing: Appearance.rounding.smoothing
    property color color: "black"

    readonly property real extent: Squircle.extent(radius, cornerSmoothing)

    implicitWidth: extent
    implicitHeight: extent

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeWidth: 0
            strokeColor: "transparent"

            PathSvg {
                path: Squircle.cornerPatch(root.radius, root.cornerSmoothing, root.corner)
            }
        }
    }
}
