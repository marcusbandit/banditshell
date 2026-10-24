import QtQuick
import QtQuick.Shapes
import qs.config
import "squircle.js" as Squircle

Item {
    id: root

    property string pill: ""

    property real radius: root.pill !== "" ? Math.min(root.width, root.height) / 2 : Appearance.rounding.normal
    property real topLeftRadius: radius
    property real topRightRadius: radius
    property real bottomRightRadius: radius
    property real bottomLeftRadius: radius

    property real cornerPower: root.pill === "object" ? 2 : Appearance.rounding.power

    property color color: "transparent"

    property color stroke: "transparent"
    property real strokeWidth: 0

    default property alias content: inner.data

    property bool shaded: true

    readonly property bool drawn: root.color.a > 0 || (root.strokeWidth > 0 && root.stroke.a > 0)

    readonly property real inset: root.strokeWidth / 2
    readonly property bool onShader: root.shaded && root.topLeftRadius >= 0 && root.topRightRadius >= 0 && root.bottomRightRadius >= 0 && root.bottomLeftRadius >= 0

    function offset(r: real): real {
        return r < 0 ? r : Math.max(0, r - root.inset);
    }

    Loader {
        id: drawing

        active: root.drawn || drawing.item !== null
        sourceComponent: root.onShader ? fill : outline
    }

    Component {
        id: fill

        ShaderEffect {
            x: -bleed
            y: -bleed
            width: root.width + bleed * 2
            height: root.height + bleed * 2
            visible: root.drawn

            property real power: root.cornerPower
            property real bleed: 1
            property real across: root.width
            property real down: root.height
            property real rim: root.strokeWidth
            property vector4d radii: Qt.vector4d(root.topLeftRadius, root.topRightRadius, root.bottomRightRadius, root.bottomLeftRadius)
            property color colour: root.color
            property color line: root.stroke

            fragmentShader: "squirclefill.frag.qsb"
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

            visible: root.drawn
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
