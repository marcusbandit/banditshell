pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Whatever is playing. This one is real.
Column {
    id: root

    spacing: Appearance.padding.normal

    Item {
        width: parent.width
        implicitHeight: Math.max(art.height, info.implicitHeight)
        visible: Media.available

        // Album art when there is any, and a placeholder shaped like album art
        // when there is not, so the row does not change height per track.
        G2Rect {
            id: art

            width: Appearance.sizes.rowHeight * 1.6
            height: width
            radius: Appearance.rounding.small
            color: Appearance.colour.fill

            Image {
                anchors.fill: parent
                source: Media.artUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                sourceSize.width: width
                sourceSize.height: height
            }

            Icon {
                anchors.centerIn: parent
                visible: !Media.artUrl
                name: "music_note"
                color: Appearance.colour.textFaint
            }
        }

        Column {
            id: info

            anchors.left: art.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right
            anchors.verticalCenter: art.verticalCenter
            spacing: 0

            StyledText {
                width: parent.width
                text: Media.title
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: !!Media.artist
                text: Media.artist
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: !!Media.app
                text: Media.app
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
                elide: Text.ElideRight
            }
        }
    }

    // Progress. Read-only: seeking is a separate capability MPRIS players
    // advertise individually, and a scrubber that silently does nothing on half
    // of them is worse than none.
    Item {
        width: parent.width
        visible: Media.available && Media.length > 0
        implicitHeight: bar.height + elapsed.implicitHeight + Appearance.padding.small

        Slider {
            id: bar

            width: parent.width
            value: Media.progress
            enabled: false
        }

        StyledText {
            id: elapsed

            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: Media.timeLabel(Media.position)
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
        }

        StyledText {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: Media.timeLabel(Media.length)
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
        }
    }

    // Transport. Centred, because it is the one thing in this menu you aim at.
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: Media.available
        spacing: Appearance.padding.large

        Repeater {
            model: [
                {
                    icon: "skip_previous",
                    action: "previous",
                    enabled: !!Media.active?.canGoPrevious
                },
                {
                    icon: Media.playing ? "pause" : "play_arrow",
                    action: "toggle",
                    enabled: true,
                    primary: true
                },
                {
                    icon: "skip_next",
                    action: "next",
                    enabled: !!Media.active?.canGoNext
                }
            ]

            delegate: G2Rect {
                id: button

                required property var modelData

                width: modelData.primary ? Appearance.sizes.rowHeight : Appearance.sizes.rowHeight * 0.85
                height: width
                radius: width / 2
                color: modelData.primary ? Appearance.colour.fillStronger : press.containsMouse ? Appearance.colour.fillStrong : "transparent"

                Icon {
                    anchors.centerIn: parent
                    name: button.modelData.icon
                    color: button.modelData.enabled ? Appearance.colour.text : Appearance.colour.textFaint
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: button.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (button.modelData.action === "toggle")
                            Media.toggle();
                        else if (button.modelData.action === "next")
                            Media.next();
                        else
                            Media.previous();
                    }
                }
            }
        }
    }

    // More than one player is common (a browser registers one per tab), so say
    // which this is controlling and let it be changed.
    Separator {
        width: parent.width
        visible: Media.players.length > 1
    }

    Repeater {
        model: Media.players.length > 1 ? Media.players : []

        delegate: MenuRow {
            required property var modelData

            width: root.width
            icon: modelData.isPlaying ? "play_arrow" : "pause"
            label: modelData.identity || "player"
            detail: modelData.trackTitle || ""
            selected: modelData === Media.active
            onActivated: Media.choose(modelData)
        }
    }

    StyledText {
        visible: !Media.available
        text: "nothing is playing"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }
}
