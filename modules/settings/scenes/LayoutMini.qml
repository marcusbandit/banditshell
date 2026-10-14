pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "keyframes.js" as Frames

Item {
    id: root

    property string layout: "dwindle"
    property bool big: false
    property bool lit: false
    property bool live: true

    readonly property color pane: Appearance.blend(Appearance.colour.surfaceSolid, Appearance.colour.paper, 0.16)
    readonly property color edge: root.big || root.lit ? Qt.rgba(Appearance.colour.accent.r, Appearance.colour.accent.g, Appearance.colour.accent.b, 0.55) : Appearance.colour.fillStronger
    readonly property real edgeWidth: root.big || root.lit ? 1.5 : 1
    readonly property real winRadius: root.big ? Appearance.rounding.small : 3

    readonly property var frames: ({
            dwindle: [
                [[0, 14], [4, 6, 92, 88, 1, 1], [22, 100], [4, 6, 45, 88, 1, 1]],
                [[0, 14], [51, 6, 45, 88, 0, 0.8], [22, 36], [51, 6, 45, 88, 1, 1], [44, 100], [51, 6, 45, 42, 1, 1]],
                [[0, 36], [51, 52, 45, 42, 0, 0.8], [44, 58], [51, 52, 45, 42, 1, 1], [66, 100], [51, 52, 21, 42, 1, 1]],
                [[0, 58], [75, 52, 21, 42, 0, 0.8], [66, 100], [75, 52, 21, 42, 1, 1]]
            ],
            master: [
                [[0, 14], [4, 6, 92, 88, 1, 1], [22, 100], [4, 6, 56, 88, 1, 1]],
                [[0, 14], [62, 6, 34, 88, 0, 1], [22, 36], [62, 6, 34, 88, 1, 1], [44, 58], [62, 6, 34, 42, 1, 1], [66, 100], [62, 6, 34, 27, 1, 1]],
                [[0, 36], [62, 52, 34, 42, 0, 1], [44, 58], [62, 52, 34, 42, 1, 1], [66, 100], [62, 36.5, 34, 27, 1, 1]],
                [[0, 58], [62, 67, 34, 27, 0, 1], [66, 100], [62, 67, 34, 27, 1, 1]]
            ]
        })

    function track(raw: var): var {
        const out = [];
        for (let i = 0; i < raw.length; i += 2) {
            const g = raw[i + 1];
            out.push([raw[i], {
                    x: g[0],
                    y: g[1],
                    w: g[2],
                    h: g[3],
                    o: g[4],
                    s: g[5]
                }]);
        }
        return out;
    }

    readonly property var tracks: (root.frames[root.layout] ?? []).map(root.track)

    SceneClock {
        id: clock

        duration: 4800
        live: root.live && root.visible
    }

    SceneClock {
        id: orbit

        duration: 9000
        still: 0
        live: root.live && root.visible && root.layout === "custom"
    }

    SceneClock {
        id: wobble

        duration: 2400
        still: 0
        live: root.live && root.visible && root.layout === "custom"
    }

    SquircleRect {
        id: box

        anchors.fill: parent
        radius: root.big ? Appearance.rounding.normal : 6
        color: Appearance.colour.fill
    }

    Item {
        anchors.fill: parent
        clip: true

        Repeater {
            model: root.layout === "dwindle" || root.layout === "master" ? root.tracks : []

            delegate: SquircleRect {
                required property var modelData

                readonly property var f: Frames.at(modelData, clock.value, Frames.STANDARD)

                x: f.x / 100 * root.width
                y: f.y / 100 * root.height
                width: f.w / 100 * root.width
                height: f.h / 100 * root.height
                opacity: f.o
                scale: f.s
                radius: root.winRadius
                color: root.pane
                stroke: root.edge
                strokeWidth: root.edgeWidth
            }
        }

        Item {
            id: strip

            readonly property var shift: [[[0, 18], {
                        x: 0
                    }], [[30, 46], {
                        x: -48
                    }], [[58, 74], {
                        x: -96
                    }], [[88, 100], {
                        x: 0
                    }]]

            visible: root.layout === "scrolling"
            width: parent.width
            height: parent.height
            x: Frames.at(strip.shift, clock.value, Frames.STANDARD).x / 100 * root.width

            Repeater {
                model: [4, 52, 100, 148]

                delegate: SquircleRect {
                    required property real modelData

                    x: modelData / 100 * root.width
                    y: 0.06 * root.height
                    width: 0.44 * root.width
                    height: 0.88 * root.height
                    radius: root.winRadius
                    color: root.pane
                    stroke: root.edge
                    strokeWidth: root.edgeWidth
                }
            }
        }

        SquircleRect {
            visible: root.layout === "scrolling"
            x: 0.02 * root.width
            y: 0.03 * root.height
            width: 0.96 * root.width
            height: 0.94 * root.height
            radius: 6
            color: "transparent"
            stroke: Appearance.colour.accent
            strokeWidth: 1.5
            opacity: 0.5
        }

        Item {
            id: hy3

            readonly property var walk: [[[0, 28], {
                        x: 0
                    }], [[36, 61], {
                        x: 1
                    }], [[69, 94], {
                        x: 2
                    }], [100, {
                        x: 0
                    }]]
            readonly property real tab: Frames.at(hy3.walk, clock.value, Frames.STANDARD).x

            visible: root.layout === "hy3"
            anchors.fill: parent

            SquircleRect {
                x: 0.04 * root.width
                y: 0.06 * root.height
                width: 0.45 * root.width
                height: 0.88 * root.height
                radius: root.winRadius
                color: root.pane
                stroke: root.edge
                strokeWidth: root.edgeWidth
            }

            Item {
                id: group

                x: 0.51 * root.width
                y: 0.06 * root.height
                width: 0.45 * root.width
                height: 0.88 * root.height

                readonly property real gap: group.height * 0.03
                readonly property real tabsHeight: group.height * 0.14
                readonly property real tabGap: group.width * 0.04
                readonly property real tabWidth: (group.width - 2 * group.tabGap) / 3

                Repeater {
                    model: 3

                    delegate: SquircleRect {
                        required property int index

                        x: index * (group.tabWidth + group.tabGap)
                        width: group.tabWidth
                        height: group.tabsHeight
                        radius: 2
                        color: Appearance.colour.fillStrong
                    }
                }

                SquircleRect {
                    x: hy3.tab * (group.tabWidth + group.tabGap)
                    width: group.width * 0.306
                    height: group.tabsHeight
                    radius: 2
                    color: Appearance.colour.accent
                    opacity: 0.7
                }

                Item {
                    id: body

                    y: group.tabsHeight + group.gap
                    width: group.width
                    height: group.height - y
                    clip: true

                    Row {
                        x: -hy3.tab * body.width

                        Repeater {
                            model: [["public", 0], ["terminal", 1], ["edit_note", 2]]

                            delegate: SquircleRect {
                                required property var modelData

                                width: body.width
                                height: body.height
                                radius: root.winRadius
                                color: modelData[1] === 1 ? Appearance.blend(root.pane, Appearance.colour.accent, 0.12) : modelData[1] === 2 ? Appearance.blend(root.pane, Appearance.colour.paper, 0.06) : root.pane
                                stroke: Appearance.colour.fillStronger
                                strokeWidth: 1

                                Icon {
                                    anchors.centerIn: parent
                                    name: modelData[0]
                                    size: root.big ? 32 : 12
                                    color: Appearance.colour.textDim
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: spin

            visible: root.layout === "custom"
            anchors.fill: parent
            rotation: orbit.value * 360

            Repeater {
                model: [[10, 10, 0, "plain"], [64, 10, -0.6, "leaf"], [64, 56, -1.2, "plain"], [10, 56, -1.8, "leafBack"]]

                delegate: SquircleRect {
                    required property var modelData

                    readonly property real phase: Frames.pulse(wobble.value * 2.4, modelData[2], 2.4)
                    readonly property real swing: Frames.EASE_IN_OUT(phase < 0.5 ? phase * 2 : 2 - phase * 2)

                    x: modelData[0] / 100 * root.width
                    y: modelData[1] / 100 * root.height
                    width: 0.26 * root.width
                    height: 0.34 * root.height
                    rotation: -8 + 18 * swing
                    scale: 0.92 + 0.16 * swing
                    radius: root.winRadius
                    topLeftRadius: modelData[3] === "leaf" ? height * 0.4 : modelData[3] === "leafBack" ? 6 : root.winRadius
                    bottomRightRadius: modelData[3] === "leaf" ? height * 0.4 : modelData[3] === "leafBack" ? 6 : root.winRadius
                    topRightRadius: modelData[3] === "leaf" ? 6 : modelData[3] === "leafBack" ? height * 0.4 : root.winRadius
                    bottomLeftRadius: modelData[3] === "leaf" ? 6 : modelData[3] === "leafBack" ? height * 0.4 : root.winRadius
                    color: Appearance.blend(root.pane, Appearance.colour.accent, 0.25)
                    stroke: root.edge
                    strokeWidth: root.edgeWidth
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            visible: root.layout === "custom"
            name: "add"
            size: root.big ? 40 : 18
            color: Appearance.colour.accent
        }
    }
}
