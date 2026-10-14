pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "keyframes.js" as Frames

SceneGauge {
    id: root

    readonly property bool on: SettingsState.v("wifi") && SettingsState.wifiNet !== ""
    readonly property bool live: SettingsState.v("keepFresh") && SettingsState.v("wifi")
    readonly property int sig: Network.active ? Network.bars(Network.active) : 0

    SceneClock {
        id: clock

        duration: 2800
        still: 0.5
    }

    readonly property var barFrames: [[0, {
                o: 0.2
            }], [[20, 85], {
                o: 1
            }], [100, {
                o: 0.2
            }]]
    readonly property var sweepFrames: [[0, {
                s: 0.3,
                o: 0.8
            }], [[70, 100], {
                s: 1.6,
                o: 0
            }]]

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 120
        height: 90

        SquircleRect {
            readonly property var f: Frames.at(root.sweepFrames, clock.value, Frames.EASE_OUT)

            anchors.centerIn: parent
            width: 90
            height: 90
            radius: 45
            cornerPower: 2
            color: "transparent"
            stroke: Appearance.colour.accent
            strokeWidth: 2
            visible: root.live && clock.moving
            scale: f.s
            opacity: f.o
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: 4

                delegate: SquircleRect {
                    required property int index

                    readonly property var f: Frames.at(root.barFrames, Frames.pulse(clock.value * 2.8, (index + 1) * 0.15, 2.8), Frames.EASE)

                    anchors.bottom: parent.bottom
                    width: 14
                    height: (index + 1) * 16
                    radius: 4
                    color: root.on ? Appearance.colour.text : Appearance.colour.textGhost
                    opacity: !root.on ? 0.28 : index >= root.sig ? 0.28 : clock.moving ? f.o : 1
                }
            }
        }
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.on ? SettingsState.wifiNet : Network.wiredConnected ? "ethernet" : "offline"
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.on || Network.wiredConnected ? SettingsState.reach : SettingsState.v("wifi") ? "pick a network" : "wi-fi is off"
        color: Appearance.colour.textFaint
    }
}
