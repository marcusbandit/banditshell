pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "keyframes.js" as Frames
import "../catalogue.js" as Catalogue

Item {
    id: root

    readonly property real stageHeight: 260
    readonly property var apps: (SettingsState.planned.startup ?? []).filter(a => a.on)
    readonly property var rects: Catalogue.dwindleRects(Math.max(1, root.apps.length))
    readonly property int cycle: 2000 + root.apps.length * 900 + 1800

    SceneClock {
        id: clock

        duration: root.cycle
        still: 1
    }

    readonly property real ms: clock.value * root.cycle

    function phase(start: real, length: real): real {
        return Math.max(0, Math.min(1, (root.ms - start) / length));
    }

    Item {
        id: fit

        x: 16
        y: 16
        width: parent.width - 32
        height: parent.height - 16 - 44

        Item {
            id: screen

            height: Math.min(fit.height, fit.width * 10 / 16)
            width: screen.height * 16 / 10
            anchors.centerIn: parent
            clip: true

            SquircleRect {
                anchors.fill: parent
                radius: 10
                color: "#050506"
                stroke: Appearance.colour.fillStrong
                strokeWidth: 1
            }

            Item {
                id: shell

                readonly property real k: Frames.ARRIVE(root.phase(700, 800))

                anchors.fill: parent
                opacity: shell.k
                scale: 1.03 - 0.03 * shell.k

                SquircleRect {
                    anchors.fill: parent
                    radius: 10
                    color: Appearance.colour.surfaceSolid
                }

                Column {
                    readonly property real k: Frames.ARRIVE(root.phase(1100, 600))

                    x: parent.width * 0.03 - (1 - k) * 1.2 * parent.width * 0.07
                    width: parent.width * 0.07
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    opacity: k

                    Repeater {
                        model: [false, true, false, false]

                        delegate: SquircleRect {
                            required property bool modelData

                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 6
                            height: modelData ? 16 : 6
                            radius: 3
                            color: modelData ? Appearance.colour.accent : Appearance.colour.fillStronger
                        }
                    }
                }

                Item {
                    id: hole

                    x: parent.width * 0.12
                    y: parent.height * 0.04
                    width: parent.width * 0.85
                    height: parent.height * 0.92

                    SquircleRect {
                        anchors.fill: parent
                        radius: 6
                        color: Appearance.blend(Appearance.colour.surfaceSolid, "#000000", 0.35)
                    }

                    Repeater {
                        model: root.apps

                        delegate: Item {
                            id: win

                            required property var modelData
                            required property int index

                            readonly property var r: root.rects[win.index]
                            readonly property real open: Frames.BACK(root.phase(2500 + win.index * 900, 400))
                            readonly property real spin: root.phase(2000 + win.index * 900, 550)

                            x: win.r.x / 100 * hole.width
                            y: win.r.y / 100 * hole.height
                            width: win.r.w / 100 * hole.width
                            height: win.r.h / 100 * hole.height

                            SquircleRect {
                                anchors.fill: parent
                                anchors.margins: parent.width * 0.015
                                radius: 5
                                color: Appearance.blend(Appearance.colour.surfaceSolid, Appearance.colour.paper, 0.12)
                                stroke: Appearance.colour.fillStronger
                                strokeWidth: 1
                                opacity: Math.min(1, win.open)
                                scale: 0.85 + 0.15 * win.open

                                AppMark {
                                    anchors.centerIn: parent
                                    size: 26
                                    spec: AppIcons.markFor(win.modelData.id, "colour")
                                    color: Appearance.colour.textDim
                                }
                            }

                            SquircleRect {
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                radius: 11
                                cornerPower: 2
                                color: "transparent"
                                stroke: Appearance.colour.accent
                                strokeWidth: 3
                                rotation: win.spin * 360 * 1.1
                                opacity: win.spin <= 0 || win.spin >= 1 ? 0 : win.spin < 0.15 ? win.spin / 0.15 : win.spin > 0.8 ? (1 - win.spin) / 0.2 : 1

                                Rectangle {
                                    x: parent.width / 2
                                    width: parent.width / 2 + 1
                                    height: parent.height / 2 + 1
                                    color: Appearance.blend(Appearance.colour.surfaceSolid, "#000000", 0.35)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SceneCaption {
        text: root.apps.length ? `${root.apps.length} app${root.apps.length > 1 ? "s start" : " starts"} with you` : "nothing starts with you"
    }
}
