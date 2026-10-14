pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "scenes/keyframes.js" as Frames

Item {
    id: root

    property string style: "plates"
    property bool colourful: true
    property int limit: 4
    property int active: 1
    property int persistent: 5
    property bool walking: false

    readonly property var turn: [[0, {
                o: 0
            }], [[4, 24], {
                o: 1
            }], [[28, 100], {
                o: 0
            }]]

    property real clock: 0

    NumberAnimation on clock {
        from: 0
        to: 1
        duration: 6000
        loops: Animation.Infinite
        running: root.walking && root.visible && !SettingsView.reduceMotion
    }

    readonly property var sample: [
        {
            id: 1,
            apps: [{
                    ic: "public",
                    app: "#ff7139",
                    focus: true
                }]
        },
        {
            id: 2,
            apps: [{
                    ic: "terminal",
                    app: "#a6e3a1",
                    count: 2
                }]
        },
        {
            id: 3,
            apps: []
        },
        {
            id: 4,
            apps: [{
                    ic: "music_note",
                    app: "#1ed760"
                }, {
                    ic: "forum",
                    app: "#7289ff"
                }]
        },
        {
            id: 5,
            apps: []
        },
        {
            id: 7,
            apps: [{
                    ic: "code",
                    app: "#3b9cff"
                }]
        }
    ]

    readonly property var list: root.sample.filter(w => w.id <= root.persistent || w.apps.length).slice(0, root.limit)

    function windows(w: var): var {
        const out = [];
        for (const a of w.apps)
            for (let i = 0; i < (a.count || 1); i++)
                out.push({
                    focus: !!a.focus,
                    i
                });
        return out;
    }

    implicitWidth: loader.item?.implicitWidth ?? 0
    implicitHeight: loader.item?.implicitHeight ?? 0

    Loader {
        id: loader

        sourceComponent: root.style === "map" ? map : root.style === "blocks" ? blocks : plates
    }

    Component {
        id: plates

        Column {
            spacing: 12

            Repeater {
                model: root.list

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property bool busy: cell.modelData.apps.length > 0
                    readonly property real lit: root.walking && cell.busy && !SettingsView.reduceMotion ? Frames.at(root.turn, Frames.pulse(root.clock * 6, cell.index === 0 ? 0 : (cell.index + 1) * 0.75, 6), Frames.EASE).o : 0
                    readonly property bool on: cell.modelData.id === root.active
                    readonly property real plateHeight: cell.busy ? 32 + (cell.modelData.apps.length - 1) * 25 : 9

                    width: 32
                    height: cell.plateHeight

                    SquircleRect {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: cell.busy ? 32 : 9
                        height: cell.plateHeight
                        radius: Appearance.rounding.normal
                        color: cell.on ? Appearance.colour.fillStrong : Appearance.colour.fill

                        SquircleRect {
                            anchors.fill: parent
                            radius: Appearance.rounding.normal
                            color: Appearance.colour.accentFill
                            visible: cell.on && !root.walking
                        }

                        SquircleRect {
                            anchors.fill: parent
                            radius: Appearance.rounding.normal
                            color: Appearance.colour.accentFill
                            opacity: cell.lit
                            visible: root.walking
                        }

                        Column {
                            anchors.centerIn: parent

                            Repeater {
                                model: cell.modelData.apps

                                delegate: Icon {
                                    required property var modelData

                                    width: 25
                                    height: 25
                                    name: modelData.ic
                                    size: Math.round(Appearance.font.iconSize * 1.25)
                                    color: root.colourful ? modelData.app : modelData.focus ? Appearance.colour.text : Appearance.colour.textDim
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: map

        Column {
            leftPadding: 10
            spacing: 10

            Repeater {
                model: root.list

                delegate: Column {
                    id: grp

                    required property var modelData

                    readonly property bool on: grp.modelData.id === root.active
                    readonly property var bars: root.windows(grp.modelData)

                    spacing: 3

                    Repeater {
                        model: grp.bars.length ? grp.bars : [{
                                empty: true
                            }]

                        delegate: SquircleRect {
                            required property var modelData
                            required property int index

                            width: modelData.empty ? 12 : 14 + ((grp.modelData.id * 7 + modelData.i * 5) % 18)
                            height: 5
                            radius: Appearance.rounding.normal
                            color: modelData.empty ? (grp.on ? Appearance.colour.accent : Appearance.colour.textGhost) : grp.on ? (modelData.focus ? Appearance.colour.accent : Appearance.colour.accentFill) : Appearance.colour.textFaint
                        }
                    }
                }
            }
        }
    }

    Component {
        id: blocks

        Column {
            spacing: 10

            Repeater {
                model: root.list

                delegate: Item {
                    id: blk

                    required property var modelData

                    readonly property bool on: blk.modelData.id === root.active
                    readonly property var cells: root.windows(blk.modelData)

                    width: 33
                    height: blk.cells.length ? Math.ceil(blk.cells.length / 3) * 12 - 3 : 4.5

                    Grid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: blk.cells.length > 0
                        columns: 3
                        spacing: 3

                        Repeater {
                            model: blk.cells

                            delegate: SquircleRect {
                                required property var modelData

                                width: 9
                                height: 9
                                radius: 2
                                color: blk.on ? (modelData.focus ? Appearance.colour.accent : Appearance.colour.accentFill) : Appearance.colour.textFaint
                            }
                        }
                    }

                    SquircleRect {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: blk.cells.length === 0
                        width: 4.5
                        height: 4.5
                        radius: 2
                        color: blk.on ? Appearance.colour.accent : Appearance.colour.textGhost
                    }
                }
            }
        }
    }
}
