import QtQuick
import QtQuick.Shapes
import qs.config
import "squircle.js" as Squircle

// The one rounded-rectangle primitive in this shell.
//
// Qt's Rectangle.radius is a plain circular arc (G1). This draws a G2-continuous
// squircle instead, so corners have no curvature jump. Nothing in myshell should
// use Rectangle.radius; route every rounded shape through here.
// See ~/.claude/rules/g2-corners.md.
Item {
    id: root

    // Positive radius = convex, the corner is cut off the bounding box.
    // Negative radius = CONCAVE, the side pulls in and the corner flares back out
    // to the bounding box, arriving tangent to the perpendicular edge. Use that
    // where a panel meets a screen edge so it sweeps into the edge.
    property real radius: Appearance.rounding.normal
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomRightRadius: radius
    property real bottomLeftRadius: radius

    // How far a corner of this radius reaches along each of its sides. A concave
    // corner needs this to know how much extra width to reserve for the flare.
    function cornerExtent(r: real): real {
        return Squircle.extent(r, cornerSmoothing);
    }

    // 0 = plain rounded rect, 0.6 = iOS squircle, 1 = maximum smoothing.
    property real cornerSmoothing: Appearance.rounding.smoothing

    // Surfaces are lit, not flat: `color` is the top of a vertical gradient and
    // `colorBottom` the bottom. Leave colorBottom alone for a flat fill.
    // Lighter at the top reads as RAISED, darker at the top reads as RECESSED,
    // which is the entire depth vocabulary.
    property color color: "transparent"
    property color colorBottom: color

    // A hairline stroke along the whole contour. On a panel flush to a screen
    // edge only the free edge is visible, which is exactly where light would
    // catch it.
    property color borderColor: "transparent"
    property real borderWidth: 0

    // Children declared inside a G2Rect land in `inner`, on top of the shape.
    default property alias content: inner.data

    Shape {
        anchors.fill: parent
        // Qt 6.6+ curve renderer: proper antialiasing without a multisample layer.
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.borderWidth > 0 ? root.borderColor : "transparent"
            strokeWidth: root.borderWidth

            fillGradient: LinearGradient {
                x1: 0
                y1: 0
                x2: 0
                y2: Math.max(1, root.height)

                GradientStop {
                    position: 0
                    color: root.color
                }
                GradientStop {
                    position: 1
                    color: root.colorBottom
                }
            }

            PathSvg {
                path: Squircle.path(root.width, root.height, root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius, root.cornerSmoothing)
            }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
