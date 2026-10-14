pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "keyframes.js" as Frames

Item {
    id: root

    readonly property real stageHeight: 220

    property double now: Date.now()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    SceneClock {
        id: clock

        duration: 4000
        still: 0.5
    }

    readonly property var dotFrames: [[0, {
                o: 0,
                s: 0
            }], [[6, 70], {
                o: 1,
                s: 1
            }], [[80, 100], {
                o: 0,
                s: 1
            }]]
    readonly property var liftFrames: [[[0, 62], {
                o: 1,
                y: 0,
                s: 1
            }], [76, {
                o: 0,
                y: -14,
                s: 1.04
            }], [[90, 100], {
                o: 1,
                y: 0,
                s: 1
            }]]

    Item {
        anchors.fill: parent
        clip: true

        Image {
            id: wall

            x: -30
            y: -30
            width: parent.width + 60
            height: parent.height + 60
            source: Wallpaper.faceOf(Wallpaper.currentOn(Settings.screenName)) ? `file://${Wallpaper.expand(Wallpaper.faceOf(Wallpaper.currentOn(Settings.screenName)))}` : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        MultiEffect {
            anchors.fill: wall
            source: wall
            blurEnabled: true
            blur: SettingsState.v("lockBlur")
            blurMax: 20
            saturation: -SettingsState.v("lockDesat")
            brightness: -SettingsState.v("lockDim") * 0.6
        }
    }

    Column {
        readonly property var f: Frames.at(root.liftFrames, clock.value, Frames.EASE)

        anchors.centerIn: parent
        anchors.verticalCenterOffset: f.y
        spacing: 6
        opacity: f.o
        scale: f.s

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: TimeFormat.time(new Date(root.now), false)
            font.pixelSize: Appearance.font.size.large
            color: "white"
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: dots.implicitWidth + 28
            height: dots.implicitHeight + 16

            SquircleRect {
                anchors.fill: parent
                radius: 16
                cornerPower: 2
                color: Qt.rgba(1, 1, 1, 0.14)
            }

            Row {
                id: dots

                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: 6

                    delegate: SquircleRect {
                        required property int index

                        readonly property var f: Frames.at(root.dotFrames, Frames.pulse(clock.value * 4, 0.3 + index * 0.18, 4), Frames.EASE)

                        width: 8
                        height: 8
                        radius: 4
                        cornerPower: 2
                        color: Appearance.colour.accent
                        opacity: clock.moving ? f.o : 1
                        scale: clock.moving ? f.s : 1
                    }
                }
            }
        }
    }
}
