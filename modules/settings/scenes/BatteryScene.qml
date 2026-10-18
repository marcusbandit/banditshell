import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "battery.js" as Sim

Item {
    id: root

    readonly property real stageHeight: 260

    readonly property bool present: Battery.available
    readonly property bool limit: SettingsState.v("chargeLimit")
    readonly property int cap: root.limit ? SettingsState.v("chargeMax") : 100
    readonly property int warn: SettingsState.v("lowWarn")

    readonly property var options: ({
            present: root.present,
            limit: root.limit,
            max: SettingsState.v("chargeMax"),
            home: root.present ? Battery.percent : 0,
            warn: root.warn,
            profile: SettingsState.v("profile")
        })

    property var sim: Sim.still(root.options)

    readonly property bool low: root.present && root.sim.level <= root.warn
    readonly property bool charging: root.present && root.sim.charging

    FrameAnimation {
        running: root.visible && !SettingsView.reduceMotion && !Appearance.lessMotion
        onTriggered: root.sim = Sim.step(Math.min(0.1, frameTime), root.options)
    }

    Item {
        id: tank

        x: 24
        y: 24
        width: 64
        height: parent.height - 48

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: "transparent"
            stroke: Appearance.colour.fillStronger
            strokeWidth: Appearance.stroke.ring
        }

        SquircleRect {
            x: 4
            width: parent.width - 8
            height: Math.max(0, parent.height * root.sim.level / 100 - 8)
            y: parent.height - 4 - height
            radius: Math.max(0, Appearance.rounding.normal - 4)
            color: levelTone.value
            opacity: root.low || root.charging ? Appearance.opacity.glow : Appearance.opacity.trail

            FollowColour {
                id: levelTone

                target: root.low ? Appearance.colour.alarm : root.charging ? Appearance.colour.accent : Appearance.colour.text
                speed: Appearance.animation.trackSpeed
            }
        }

        Rectangle {
            visible: root.limit && root.present
            y: parent.height * (1 - root.cap / 100) - 1
            width: parent.width
            height: 2
            color: Appearance.colour.accent
        }

        StyledText {
            x: parent.width + 8
            y: parent.height * (1 - root.sim.level / 100) + 4 - height / 2
            visible: root.present
            text: `${Math.round(root.sim.level)}%`
        }
    }

    Item {
        id: hist

        x: 150
        y: 28
        width: parent.width - 150 - 20
        height: parent.height - 28 - 44

        readonly property var pts: {
            const s = root.sim.samples.length ? root.sim.samples : [root.sim.level];
            const n = 60;
            return s.map((v, i) => Qt.point(hist.width * (1 - (s.length - 1 - i) / (n - 1)), hist.height * (1 - v / 100)));
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: "transparent"
                fillColor: Appearance.colour.fill

                PathPolyline {
                    path: hist.pts.concat([Qt.point(hist.width, hist.height), Qt.point(hist.pts[0].x, hist.height)])
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.low ? Appearance.colour.alarm : Appearance.colour.textDim
                strokeWidth: Appearance.stroke.ring

                PathPolyline {
                    path: hist.pts
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.limit && root.present ? Appearance.colour.accent : "transparent"
                strokeWidth: Appearance.stroke.line
                strokeStyle: ShapePath.DashLine
                dashPattern: [4, 4]

                PathPolyline {
                    path: [Qt.point(0, hist.height * (1 - root.cap / 100)), Qt.point(hist.width, hist.height * (1 - root.cap / 100))]
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: Appearance.colour.alarm
                strokeWidth: Appearance.stroke.line
                strokeStyle: ShapePath.DashLine
                dashPattern: [2, 4]

                PathPolyline {
                    path: [Qt.point(0, hist.height * (1 - root.warn / 100)), Qt.point(hist.width, hist.height * (1 - root.warn / 100))]
                }
            }
        }
    }

    Item {
        x: 150
        y: parent.height - 16 - height
        width: parent.width - 170
        height: Appearance.font.line.small

        StyledText {
            width: parent.width - now.width - Appearance.padding.normal
            text: !root.present ? "no battery" : root.charging ? `charging to ${Math.round(root.sim.target)}%` : `draining · ${SettingsState.v("profile")}`
            color: Appearance.colour.textFaint
            elide: Text.ElideRight
        }

        StyledText {
            id: now

            anchors.right: parent.right
            text: "now"
            color: Appearance.colour.textFaint
        }
    }
}
