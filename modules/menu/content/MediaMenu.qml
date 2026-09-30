pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.media
import qs.services

Column {
    id: root

    spacing: Appearance.padding.normal

    Item {
        width: parent.width
        implicitHeight: Math.max(art.height, info.implicitHeight)
        visible: Media.available

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

    Scrubber {
        width: parent.width
        visible: Media.available && Media.length > 0
    }

    MediaTransport {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: Media.available
        width: parent.width
    }

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
