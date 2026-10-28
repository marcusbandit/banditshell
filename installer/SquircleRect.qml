import QtQuick
import QtQuick.Shapes
import "squircle.js" as Squircle
import "theme.js" as Theme

Item {
    id: root

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

    readonly property real inset: root.strokeWidth / 2
    readonly property bool onShader: root.topLeftRadius >= 0 && root.topRightRadius >= 0 && root.bottomRightRadius >= 0 && root.bottomLeftRadius >= 0

    function offset(r: real): real {
        return r < 0 ? r : Math.max(0, r - root.inset);
    }

    Loader {
        sourceComponent: root.onShader ? fill : outline
    }

    Component {
        id: fill

        ShaderEffect {
            x: -bleed
            y: -bleed
            width: root.width + bleed * 2
            height: root.height + bleed * 2

            property real power: root.cornerPower
            property real bleed: 1
            property real across: root.width
            property real down: root.height
            property real rim: root.strokeWidth
            property vector4d radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
            property color colour: root.color
            property color line: root.stroke

            fragmentShader: Qt.resolvedUrl("../components/squirclefill.frag.qsb")
        }
    }

    Component {
        id: outline

        Shape {
            id: shape

            x: root.inset
            y: root.inset
            width: Math.max(0, root.width - root.inset * 2)
            height: Math.max(0, root.height - root.inset * 2)

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
