pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.media
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

    // Progress, and the way to move it. This used to be a read-only bar, on
    // the argument that seeking is a capability MPRIS players advertise one
    // by one and a scrubber that silently does nothing on half of them is
    // worse than none. The scrubber answers that itself: it takes a hand only
    // while the player says it can seek, and marks the position either way.
    // The same one the notch's preview draws, with its two times under it.
    Scrubber {
        width: parent.width
        visible: Media.available && Media.length > 0
    }

    // Transport. Centred, because it is the one thing in this menu you aim at.
    //
    // The same component the notch's preview uses, so there is ONE set of media
    // buttons in the shell rather than two that drift. It used to be a filled
    // disc and two bare glyphs; the ring is Niagara's, and it is the better
    // answer for a translucent material anyway (see MediaTransport.qml).
    MediaTransport {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: Media.available
        width: parent.width
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
