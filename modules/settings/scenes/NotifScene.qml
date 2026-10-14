import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "keyframes.js" as Frames

Item {
    id: root

    readonly property real stageHeight: 220
    readonly property int timeout: SettingsState.v("notifTimeout")
    readonly property bool island: SettingsState.v("notifPlace") === "island"

    SceneClock {
        id: clock

        duration: Math.round((root.timeout + 1.6) * 1000)
        still: 0.5
    }

    readonly property var slide: [[0, {
                x: 1.2
            }], [[10, 88], {
                x: 0
            }], [100, {
                x: 1.2
            }]]
    readonly property var drain: [[[0, 10], {
                w: 1
            }], [[88, 100], {
                w: 0
            }]]

    Item {
        id: card

        readonly property real home: root.width - width - Appearance.padding.card
        readonly property real away: Frames.at(root.slide, clock.value, Frames.ARRIVE).x

        x: root.island ? (root.width - width) / 2 : card.home + card.away * width
        y: root.island ? Appearance.padding.card - card.away * (height + Appearance.padding.card) : Appearance.padding.card
        width: 300
        height: body.implicitHeight + Appearance.padding.card * 2
        clip: true

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.surfaceSolid
        }

        Column {
            id: body

            x: Appearance.padding.card
            y: Appearance.padding.card
            width: parent.width - Appearance.padding.card * 2
            spacing: 4

            Item {
                width: parent.width
                height: Appearance.font.line.small

                Row {
                    spacing: Appearance.padding.small

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "chat"
                        color: Appearance.colour.accent
                    }

                    StyledText {
                        text: "signal"
                        color: Appearance.colour.textFaint
                    }
                }

                StyledText {
                    anchors.right: parent.right
                    text: "now"
                    color: Appearance.colour.textFaint
                }
            }

            StyledText {
                text: "ida"
            }

            StyledText {
                width: parent.width
                text: "still on for climbing at 7?"
                color: Appearance.colour.textDim
                wrapMode: Text.WordWrap
            }
        }

        Rectangle {
            y: parent.height - 2
            width: parent.width * Frames.at(root.drain, clock.value, Frames.LINEAR).w
            height: 2
            color: Appearance.colour.accent
        }
    }

    SceneCaption {
        text: `${root.island ? "in the island · " : ""}stays ${root.timeout} s · ${SettingsState.v("notifPopups")} at once${SettingsState.v("dnd") ? " · quiet now" : ""}`
    }
}
