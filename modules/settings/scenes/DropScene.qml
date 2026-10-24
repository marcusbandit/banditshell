pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "keyframes.js" as Frames
import "../catalogue.js" as Catalogue

Item {
    id: root

    readonly property real stageHeight: 260
    readonly property bool dropping: ["dropMode", "edgeLift", "followSent"].indexOf(SettingsView.hovered?.k ?? "") >= 0
    readonly property string layout: SettingsView.layoutHover || SettingsState.v("layout")
    readonly property var about: Catalogue.LAYOUTS.find(l => l.id === root.layout) ?? Catalogue.LAYOUTS[0]
    readonly property bool swap: SettingsState.v("dropMode") === "swap"
    readonly property color pane: Appearance.colour.pane

    SceneClock {
        id: clock

        duration: 4800
        still: 0.7
        live: root.dropping
    }

    readonly property real t: clock.value

    function g(x: real, y: real, w: real, h: real, extra: var): var {
        return Object.assign({
            x,
            y,
            w,
            h,
            s: 1,
            lit: 0,
            o: 1
        }, extra ?? {});
    }

    readonly property var deskFrames: [[[0, 86], {
                o: 1
            }], [[92, 97], {
                o: 0
            }], [100, {
                o: 1
            }]]
    readonly property var cFrames: [[[0, 14], root.g(59, 51.5, 41, 48.5)], [22, root.g(59, 51.5, 41, 48.5, {
                s: 1.06,
                lit: 1
            })], [46, root.g(12, 26, 33, 48, {
                s: 1.06,
                lit: 1
            })], [[58, 94], root.g(0, 0, 57, 100)], [[97, 100], root.g(59, 51.5, 41, 48.5)]]
    readonly property var aFrames: [[[0, 30], root.g(0, 0, 57, 100)], [[40, 48], root.g(0, 0, 57, 100, {
                lit: 1
            })], [[60, 94], root.swap ? root.g(59, 51.5, 41, 48.5) : root.g(59, 0, 41, 48.5)], [[97, 100], root.g(0, 0, 57, 100)]]
    readonly property var bFrames: root.swap ? [[0, root.g(59, 0, 41, 48.5)], [100, root.g(59, 0, 41, 48.5)]] : [[[0, 50], root.g(59, 0, 41, 48.5)], [[64, 94], root.g(59, 51.5, 41, 48.5)], [[97, 100], root.g(59, 0, 41, 48.5)]]
    readonly property var curFrames: [[[0, 14], {
                x: 82,
                y: 78,
                o: 1
            }], [46, {
                x: 30,
                y: 52,
                o: 1
            }], [[58, 90], {
                x: 30,
                y: 52,
                o: 1
            }], [[92, 100], {
                x: 82,
                y: 78,
                o: 1
            }]]

    Item {
        id: desk

        visible: root.dropping
        x: 16
        y: 16
        width: parent.width - 32
        height: parent.height - 16 - 48
        opacity: Frames.at(root.deskFrames, root.t, Frames.EASE).o

        Repeater {
            model: [["public", root.aFrames, 1], ["terminal", root.bFrames, 0], ["music_note", root.cFrames, 2]]

            delegate: SquircleRect {
                required property var modelData

                readonly property var f: Frames.at(modelData[1], root.t, Frames.STANDARD)

                x: f.x / 100 * desk.width
                y: f.y / 100 * desk.height
                width: f.w / 100 * desk.width
                height: f.h / 100 * desk.height
                scale: f.s
                z: modelData[2]
                radius: Appearance.rounding.small
                color: modelData[2] === 2 ? Appearance.blend(root.pane, Appearance.blend(Appearance.colour.surfaceSolid, Appearance.colour.accent, 0.2), f.lit) : root.pane
                stroke: Appearance.blend(Appearance.colour.fillStronger, Appearance.colour.accent, f.lit)
                strokeWidth: Appearance.stroke.ring

                Icon {
                    anchors.centerIn: parent
                    name: modelData[0]
                    size: Appearance.icon.large
                    color: Appearance.colour.textDim
                }
            }
        }

        Icon {
            readonly property var f: Frames.at(root.curFrames, root.t, Frames.STANDARD)

            x: f.x / 100 * desk.width
            y: f.y / 100 * desk.height
            z: 3
            name: "near_me"
            size: Appearance.icon.normal
            fill: 1
            color: Appearance.colour.text
        }
    }

    Item {
        visible: !root.dropping
        x: 16
        y: 16
        width: parent.width - 32
        height: parent.height - 16 - 44

        LayoutMini {
            seen: SettingsView.sceneSeen
            height: Math.min(parent.height, parent.width * 10 / 16)
            width: height * 16 / 10
            anchors.centerIn: parent
            layout: root.layout
            big: true
        }
    }

    SceneCaption {
        text: root.dropping ? (root.swap ? "they trade places" : "moves in, the rest shuffle") : `${root.about.name} · ${SettingsState.layoutAvailable(root.about.id) ? root.about.detail : SettingsState.layoutHowTo(root.about.id)}`
    }
}
