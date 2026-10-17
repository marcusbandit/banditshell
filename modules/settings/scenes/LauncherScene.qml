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

    readonly property real stageHeight: 420
    readonly property bool alphabetical: SettingsState.v("concept") === "alphabet"
    readonly property int size: SettingsState.v("launcherIcon")

    SceneClock {
        id: listClock

        duration: 2400
        still: 0.5
        live: !root.alphabetical
    }

    SceneClock {
        id: railClock

        duration: 6600
        still: 0.36
        live: root.alphabetical
    }

    Item {
        id: list

        visible: !root.alphabetical
        x: 16
        y: 16
        width: parent.width - 32
        height: parent.height - 32

        readonly property var found: Apps.search("fir").slice(0, 3)
        readonly property var type: [[[0, 4], {
                    a: 0,
                    b: 0,
                    c: 0
                }], [[5, 9], {
                    a: 1,
                    b: 0,
                    c: 0
                }], [[10, 14], {
                    a: 1,
                    b: 1,
                    c: 0
                }], [[15, 90], {
                    a: 1,
                    b: 1,
                    c: 1
                }], [[92, 100], {
                    a: 0,
                    b: 0,
                    c: 0
                }]]
        readonly property var rowIn: [[[0, 17], {
                    o: 0,
                    x: -8
                }], [[23, 88], {
                    o: 1,
                    x: 0
                }], [[94, 100], {
                    o: 0,
                    x: 0
                }]]
        readonly property var typed: Frames.at(list.type, listClock.value, Frames.steps)

        Column {
            width: parent.width
            spacing: Appearance.padding.small

            Item {
                width: parent.width
                height: 36

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.small
                    color: Appearance.colour.fillStrong
                }

                Row {
                    x: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Appearance.padding.small

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        color: Appearance.colour.textFaint
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "fir".slice(0, list.typed.a + list.typed.b + list.typed.c)
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 2
                        height: 18
                        color: Appearance.colour.accent
                        visible: Math.floor(listClock.value * 2.4 * 2) % 2 === 0 || !listClock.moving
                    }
                }
            }

            Repeater {
                model: list.found

                delegate: Item {
                    id: hit

                    required property var modelData
                    required property int index

                    readonly property var f: Frames.at(list.rowIn, Frames.pulse(listClock.value * 2.4, hit.index * 0.06, 2.4), Frames.EASE)

                    width: list.width
                    height: Math.max(root.size, Appearance.font.line.small) + Appearance.padding.small * 2
                    opacity: listClock.moving ? f.o : 1

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.fill
                        visible: hit.index === 0
                    }

                    Row {
                        x: Appearance.padding.normal + (listClock.moving ? hit.f.x : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.padding.normal

                        AppMark {
                            anchors.verticalCenter: parent.verticalCenter
                            size: root.size
                            spec: AppIcons.markFor(hit.modelData.id, "colour")
                            color: Appearance.colour.textDim
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (hit.modelData.name ?? "").toLowerCase()
                            color: hit.index === 0 ? Appearance.colour.text : Appearance.colour.textDim
                        }
                    }
                }
            }
        }
    }

    Item {
        id: nia

        visible: root.alphabetical
        x: 16
        y: 14
        width: parent.width - 16 - 6
        height: parent.height - 28

        readonly property var letters: Catalogue.RAIL_LETTERS
        readonly property var byLetter: {
            const out = {};
            for (const e of Apps.visible) {
                const c = (e.name ?? "").charAt(0).toLowerCase();
                const key = /[a-z]/.test(c) ? c : "#";
                if (!out[key])
                    out[key] = [];
                if (out[key].length < 3)
                    out[key].push(e);
            }
            return out;
        }
        readonly property var pos: Catalogue.alphabetThumbAt(railClock.value * 6600)
        readonly property real step: nia.height / nia.letters.length
        readonly property real spread: Config.values.launcher.alphabet.bowSpread / 2
        readonly property real bow: Config.values.launcher.alphabet.bow / 10
        property string shown: "fav"

        readonly property string near: nia.pos === null ? "fav" : (nia.byLetter[nia.letters[Math.round(nia.pos)]] ? nia.letters[Math.round(nia.pos)] : nia.shown)

        onNearChanged: nia.shown = nia.near

        readonly property var apps: nia.shown === "fav" ? Apps.pinned(5).slice(0, 5) : nia.byLetter[nia.shown] ?? []

        Column {
            width: parent.width - 44
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            StyledText {
                text: nia.shown === "fav" ? "favourites" : nia.shown
                font.pixelSize: Appearance.font.size.normal
                color: Appearance.colour.accent
                bottomPadding: 4
            }

            Repeater {
                model: nia.apps

                delegate: Row {
                    required property var modelData

                    spacing: 10

                    Item {
                        width: root.size
                        height: root.size

                        SquircleRect {
                            anchors.fill: parent
                            radius: Appearance.rounding.small
                            color: Appearance.colour.fillStrong
                        }

                        AppMark {
                            anchors.centerIn: parent
                            size: Math.round(root.size * 0.62)
                            spec: AppIcons.markFor(modelData.id, "colour")
                            color: Appearance.colour.textDim
                        }
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (modelData.name ?? "").toLowerCase()
                    }
                }
            }
        }

        Item {
            x: parent.width - 44
            width: 44
            height: parent.height

            Repeater {
                model: nia.letters

                delegate: Text {
                    required property string modelData
                    required property int index

                    readonly property real f: Catalogue.bowAt(index, nia.pos, nia.bow, nia.spread)
                    readonly property bool has: !!nia.byLetter[modelData]

                    x: parent.width - 6 - width - nia.bow * f
                    y: index * nia.step + (nia.step - height) / 2
                    text: modelData
                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.small
                    renderType: Text.NativeRendering
                    scale: 1 + f * 0.5
                    transformOrigin: Item.Right
                    color: nia.pos !== null && Math.abs(index - nia.pos) < 0.5 ? Appearance.colour.accent : Appearance.colour.textFaint
                }
            }

            SquircleRect {
                x: parent.width - 14 + 2
                y: nia.pos === null ? 0 : (nia.pos + 0.5) * nia.step - height / 2
                width: 14
                height: 14
                pill: "object"
                color: Appearance.colour.text
                opacity: nia.pos === null ? 0 : 1

                SquircleRect {
                    anchors.centerIn: parent
                    width: 26
                    height: 26
                    pill: "object"
                    z: -1
                    color: Appearance.colour.fillStronger
                }
            }
        }
    }
}
