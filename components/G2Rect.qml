import QtQuick
import QtQuick.Shapes
import qs.config
import "squircle.js" as Squircle

// The one rounded-rectangle primitive in this shell.
//
// Qt's Rectangle.radius is a plain circular arc (G1). This draws a G2-continuous
// squircle instead, so corners have no curvature jump. Nothing in banditshell
// should use Rectangle.radius; route every rounded shape through here.
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

    // The corner's superellipse exponent, |x|^n + |y|^n = r^n. 2 is a plain
    // circular arc, 4 is what the compositor rounds windows with here, 5 is
    // Apple's. It is the SAME number the chassis field uses, because they are the
    // same curve: see components/squircle.js.
    property real cornerPower: Appearance.rounding.power

    property color color: "transparent"

    // AN OUTLINE, for a shape that is a CONTROL rather than part of the body.
    //
    // This used to say "fill only, no stroke", and the reason still holds for
    // everything the chassis is made of: every hairline this shell tried to draw
    // on a body's own contour landed on a join with another shape and read as a
    // seam through one object (see Chassis.qml). A ring around a button joins
    // nothing, and it is the one way to draw a control that has a boundary
    // without painting a solid disc that shouts.
    //
    // Stroked INSIDE the item's bounds rather than centred on the path, which is
    // Qt's default: a ring is laid out as a target, and half of it hanging
    // outside the box it was given makes every layout around it wrong by a
    // pixel.
    property color stroke: "transparent"
    property real strokeWidth: 0

    // Children declared inside a G2Rect land in `inner`, on top of the shape.
    default property alias content: inner.data

    // Half the stroke, which is how far the drawn curve moves in to keep the
    // whole of it inside the item. An offset curve is the radius less the same
    // distance; a concave corner is left alone, because it is a flare into a
    // screen edge and nothing there is ever stroked.
    readonly property real inset: root.strokeWidth / 2

    function offset(r: real): real {
        return r < 0 ? r : Math.max(0, r - root.inset);
    }

    Shape {
        id: shape

        anchors.fill: parent
        anchors.margins: root.inset
        // Qt 6.6+ curve renderer: proper antialiasing without a multisample layer.
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
