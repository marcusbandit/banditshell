pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "keyframes.js" as Frames

SceneGauge {
    id: root

    readonly property real v: Audio.muted ? 0 : Audio.volume
    readonly property real ceiling: SettingsState.v("overAmp") ? Audio.maxVolume : 1
    readonly property bool over: root.ceiling > 1 && root.v > 1
    readonly property real g: Math.min(1, root.v / root.ceiling)

    SceneClock {
        id: clock

        duration: 30240
        still: 0
        live: !Audio.muted
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 150
        height: 150

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Appearance.colour.fillStrong
                strokeWidth: 15
                capStyle: ShapePath.FlatCap

                PathAngleArc {
                    centerX: 75
                    centerY: 75
                    radiusX: 67.5
                    radiusY: 67.5
                    startAngle: 135
                    sweepAngle: 270
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.over ? Appearance.colour.accent : Appearance.colour.text
                strokeWidth: 15
                capStyle: ShapePath.FlatCap

                PathAngleArc {
                    centerX: 75
                    centerY: 75
                    radiusX: 67.5
                    radiusY: 67.5
                    startAngle: 135
                    sweepAngle: Math.max(0.01, 270 * root.g)
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: Audio.muted ? "off" : `${Math.round(root.v * 100)}`
            font.pixelSize: Appearance.font.size.large
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        height: 28
        spacing: 4

        Repeater {
            model: [0.9, 1.3, 0.7, 1.1, 0.8, 1.4, 1]

            delegate: SquircleRect {
                required property real modelData
                required property int index

                readonly property real period: modelData * 2
                readonly property real phase: Frames.pulse(clock.value * 30.24, index * 0.11, period)
                readonly property real swing: Frames.EASE_IN_OUT(phase < 0.5 ? phase * 2 : 2 - phase * 2)

                anchors.bottom: parent.bottom
                width: 6
                height: Audio.muted ? 4 : 4 + (28 * Math.min(1.2, root.v) - 4) * (clock.moving ? swing : 1)
                radius: 2
                color: Appearance.colour.text
                opacity: 0.55
            }
        }
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: SettingsState.outputName
        color: Appearance.colour.textFaint
        elide: Text.ElideRight
    }
}
