pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "keyframes.js" as Frames

Item {
    id: root

    readonly property real stageHeight: 300
    readonly property color pane: Appearance.blend(Appearance.colour.surfaceSolid, Appearance.colour.paper, 0.12)

    SceneClock {
        id: clock

        duration: 10000
        still: 0.1
    }

    readonly property real t: clock.value

    function rect(x: real, y: real, w: real, h: real): var {
        return {
            x,
            y,
            w,
            h
        };
    }

    readonly property var w1: [[[0, 28], root.rect(3, 4, 55, 92)], [[34, 44], root.rect(60, 51, 37, 45)], [[50, 100], root.rect(3, 4, 55, 92)]]
    readonly property var w3: [[[0, 26], Object.assign(root.rect(60, 51, 37, 45), {
                s: 1,
                lit: 0
            })], [29, {
                s: 1.05,
                lit: 1
            }], [[34, 44], Object.assign(root.rect(3, 4, 55, 92), {
                s: 1,
                lit: 0
            })], [[50, 100], Object.assign(root.rect(60, 51, 37, 45), {
                s: 1,
                lit: 0
            })]]
    readonly property var launch: [[[0, 52], {
                o: -1.02
            }], [[57, 70], {
                o: 0
            }], [[75, 100], {
                o: -1.02
            }]]
    readonly property var clip: [[[0, 77], {
                o: -1.02
            }], [[82, 95], {
                o: 0
            }], [100, {
                o: -1.02
            }]]
    readonly property var wsGlow: [[[0, 2], {
                a: 0
            }], [[5, 9], {
                a: 1
            }], [[14, 100], {
                a: 0
            }]]
    readonly property var captions: [[[[0, 22], {
                    o: 1
                }], [[25, 100], {
                    o: 0
                }]], [[[0, 25], {
                    o: 0
                }], [[28, 47], {
                    o: 1
                }], [[50, 100], {
                    o: 0
                }]], [[[0, 50], {
                    o: 0
                }], [[53, 72], {
                    o: 1
                }], [[75, 100], {
                    o: 0
                }]], [[[0, 75], {
                    o: 0
                }], [[78, 97], {
                    o: 1
                }], [100, {
                    o: 0
                }]]]

    Item {
        id: fit

        x: 16
        y: 16
        width: parent.width - 32
        height: parent.height - 16 - 44

        Item {
            id: frame

            height: Math.min(fit.height, fit.width * 10 / 16)
            width: frame.height * 16 / 10
            anchors.centerIn: parent
            clip: true

            SquircleRect {
                anchors.fill: parent
                radius: 10
                color: Appearance.colour.surfaceSolid
            }

            Column {
                id: bar

                width: parent.width * 0.09
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5

                Repeater {
                    model: [1, 1, 0, 1, 0]

                    delegate: SquircleRect {
                        required property int modelData
                        required property int index

                        readonly property real glow: modelData ? Frames.at(root.wsGlow, Frames.pulse(root.t * 10, index * 0.35, 10), Frames.EASE).a : 0

                        anchors.horizontalCenter: parent.horizontalCenter
                        width: modelData ? 10 : 4
                        height: width
                        radius: 3
                        color: Appearance.blend(Appearance.colour.fillStronger, Appearance.colour.accent, glow)
                    }
                }
            }

            SquircleRect {
                x: (bar.width - width) / 2
                y: parent.height - 10 - height
                width: 10
                height: 14
                radius: 2
                color: Appearance.colour.fillStrong
            }

            Item {
                id: hole

                x: parent.width * 0.09
                y: parent.height * 0.04
                width: parent.width * (1 - 0.09 - 0.025)
                height: parent.height * 0.92
                clip: true

                SquircleImage {
                    anchors.fill: parent
                    radius: 6
                    source: Wallpaper.faceOf(Wallpaper.currentOn(Settings.screenName))
                    fillMode: Image.PreserveAspectCrop
                }

                SquircleRect {
                    readonly property var f: Frames.at(root.w1, root.t, Frames.STANDARD)

                    x: f.x / 100 * hole.width
                    y: f.y / 100 * hole.height
                    width: f.w / 100 * hole.width
                    height: f.h / 100 * hole.height
                    radius: 4
                    color: root.pane
                    stroke: Appearance.colour.fillStronger
                    strokeWidth: 1
                }

                SquircleRect {
                    x: 0.6 * hole.width
                    y: 0.04 * hole.height
                    width: 0.37 * hole.width
                    height: 0.45 * hole.height
                    radius: 4
                    color: root.pane
                    stroke: Appearance.colour.fillStronger
                    strokeWidth: 1
                }

                SquircleRect {
                    readonly property var f: Frames.at(root.w3, root.t, Frames.STANDARD)

                    x: f.x / 100 * hole.width
                    y: f.y / 100 * hole.height
                    width: f.w / 100 * hole.width
                    height: f.h / 100 * hole.height
                    scale: f.s
                    z: 1
                    radius: 4
                    color: root.pane
                    stroke: Appearance.blend(Appearance.colour.fillStronger, Appearance.colour.accent, f.lit)
                    strokeWidth: 1 + f.lit * 0.5
                }

                Repeater {
                    model: [["launch", 0.18, 0.46, 4, false], ["clip", 0.3, 0.56, 4, true]]

                    delegate: Item {
                        id: panel

                        required property var modelData

                        readonly property var f: Frames.at(panel.modelData[0] === "launch" ? root.launch : root.clip, root.t, Frames.ARRIVE)

                        x: f.o * width
                        y: panel.modelData[1] * hole.height
                        z: 2
                        width: panel.modelData[2] * hole.width
                        height: lines.implicitHeight + 12

                        SquircleRect {
                            anchors.fill: parent
                            radius: 8
                            topLeftRadius: 0
                            bottomLeftRadius: 0
                            color: Appearance.colour.surfaceSolid
                        }

                        Column {
                            id: lines

                            x: 6
                            y: 6
                            width: parent.width - 12
                            spacing: 5

                            Repeater {
                                model: panel.modelData[3]

                                delegate: SquircleRect {
                                    required property int index

                                    readonly property bool title: panel.modelData[0] === "launch" && index === 0

                                    width: parent.width
                                    height: title ? 10 : 6
                                    radius: 3
                                    color: panel.modelData[4] && index === 0 ? Appearance.colour.accentFill : title ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Item {
        x: Appearance.padding.card
        y: parent.height - Appearance.padding.normal - height
        width: parent.width - Appearance.padding.card * 2
        height: Appearance.font.line.small

        Repeater {
            model: ["sidebar", "windows", "launcher", "clipboard"]

            delegate: StyledText {
                required property string modelData
                required property int index

                text: modelData
                color: Appearance.colour.textFaint
                opacity: clock.moving ? Frames.at(root.captions[index], root.t, Frames.EASE).o : index === 0 ? 1 : 0
            }
        }
    }
}
