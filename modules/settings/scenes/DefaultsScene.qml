pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "keyframes.js" as Frames
import "../catalogue.js" as Catalogue

Item {
    id: root

    readonly property real stageHeight: 240

    readonly property var look: ({
            firefox: ["public", "#ff7139"],
            chromium: ["public", "#4c8bf5"],
            zen: ["public", "#f2c75c"],
            files: ["folder", "#7fb3d4"],
            nautilus: ["folder", "#8fb7e8"],
            thunar: ["folder", "#6aa0d8"],
            kitty: ["terminal", "#a6e3a1"],
            foot: ["terminal", "#9ccfd8"],
            alacritty: ["terminal", "#f5a97f"],
            thunderbird: ["mail", "#7a8cff"],
            geary: ["mail", "#8fa0c8"],
            loupe: ["image", "#f2a7c3"],
            imv: ["image", "#c9a0ff"],
            gwenview: ["image", "#9ccfd8"],
            mpv: ["movie", "#a26eff"],
            celluloid: ["movie", "#ff8a6b"],
            vlc: ["movie", "#ff8800"]
        })

    property int turn: 0

    readonly property string pinned: Catalogue.OPENS.some(o => o.k === SettingsView.hovered?.k) ? SettingsView.hovered.k : ""
    readonly property var kind: root.pinned ? Catalogue.OPENS.find(o => o.k === root.pinned) : Catalogue.OPENS[root.turn % Catalogue.OPENS.length]
    readonly property string app: String(SettingsState.v(root.kind.k))
    readonly property var appLook: root.look[root.app] ?? ["apps", Appearance.colour.accent]

    property real t: 1

    NumberAnimation on t {
        id: fly

        from: 0
        to: 1
        duration: 2000
        running: false
    }

    Timer {
        interval: 2000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.pinned)
                root.turn++;
            if (SettingsView.reduceMotion)
                root.t = 1;
            else
                fly.restart();
        }
    }

    readonly property var chipFrames: [[0, {
                x: 0,
                y: 58,
                o: 0,
                s: 0.9
            }], [[10, 22], {
                x: 0,
                y: 58,
                o: 1,
                s: 1
            }], [42, {
                x: 36,
                y: 18,
                o: 1,
                s: 0.85
            }], [58, {
                x: 100,
                y: 58,
                o: 1,
                s: 0.4
            }], [[64, 100], {
                x: 100,
                y: 58,
                o: 0,
                s: 0.2
            }]]
    readonly property var popFrames: [[[0, 56], {
                s: 1
            }], [64, {
                s: 1.18
            }], [[74, 100], {
                s: 1
            }]]
    readonly property var trailFrames: [[[0, 20], {
                o: 0.2
            }], [40, {
                o: 1
            }], [[70, 100], {
                o: 0.2
            }]]

    Item {
        id: opens

        x: 20
        y: 20
        width: parent.width - 40
        height: parent.height - 20 - 48

        Shape {
            x: 0
            y: opens.height * 0.3
            width: opens.width
            height: opens.height * 0.4
            opacity: Frames.at(root.trailFrames, root.t, Frames.LINEAR).o
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Appearance.colour.fillStronger
                strokeWidth: 2
                strokeStyle: ShapePath.DashLine
                dashPattern: [1.5, 2.5]
                startX: 0.08 * opens.width
                startY: 0.75 * opens.height * 0.4

                PathQuad {
                    controlX: 0.5 * opens.width
                    controlY: -0.15 * opens.height * 0.4
                    x: 0.92 * opens.width
                    y: 0.75 * opens.height * 0.4
                }
            }
        }

        Item {
            id: chip

            readonly property var f: Frames.at(root.chipFrames, root.t, Frames.STANDARD)

            x: chip.f.x >= 100 ? opens.width - 96 : chip.f.x / 100 * opens.width
            y: chip.f.y / 100 * opens.height - height / 2
            width: Math.min(chipRow.implicitWidth + 20, opens.width * 0.6)
            height: chipRow.implicitHeight + 8
            opacity: chip.f.o
            scale: chip.f.s

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fillStrong
            }

            Row {
                id: chipRow

                x: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.kind.icon
                    color: Appearance.colour.accent
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, opens.width * 0.6 - 46)
                    text: root.kind.thing
                    elide: Text.ElideRight
                }
            }
        }

        Column {
            anchors.right: parent.right
            y: 0.58 * opens.height - height / 2
            spacing: 6

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 64
                scale: Frames.at(root.popFrames, root.t, Frames.BACK).s

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.large
                    color: Appearance.blend(Appearance.colour.surfaceSolid, root.appLook[1], 0.22)
                    stroke: Qt.rgba(Qt.color(root.appLook[1]).r, Qt.color(root.appLook[1]).g, Qt.color(root.appLook[1]).b, 0.5)
                    strokeWidth: 2
                }

                Icon {
                    anchors.centerIn: parent
                    name: root.appLook[0]
                    size: 34
                    fill: 1
                    color: root.appLook[1]
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.app
                color: Appearance.colour.textDim
            }
        }
    }

    SceneCaption {
        text: `${root.kind.what} opens in ${root.app}`
    }
}
