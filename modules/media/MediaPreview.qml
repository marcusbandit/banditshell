pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property real trackMax: Appearance.sizes.notchTrack

    property bool watched: true

    readonly property real trackWidth: Math.min(root.trackMax, Math.ceil(Math.max(titleSize.advanceWidth, subSize.advanceWidth)))

    readonly property real columnWidth: Math.max(root.trackWidth, transport.implicitWidth)

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

    Item {
        id: block

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.implicitWidth
        height: root.artSize

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

                size: Math.round(root.artSize / 2)
                name: "music_note"
                color: Appearance.colour.textFaint
            }

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

    Scrubber {
        id: progress

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: block.width
        visible: Media.length > 0
        watched: root.watched
    }
}
