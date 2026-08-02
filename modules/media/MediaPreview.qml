pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// What is playing, laid out the way Niagara Launcher's media widget is.
//
// Niagara puts a big square cover on the left, the name and the artist stacked
// beside it, and the transport centred UNDER them, so the artwork is exactly as
// tall as everything it is next to and the block reads as one object. The
// alternative, a strip with the art, the text and the buttons all in one row, is
// what every other shell draws and it turns the artwork into a bullet point.
//
// It is the ambient half of the notch (DESIGN.md 2.4). Going to the top of the
// screen asks for the TIME; this rides under it, quieter, as the thing you did
// not ask for but would want while you are up there anyway. Everything here is
// one light at three weights and one outlined ring: no fills, nothing raised.
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

    // The column beside the artwork holds the type AND the transport, so it is
    // as wide as whichever of them needs more. Without this a two-word title
    // would squeeze the buttons out of their own column.
    readonly property real columnWidth: Math.max(root.trackWidth, transport.implicitWidth)

    // Square, and exactly as tall as that column: the Niagara proportion, and
    // the reason the artwork can be this size without looking pasted on.
    readonly property real artSize: stack.implicitHeight

    implicitWidth: root.artSize + Appearance.padding.normal + root.columnWidth
    implicitHeight: block.height + (progress.visible ? Appearance.padding.normal + progress.height : 0)

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

    // Centred rather than left-aligned, because the host may be wider than this
    // asked for (the clock above it is the other thing setting the width) and a
    // block hard against one edge of a notch reads as a mistake.
    Item {
        id: block

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.implicitWidth
        height: root.artSize

        // Album art, and a plate shaped like album art when there is none, so
        // the preview does not change size from one track to the next.
        G2Rect {
            id: art

            width: root.artSize
            height: width
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill

            G2Image {
                id: cover

                anchors.fill: parent
                source: Media.artUrl
                radius: art.radius
            }

            Icon {
                anchors.centerIn: parent
                visible: !cover.ready
                // Half the plate. The shell's text-side icon size is meant to
                // sit beside a line of body text, and this plate is a cover:
                // dropped in at that size the note is a speck in a box.
                size: Math.round(root.artSize / 2)
                name: "music_note"
                color: Appearance.colour.textFaint
            }

            // The way back to the application. The preview can say what is
            // playing and never what it IS, so pressing the cover raises the
            // player that knows. Not drawn until the cursor is on it: a badge
            // parked on an album cover makes a glance into a widget.
            G2Rect {
                anchors.fill: parent
                visible: Media.canRaise
                radius: art.radius
                color: Appearance.colour.scrim
                opacity: open.containsMouse ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Icon {
                    anchors.centerIn: parent
                    name: "open_in_new"
                }
            }

            MouseArea {
                id: open

                anchors.fill: parent
                hoverEnabled: true
                enabled: Media.canRaise
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.raise()
            }
        }

        Column {
            id: stack

            anchors.left: art.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.verticalCenter: art.verticalCenter
            width: root.columnWidth
            spacing: Appearance.padding.normal

            Column {
                width: parent.width
                spacing: 0

                StyledText {
                    id: title

                    width: parent.width
                    text: Media.title
                    elide: Text.ElideRight
                }

                // The artist, or failing that whoever is playing it. One line,
                // not two: a preview that lists everything MPRIS knows is the
                // menu.
                StyledText {
                    id: sub

                    width: parent.width
                    text: Media.artist || Media.app
                    color: Appearance.colour.textDim
                    elide: Text.ElideRight
                }
            }

            MediaTransport {
                id: transport

                width: parent.width
            }
        }
    }

    // How far in it is. Read-only, and exactly as wide as the block above it
    // rather than as wide as the host: the artwork, the name and the transport
    // are one object, and a line that runs past the ends of it belongs to the
    // notch instead. It also keeps them from disagreeing while the host is still
    // smoothing its way to a new size. Hidden for anything without a length,
    // which is every stream: a bar that can never fill is a bar that lies.
    Slider {
        id: progress

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: block.width
        visible: Media.length > 0
        value: Media.progress
        enabled: false
    }
}
