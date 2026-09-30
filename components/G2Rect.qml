import QtQuick
import QtQuick.Shapes
import qs.config
import "squircle.js" as Squircle

Item {
    id: root

    property real radius: Appearance.rounding.normal
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomRightRadius: radius
    property real bottomLeftRadius: radius

    property real cornerPower: Appearance.rounding.power

    property color color: "transparent"

    property color stroke: "transparent"
    property real strokeWidth: 0

    default property alias content: inner.data

    readonly property real inset: root.strokeWidth / 2

    function offset(r: real): real {
        return r < 0 ? r : Math.max(0, r - root.inset);
    }

    Shape {
        id: shape

        anchors.fill: parent
        anchors.margins: root.inset

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
