pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "keyframes.js" as Frames

Item {
    id: root

    readonly property real stageHeight: 240
    readonly property bool natural: SettingsState.v("naturalScroll")

    SceneClock {
        id: clock

        duration: 2400
        still: 0.5
    }

    readonly property var swipe: [[[0, 10], {
                y: 0.3,
                o: 0
            }], [20, {
                y: 0.1,
                o: 0.55
            }], [70, {
                y: -1.6,
                o: 0.55
            }], [[85, 100], {
                y: -1.6,
                o: 0
            }]]
    readonly property var page: [[[0, 20], {
                y: 0
            }], [[70, 100], {
                y: 1
            }]]

    Item {
        id: area

        x: 20
        y: 20
        width: parent.width - 40
        height: parent.height - 20 - 48

        readonly property real padWidth: (width - 20) * 1.6 / 2.6
        readonly property real stripWidth: (width - 20) / 2.6

        Item {
            id: pad

            width: Math.min(area.padWidth, area.height * 1.5)
            height: width / 1.5
            anchors.verticalCenter: parent.verticalCenter

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill
                stroke: Appearance.colour.fillStronger
                strokeWidth: 2
            }

            Item {
                anchors.fill: parent
                clip: true

                Repeater {
                    model: [0.34, 0.52]

                    delegate: SquircleRect {
                        required property real modelData

                        readonly property var f: Frames.at(root.swipe, clock.value, Frames.STANDARD)

                        x: modelData * pad.width
                        y: 0.6 * pad.height + f.y * width
                        width: 0.14 * pad.width
                        height: width
                        radius: width / 2
                        cornerPower: 2
                        color: Appearance.colour.text
                        opacity: clock.moving ? f.o : 0.55
                    }
                }
            }
        }

        Item {
            id: strip

            x: area.padWidth + 20
            width: area.stripWidth
            height: Math.min(150, area.height)
            anchors.verticalCenter: parent.verticalCenter
            clip: true

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colour.fill
            }

            Column {
                readonly property real k: Frames.at(root.page, clock.value, Frames.STANDARD).y

                x: 10
                y: 10 - 40 * (root.natural ? k : 1 - k)
                width: parent.width - 20
                spacing: 8

                Repeater {
                    model: 9

                    delegate: SquircleRect {
                        required property int index

                        width: (index + 1) % 3 === 0 ? parent.width * 0.6 : parent.width
                        height: 6
                        radius: 3
                        color: Appearance.colour.fillStronger
                    }
                }
            }
        }
    }

    SceneCaption {
        text: `${root.natural ? "the page follows your fingers" : "the page moves against your fingers"}${SettingsState.v("tapClick") ? " · tap clicks" : ""}`
    }
}
