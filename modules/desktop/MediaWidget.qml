pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.media

WidgetCard {
    id: root

    property bool running: true

    title: Media.playing ? "Now playing" : "Paused"
    aside: Media.app

    Item {
        width: parent.width
        height: Math.max(art.height, words.implicitHeight)

        Item {
            id: art

            width: 64
            height: 64

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fillStrong
            }

            Icon {
                anchors.centerIn: parent
                visible: !cover.ready
                name: "music_note"
                color: Appearance.colour.textFaint
            }

            SquircleImage {
                id: cover

                anchors.fill: parent
                source: Media.artUrl
                radius: Appearance.rounding.normal
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.open("media", {})
            }
        }

        Column {
            id: words

            x: art.width + Appearance.padding.card
            width: parent.width - x
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                text: Media.title
                font.pixelSize: Appearance.font.size.normal
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.open("media", {})
                }
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: Media.artist
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            Row {
                topPadding: Appearance.padding.small
                spacing: Appearance.padding.small

                Press {
                    icon: "skip_previous"
                    tip: "Previous"
                    onClicked: Media.previous()
                }

                Press {
                    icon: Media.playing ? "pause" : "play_arrow"
                    tip: Media.playing ? "Pause" : "Play"
                    strong: true
                    onClicked: Media.toggle()
                }

                Press {
                    icon: "skip_next"
                    tip: "Next"
                    onClicked: Media.next()
                }
            }
        }
    }

    Scrubber {
        width: parent.width
        watched: root.running
        perPixel: true
    }

    component Press: Item {
        id: press

        property string icon: ""
        property string tip: ""
        property bool strong: false

        signal clicked

        width: 32
        height: 32

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: press.strong ? Appearance.colour.accentFill : Appearance.colour.fill
            opacity: press.strong ? 1 : lit.value

            Follow {
                id: lit

                target: pressHover.hovered ? 1 : 0
                speed: Appearance.animation.revealSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: true
            }
        }

        Icon {
            anchors.centerIn: parent
            name: press.icon
            fill: 1
            color: press.strong ? Appearance.colour.accent : Appearance.colour.textDim
        }

        HoverHandler {
            id: pressHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: press.clicked()
        }

        FloatingTooltip {
            text: press.tip
            shown: pressHover.hovered
        }
    }
}
