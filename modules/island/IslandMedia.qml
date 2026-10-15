pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.media
import qs.services

Item {
    id: root

    property bool watched: false

    signal expand

    readonly property real artSize: Math.round(Appearance.font.line.small * 3.5)
    readonly property real coverTop: 0

    implicitHeight: column.implicitHeight

    Column {
        id: column

        width: root.width
        spacing: Appearance.padding.normal

        Item {
            id: head

            width: parent.width
            height: root.artSize

            Item {
                id: cover

                width: root.artSize
                height: root.artSize

                DropShadow {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    blur: Appearance.padding.normal
                    offset.y: Appearance.padding.small / 2
                    opacity: art.ready ? 0.7 : 0
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill
                    visible: !art.ready

                    Icon {
                        anchors.centerIn: parent
                        size: Math.round(root.artSize / 3)
                        name: "music_note"
                        color: Appearance.colour.textFaint
                    }
                }

                ArtCrossfade {
                    id: art

                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    source: Media.artUrl
                }

                SquircleRect {
                    anchors.fill: parent
                    visible: Media.canRaise
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.scrim
                    opacity: raise.containsMouse ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.animation.fade.fast
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "open_in_new"
                    }
                }

                MouseArea {
                    id: raise

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: Media.canRaise
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Media.raise()
                }
            }

            SquircleRect {
                anchors.fill: words
                anchors.margins: -Appearance.padding.small
                radius: Appearance.rounding.normal
                color: wordsPress.pressed ? Appearance.colour.fillStrong : Appearance.colour.fill
                opacity: wordsPress.containsMouse ? 1 : 0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.animation.fade.fast
                    }
                }
            }

            TextMetrics {
                id: titleCap

                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.normal
                text: "H"
            }

            Item {
                id: words

                readonly property real groupLine: root.artSize

                anchors.left: cover.right
                anchors.leftMargin: Appearance.padding.normal
                anchors.right: side.left
                anchors.rightMargin: Appearance.padding.small
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                ScrollingText {
                    id: title

                    width: parent.width
                    y: -(title.baselineOffset + titleCap.tightBoundingRect.y)
                    text: Media.title
                    pixelSize: Appearance.font.size.normal
                    running: root.watched
                }

                ScrollingText {
                    id: artist

                    width: parent.width
                    y: words.groupLine - (album.visible ? Appearance.font.line.small : 0) - artist.baselineOffset
                    text: Media.artist
                    color: Appearance.colour.textDim
                    running: root.watched
                    visible: !!Media.artist
                }

                ScrollingText {
                    id: album

                    width: parent.width
                    y: words.groupLine - album.baselineOffset
                    text: Media.album || Media.app
                    color: Appearance.colour.textFaint
                    running: root.watched
                    visible: !!Media.album || !!Media.app
                }
            }

            MouseArea {
                id: wordsPress

                anchors.fill: words
                anchors.margins: -Appearance.padding.small
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expand()
            }

            Item {
                id: side

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: grow.width

                Item {
                    id: grow

                    anchors.right: parent.right
                    anchors.rightMargin: -(width - Appearance.font.iconSize) / 2
                    y: -(height - Appearance.font.iconSize) / 2
                    width: Appearance.sizes.minTarget + Appearance.padding.small
                    height: width

                    scale: growPress.pressed ? Appearance.press.ring : growPress.containsMouse ? Appearance.press.ringHover : 1

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.animation.fast
                            easing.type: Easing.OutCubic
                        }
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "open_in_full"
                        color: growPress.containsMouse ? Appearance.colour.text : Appearance.colour.textDim
                    }

                    MouseArea {
                        id: growPress

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expand()
                    }
                }

                Equalizer {
                    anchors.right: parent.right
                    y: words.groupLine - height
                    playing: Media.playing
                    color: Appearance.colour.accent
                }
            }
        }

        Item {
            readonly property real timesMiddle: scrub.visible ? scrub.height - Appearance.font.line.small / 2 : transport.height / 2
            readonly property real transportY: Math.max(scrub.visible ? scrub.height - Appearance.font.line.small : 0, timesMiddle - transport.height / 2)

            width: parent.width
            height: Math.max(scrub.visible ? scrub.height : 0, transportY + transport.height)

            Scrubber {
                id: scrub

                width: parent.width
                visible: Media.length > 0 || Media.hasTrack
                watched: root.watched
            }

            MediaTransport {
                id: transport

                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.transportY
                extended: true
            }
        }
    }
}
