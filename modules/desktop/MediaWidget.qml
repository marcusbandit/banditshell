pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

WidgetCard {
    id: root

    property bool running: true
    property real progress: 0

    function measure(): void {
        root.progress = Media.length > 0 ? Math.max(0, Math.min(1, Media.now() / Media.length)) : 0;
    }

    title: Media.playing ? "Now playing" : "Paused"
    aside: Media.app

    Component.onCompleted: root.measure()

    Timer {
        interval: 1000
        repeat: true
        running: root.running && root.visible && Media.playing
        triggeredOnStart: true
        onTriggered: root.measure()
    }

    Connections {
        target: Media

        function onTrackKeyChanged(): void {
            root.measure();
        }

        function onPlayingChanged(): void {
            root.measure();
        }
    }

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
                elide: Text.ElideRight
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
                    onClicked: Media.previous()
                }

                Press {
                    icon: Media.playing ? "pause" : "play_arrow"
                    strong: true
                    onClicked: Media.toggle()
                }

                Press {
                    icon: "skip_next"
                    onClicked: Media.next()
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 4
        visible: Media.length > 0

        SquircleRect {
            anchors.fill: parent
            pill: "place"
            color: Appearance.colour.fillStrong
        }

        SquircleRect {
            width: Math.max(height, parent.width * root.progress)
            height: parent.height
            pill: "place"
            color: Appearance.colour.accent
        }
    }

    component Press: Item {
        id: press

        property string icon: ""
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
    }
}
