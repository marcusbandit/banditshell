import QtQuick
import QtQuick.Shapes
import qs.config
import "squircle.js" as Squircle

// One black corner piece, sized and shaped to the desktop's corner rounding.
//
// Four of these turn a rectangular display into a rounded one. It is the corner
// curve itself plus two straight runs back through the physical corner, using
// the same geometry as every other corner in the shell, so it matches the window
// rounding exactly rather than approximating it.
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
