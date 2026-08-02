pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// What is playing, in as little room as it can be said in.
//
// This is the AMBIENT half of the notch (DESIGN.md 2.4). Going to the top of the
// screen asks for the TIME, so the time stays the focus and this rides under it,
// smaller and dimmer: the thing you did not ask for but would want to see while
// you are up there anyway. The transport lives in the media menu; the one control
// here is the one you would reach for without looking, so pressing the artwork
// plays and pauses and nothing else is offered.
//
// It does not size its host. It takes a ceiling for the track line, reports what
// it would LIKE to be, and lays out inside whatever width it is given, so the
// same preview fits a notch, a menu or a lock screen without being told which.
Item {
    id: root

    // How wide the track line may get before it elides.
    property real trackMax: Appearance.sizes.notchTrack

    // MEASURED, not read off the labels. A label's `implicitWidth` feeding a
    // width that is then bound back onto that label is a loop waiting to be
    // tripped; TextMetrics answers the same question from outside the layout.
    readonly property real trackWidth: Math.min(root.trackMax, Math.ceil(Math.max(titleSize.advanceWidth, subSize.advanceWidth)))

    // Square, and exactly the two lines beside it, so the block reads as one
    // object rather than as a picture with some text near it. Two lines whether
    // or not the second one has anything in it: a player that reports no artist
    // must not make the artwork half the size it is for one that does.
    readonly property real artSize: Math.round(title.lineHeight * 2)

    implicitWidth: root.artSize + Appearance.padding.normal + root.trackWidth
    implicitHeight: track.height + (progress.visible ? Appearance.padding.normal + progress.height : 0)

    TextMetrics {
        id: titleSize

        font: title.font
        text: title.text
    }

    TextMetrics {
        id: subSize

        font: sub.font
        text: sub.text
    }

    // The artwork and what it is. Centred rather than left-aligned, because the
    // host may be wider than this asked for (the clock above it is the other
    // thing setting the width) and a block hard against one edge of a notch
    // reads as a mistake.
    Item {
        id: track

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.implicitWidth
        height: root.artSize

        // Album art, and a plate shaped like album art when there is none, so
        // the preview does not change height from one track to the next.
        G2Rect {
            id: art

            width: root.artSize
            height: width
            radius: Appearance.rounding.small
            color: Appearance.colour.fill

            Image {
                id: cover

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
                visible: !cover.visible
                name: "music_note"
                color: Appearance.colour.textFaint
            }

            // The one control. It is not drawn until the cursor is on the
            // artwork: a play button sitting permanently on the album art would
            // make the preview a widget, and it is meant to be a glance.
            G2Rect {
                anchors.fill: parent
                radius: art.radius
                color: Appearance.colour.scrim
                opacity: press.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: Media.playing ? "pause" : "play_arrow"
                }
            }

            MouseArea {
                id: press

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.toggle()
            }
        }

        Column {
            anchors.left: art.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.verticalCenter: art.verticalCenter
            spacing: 0

            StyledText {
                id: title

                width: root.trackWidth
                text: Media.title
                elide: Text.ElideRight
            }

            // The artist, or failing that whoever is playing it. One line, not
            // two: a preview that lists everything MPRIS knows is the menu.
            StyledText {
                id: sub

                width: root.trackWidth
                text: Media.artist || Media.app
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }
        }
    }

    // How far in it is. Read-only, and exactly as wide as the block above it
    // rather than as wide as the host: the artwork, the name and the progress
    // are one object, and a line that runs past the ends of it belongs to the
    // notch instead. It also keeps them from disagreeing while the host is still
    // smoothing its way to a new size. Hidden for anything without a length,
    // which is every stream: a bar that can never fill is a bar that lies.
    Slider {
        id: progress

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: track.width
        visible: Media.length > 0
        value: Media.progress
        enabled: false
    }
}
