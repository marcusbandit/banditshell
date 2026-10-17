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

    property bool shaded: true

    readonly property real inset: root.strokeWidth / 2
    readonly property bool onShader: root.shaded && root.topLeftRadius >= 0 && root.topRightRadius >= 0 && root.bottomRightRadius >= 0 && root.bottomLeftRadius >= 0

    function offset(r: real): real {
        return r < 0 ? r : Math.max(0, r - root.inset);
    }

    Loader {
        readonly property real fringe: 1

        x: -fringe
        y: -fringe
        width: root.width + fringe * 2
        height: root.height + fringe * 2
        active: root.onShader

        sourceComponent: ShaderEffect {
            visible: root.color.a > 0 || (root.strokeWidth > 0 && root.stroke.a > 0)

            property real power: root.cornerPower
            property real bleed: parent.fringe
            property real across: root.width
            property real down: root.height
            property real rim: root.strokeWidth
            property vector4d radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
            property color colour: root.color
            property color line: root.stroke

            fragmentShader: Qt.resolvedUrl("squirclefill.frag.qsb")
        }
    }

    Loader {
        anchors.fill: parent
        active: !root.onShader

        sourceComponent: Shape {
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
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
