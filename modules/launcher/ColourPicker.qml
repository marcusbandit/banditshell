pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components
import "../../components/squircle.js" as Squircle
import "../../services/colours.js" as Colours

Item {
    id: root

    property string seed: ""

    property real hue: 0
    property real saturation: 0
    property real lightness: 0
    property real alpha: 1

    readonly property color colour: Qt.hsla(root.hue, root.saturation, root.lightness, root.alpha)
    readonly property var channels: ({
            r: root.colour.r * 255,
            g: root.colour.g * 255,
            b: root.colour.b * 255,
            a: root.alpha
        })
    readonly property string hex: Colours.hexOf(root.channels)

    signal picked(string hex, bool done)

    readonly property real wheel: Math.round(root.width * 0.42)
    readonly property real band: Math.round(root.wheel * 0.09)
    readonly property real centre: root.wheel / 2
    readonly property real inner: root.centre - root.band
    readonly property real side: Math.floor((root.inner - Appearance.padding.small) * Math.SQRT2)
    readonly property real marker: root.band + Appearance.padding.small

    implicitHeight: Math.max(root.wheel, values.implicitHeight)

    onSeedChanged: root.take(root.seed)
    Component.onCompleted: root.take(root.seed)

    function same(a: color, b: color): bool {
        return [a.r - b.r, a.g - b.g, a.b - b.b, a.a - b.a].every(d => Math.abs(d) < 0.5 / 255);
    }

    function take(text: string): void {
        if (!text)
            return;
        const c = Qt.color(text);
        if (root.same(c, root.colour))
            return;
        settle.stop();
        if (c.hslHue >= 0)
            root.hue = c.hslHue;
        root.saturation = c.hslSaturation;
        root.lightness = c.hslLightness;
        root.alpha = c.a;
    }

    function change(h: real, s: real, l: real): void {
        root.hue = Math.max(0, Math.min(1, h));
        root.saturation = Math.max(0, Math.min(1, s));
        root.lightness = Math.max(0, Math.min(1, l));
        root.picked(root.hex, false);
        settle.restart();
    }

    function angleOf(h: real): real {
        return (90 + h * 360) * Math.PI / 180;
    }

    function hueAt(x: real, y: real): real {
        const degrees = Math.atan2(root.centre - y, x - root.centre) * 180 / Math.PI;
        return (((degrees - 90) % 360) + 360) % 360 / 360;
    }

    Timer {
        id: settle

        interval: 250
        onTriggered: root.picked(root.hex, true)
    }

    Item {
        id: ring

        width: root.wheel
        height: root.wheel
        anchors.verticalCenter: parent.verticalCenter

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill
                fillGradient: ConicalGradient {
                    centerX: root.centre
                    centerY: root.centre
                    angle: 90

                    GradientStop {
                        position: 0
                        color: Qt.hsla(0, 1, 0.5, 1)
                    }
                    GradientStop {
                        position: 1 / 6
                        color: Qt.hsla(1 / 6, 1, 0.5, 1)
                    }
                    GradientStop {
                        position: 2 / 6
                        color: Qt.hsla(2 / 6, 1, 0.5, 1)
                    }
                    GradientStop {
                        position: 3 / 6
                        color: Qt.hsla(3 / 6, 1, 0.5, 1)
                    }
                    GradientStop {
                        position: 4 / 6
                        color: Qt.hsla(4 / 6, 1, 0.5, 1)
                    }
                    GradientStop {
                        position: 5 / 6
                        color: Qt.hsla(5 / 6, 1, 0.5, 1)
                    }
                    GradientStop {
                        position: 1
                        color: Qt.hsla(0, 1, 0.5, 1)
                    }
                }

                PathAngleArc {
                    centerX: root.centre
                    centerY: root.centre
                    radiusX: root.centre
                    radiusY: root.centre
                    startAngle: 0
                    sweepAngle: 360
                }

                PathAngleArc {
                    moveToStart: true
                    centerX: root.centre
                    centerY: root.centre
                    radiusX: root.inner
                    radiusY: root.inner
                    startAngle: 0
                    sweepAngle: 360
                }
            }
        }

        Item {
            id: plane

            readonly property string outline: Squircle.path(plane.width, plane.height, Appearance.rounding.small, Appearance.rounding.small, Appearance.rounding.small, Appearance.rounding.small, Appearance.rounding.power)

            anchors.centerIn: parent
            width: root.side
            height: root.side

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: plane.width
                        y2: 0

                        GradientStop {
                            position: 0
                            color: Qt.hsla(0, 0, 0.5, 1)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.hsla(root.hue, 1, 0.5, 1)
                        }
                    }

                    PathSvg {
                        path: plane.outline
                    }
                }

                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: LinearGradient {
                        x1: 0
                        y1: 0
                        x2: 0
                        y2: plane.height

                        GradientStop {
                            position: 0
                            color: Qt.rgba(1, 1, 1, 1)
                        }
                        GradientStop {
                            position: 0.5
                            color: Qt.rgba(1, 1, 1, 0)
                        }
                        GradientStop {
                            position: 0.5
                            color: Qt.rgba(0, 0, 0, 0)
                        }
                        GradientStop {
                            position: 1
                            color: Qt.rgba(0, 0, 0, 1)
                        }
                    }

                    PathSvg {
                        path: plane.outline
                    }
                }
            }
        }

        SquircleRect {
            x: plane.x + root.saturation * plane.width - width / 2
            y: plane.y + (1 - root.lightness) * plane.height - height / 2
            width: root.marker
            height: root.marker
            pill: "object"
            color: Qt.hsla(root.hue, root.saturation, root.lightness, 1)
            stroke: root.lightness > 0.6 ? Appearance.chosenTheme.ramp[0] : Appearance.withAlpha(Appearance.chosenTheme.ramp[10], Appearance.labelAlphas[0])
            strokeWidth: 2
        }

        SquircleRect {
            x: root.centre + (root.centre - root.band / 2) * Math.cos(root.angleOf(root.hue)) - width / 2
            y: root.centre - (root.centre - root.band / 2) * Math.sin(root.angleOf(root.hue)) - height / 2
            width: root.marker
            height: root.marker
            pill: "object"
            color: Qt.hsla(root.hue, 1, 0.5, 1)
            stroke: Appearance.colour.text
            strokeWidth: 2
        }

        MouseArea {
            id: pointer

            property string grabbed: ""

            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.CrossCursor

            function follow(x: real, y: real): void {
                if (pointer.grabbed === "hue")
                    root.change(root.hueAt(x, y), root.saturation, root.lightness);
                else if (pointer.grabbed === "plane")
                    root.change(root.hue, (x - plane.x) / plane.width, 1 - (y - plane.y) / plane.height);
            }

            onPressed: mouse => {
                const reach = Math.hypot(mouse.x - root.centre, mouse.y - root.centre);
                pointer.grabbed = reach >= root.inner - Appearance.padding.small && reach <= root.centre + Appearance.padding.small ? "hue" : mouse.x >= plane.x && mouse.x <= plane.x + plane.width && mouse.y >= plane.y && mouse.y <= plane.y + plane.height ? "plane" : "";
                mouse.accepted = pointer.grabbed !== "";
                pointer.follow(mouse.x, mouse.y);
            }
            onPositionChanged: mouse => pointer.follow(mouse.x, mouse.y)
            onReleased: pointer.grabbed = ""
        }
    }

    Column {
        id: values

        x: root.wheel + Appearance.padding.large
        width: root.width - x
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.small

        Repeater {
            model: [
                {
                    name: "H",
                    value: () => root.hue,
                    text: () => `${Math.round(root.hue * 360)}°`,
                    set: v => root.change(v, root.saturation, root.lightness)
                },
                {
                    name: "S",
                    value: () => root.saturation,
                    text: () => `${Math.round(root.saturation * 100)}%`,
                    set: v => root.change(root.hue, v, root.lightness)
                },
                {
                    name: "L",
                    value: () => root.lightness,
                    text: () => `${Math.round(root.lightness * 100)}%`,
                    set: v => root.change(root.hue, root.saturation, v)
                }
            ]

            delegate: Item {
                id: level

                required property var modelData

                width: values.width
                height: Math.max(name.implicitHeight, slider.implicitHeight)

                StyledText {
                    id: name

                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.font.size.normal * 1.5
                    text: level.modelData.name
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textFaint
                }

                Slider {
                    id: slider

                    anchors.left: name.right
                    anchors.right: amount.left
                    anchors.rightMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    step: 0.01
                    value: level.modelData.value()
                    onMoved: v => level.modelData.set(v)
                }

                StyledText {
                    id: amount

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: Appearance.font.size.small * 3
                    horizontalAlignment: Text.AlignRight
                    text: level.modelData.text()
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textDim
                }
            }
        }

        Item {
            width: values.width
            height: Appearance.padding.small
        }

        Row {
            spacing: Appearance.padding.normal

            SquircleRect {
                anchors.verticalCenter: parent.verticalCenter
                width: Appearance.sizes.launcherIcon
                height: Appearance.sizes.launcherIcon
                radius: Appearance.rounding.small
                color: root.colour
                stroke: Appearance.colour.seam
                strokeWidth: Appearance.sizes.seam
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.hex
                font.pixelSize: Appearance.font.size.normal
                color: Appearance.colour.text
            }
        }

        StyledText {
            width: values.width
            text: Colours.rgbOf(root.channels)
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
        }

        StyledText {
            width: values.width
            text: Colours.hslOf(root.channels)
            elide: Text.ElideRight
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
        }
    }
}
