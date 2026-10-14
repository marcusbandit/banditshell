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

    readonly property bool singing: root.watched && Lyrics.synced
    property int current: -1

    implicitHeight: column.implicitHeight

    FrameAnimation {
        running: root.singing

        onTriggered: root.current = Lyrics.indexAt(Media.now())
    }

    Column {
        id: column

        width: root.width
        spacing: Appearance.padding.normal

        Item {
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

            Column {
                id: words

                anchors.left: cover.right
                anchors.leftMargin: Appearance.padding.normal
                anchors.right: side.left
                anchors.rightMargin: Appearance.padding.small
                anchors.verticalCenter: cover.verticalCenter
                spacing: Appearance.padding.small / 2

                CrossfadeText {
                    width: parent.width
                    text: Media.title
                    pixelSize: Appearance.font.size.normal
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }

                CrossfadeText {
                    width: parent.width
                    text: Media.artist
                    color: Appearance.colour.textDim
                    visible: !!Media.artist
                }

                CrossfadeText {
                    width: parent.width
                    text: Media.album || Media.app
                    color: Appearance.colour.textFaint
                    visible: !!Media.album || !!Media.app
                }
            }

            MouseArea {
                anchors.fill: words
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

                    anchors.top: parent.top
                    anchors.right: parent.right
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
                    anchors.horizontalCenter: grow.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Appearance.padding.small
                    playing: Media.playing
                    color: Appearance.colour.accent
                }
            }
        }

        Scrubber {
            width: parent.width
            visible: Media.length > 0 || Media.hasTrack
            watched: root.watched
        }

        CrossfadeText {
            readonly property var line: root.current >= 0 ? Lyrics.lines[root.current] : null

            width: parent.width
            visible: root.singing
            text: line && !line.gap ? line.text : ""
            color: Appearance.colour.textDim
            horizontalAlignment: Text.AlignHCenter
        }

        MediaTransport {
            anchors.horizontalCenter: parent.horizontalCenter
            extended: true
        }
    }
}
