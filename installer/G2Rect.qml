import QtQuick
import QtQuick.Shapes
import "squircle.js" as Squircle
import "theme.js" as Theme

// The installer's only rounded-rectangle primitive, and the only one it is
// allowed to have.
//
// Qt's Rectangle.radius is a plain circular arc: G1, the curvature jumps from 0
// to 1/r the instant the straight edge ends, and the eye catches that as a pinch
// at every corner. This draws the superellipse instead, |x|^n + |y|^n = r^n, the
// same curve components/squircle.js gives the rest of the shell and the same one
// the compositor rounds windows with, so a panel the installer draws and a window
// beside it are the same shape.
//
// `Rectangle` with a radius does not appear anywhere in this directory. If a
// corner in here is not coming through this file, that is a bug.
// See ~/.claude/rules/g2-corners.md.
Item {
    id: root

    // Positive is convex. NEGATIVE is concave: the side pulls in and flares back
    // out to the bounding box tangent to the perpendicular edge, which is how a
    // panel sweeps into a screen edge instead of stopping at it.
    property real radius: Theme.rNormal
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomRightRadius: radius
    property real bottomLeftRadius: radius

    property real cornerPower: Theme.power
    property color color: "transparent"

    property color stroke: "transparent"
    property real strokeWidth: 0

    default property alias content: inner.data

    // Stroked INSIDE the bounds rather than centred on the path, so a ring laid
    // out as a target does not hang half a stroke outside the box it was given.
    readonly property real inset: root.strokeWidth / 2

    function offset(r: real): real {
        return r < 0 ? r : Math.max(0, r - root.inset);
    }

    Shape {
        id: shape

        anchors.fill: parent
        anchors.margins: root.inset
        // The curve renderer, so the corners antialias without a multisample
        // layer under them.
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            strokeColor: root.stroke
            strokeWidth: root.strokeWidth

            PathSvg {
                path: Squircle.path(shape.width, shape.height, root.offset(root.topLeftRadius), root.offset(root.topRightRadius), root.offset(root.bottomRightRadius), root.offset(root.bottomLeftRadius), root.cornerPower)
            }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
