import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "keyframes.js" as Frames

Item {
    id: root

    readonly property real stageHeight: 220
    readonly property int outline: SettingsState.v("outline")

    SceneClock {
        id: clock

        duration: 3600
        still: 0.7
    }

    readonly property var drag: [[[0, 10], {
                w: 0,
                h: 0,
                o: 1,
                cx: 18,
                cy: 18
            }], [[55, 85], {
                w: 64,
                h: 56,
                o: 1,
                cx: 82,
                cy: 74
            }], [[95, 100], {
                w: 64,
                h: 56,
                o: 0,
                cx: 82,
                cy: 74
            }]]

    readonly property var f: Frames.at(root.drag, clock.value, Frames.STANDARD)

    Item {
        id: area

        width: parent.width
        height: parent.height - 32
        clip: true

        readonly property real sx: 0.18 * width
        readonly property real sy: 0.18 * height
        readonly property real sw: root.f.w / 100 * width
        readonly property real sh: root.f.h / 100 * height

        Rectangle {
            anchors.fill: parent
            color: Appearance.withAlpha(Appearance.colour.scrim, 0.25)
        }

        Rectangle {
            width: parent.width
            height: area.sy
            color: Appearance.withAlpha(Appearance.colour.scrim, 0.25 * root.f.o)
        }

        Rectangle {
            y: area.sy + area.sh
            width: parent.width
            height: parent.height - y
            color: Appearance.withAlpha(Appearance.colour.scrim, 0.25 * root.f.o)
        }

        Rectangle {
            y: area.sy
            width: area.sx
            height: area.sh
            color: Appearance.withAlpha(Appearance.colour.scrim, 0.25 * root.f.o)
        }

        Rectangle {
            x: area.sx + area.sw
            y: area.sy
            width: parent.width - x
            height: area.sh
            color: Appearance.withAlpha(Appearance.colour.scrim, 0.25 * root.f.o)
        }

        SquircleRect {
            x: area.sx
            y: area.sy
            width: area.sw + root.outline * 2
            height: area.sh + root.outline * 2
            radius: 2
            cornerPower: 2
            color: "transparent"
            stroke: Appearance.colour.accent
            strokeWidth: root.outline
            opacity: root.f.o
            visible: root.outline > 0
        }

        Item {
            x: area.sx - 2
            y: area.sy - 32
            width: tag.implicitWidth + 12
            height: Appearance.font.line.small
            opacity: root.f.o

            SquircleRect {
                anchors.fill: parent
                radius: 6
                color: Appearance.colour.accent
            }

            StyledText {
                id: tag

                anchors.centerIn: parent
                text: "412 × 236"
                color: Appearance.colour.accentText
            }
        }

        Icon {
            x: root.f.cx / 100 * area.width
            y: root.f.cy / 100 * area.height
            name: "near_me"
            size: Appearance.icon.normal
            fill: 1
            color: Appearance.colour.paper
            opacity: root.f.o
        }
    }

    SceneCaption {
        text: `${root.outline ? `${root.outline} px outline` : "no outline"} · opens in ${String(SettingsState.v("shotEditor")).split(" ")[0] || "nothing"}`
    }
}
