import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "../boards.js" as Boards

Item {
    id: root

    readonly property real stageHeight: 260

    readonly property var output: Monitors.active.find(m => m.name.startsWith("eDP")) ?? Monitors.active[0] ?? null
    readonly property var shape: root.output ? Monitors.layoutOf(root.output) : {
        w: 16,
        h: 10
    }
    readonly property real aspect: root.shape.w / Math.max(1, root.shape.h)
    readonly property bool board: SettingsState.v("autoKeyboard")
    readonly property bool docked: SettingsState.v("docked")
    readonly property real share: SettingsState.v("boardHeight")
    readonly property var ansi: Boards.board("ansi")

    Follow {
        id: lift

        target: root.board && root.docked ? root.share : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
    }

    Follow {
        id: rise

        target: root.board ? root.share : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
    }

    Follow {
        id: edge

        target: SettingsState.v("touchEdges") ? 0.06 : 0.02
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
    }

    Item {
        id: fit

        x: 24
        y: 20
        width: parent.width - 48
        height: parent.height - 20 - 48

        Item {
            id: screen

            height: Math.min(fit.height, fit.width / root.aspect)
            width: screen.height * root.aspect
            anchors.centerIn: parent
            clip: true

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colour.fill
                stroke: Appearance.colour.fillStronger
                strokeWidth: Appearance.stroke.ring
            }

            Rectangle {
                width: screen.width * edge.value
                height: parent.height
                color: Appearance.colour.accentFill
            }

            Rectangle {
                x: parent.width - width
                width: screen.width * edge.value
                height: parent.height
                color: Appearance.colour.accentFill
            }

            SquircleRect {
                x: screen.width * 0.1
                y: screen.height * 0.08
                width: screen.width * 0.8
                height: screen.height * (1 - 0.08 - lift.value)
                radius: 6
                color: Appearance.colour.fillStrong

                Icon {
                    anchors.centerIn: parent
                    name: "edit_note"
                    color: Appearance.colour.textDim
                }
            }

            Rectangle {
                y: screen.height * (1 - rise.value)
                width: screen.width
                height: screen.height * rise.value
                visible: height > 0.5
                color: root.docked ? Appearance.colour.surfaceSolid : Appearance.colour.surface

                KeyboardBoard {
                    x: parent.width * 0.03
                    y: parent.height * 0.04
                    width: parent.width * 0.94
                    height: parent.height * 0.92
                    keys: root.ansi
                    flat: true
                    tips: false
                }
            }
        }
    }

    SceneCaption {
        text: `${root.output?.name ?? "screen"} · ${root.board ? `board ${Math.round(root.share * 100)}% · ${root.docked ? "takes room" : "floats"}` : "no board on fold"}`
    }
}
