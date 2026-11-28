pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.media

DeskWidget {
    id: root

    property bool running: true
    property real progress: 0

    readonly property real pad: Appearance.padding.card

    function measure(): void {
        root.progress = Media.length > 0 ? Math.max(0, Math.min(1, Media.now() / Media.length)) : 0;
    }

    key: "media"
    fallbackSize: "small"

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.running && root.visible && root.form !== "large"
        onTriggered: root.measure()
    }

    Connections {
        target: Media

        function onPositionChanged(): void {
            root.measure();
        }

        function onLengthChanged(): void {
            root.measure();
        }
    }

    small: Item {
        implicitWidth: Math.round(Appearance.font.size.small * 18) + root.pad * 2
        implicitHeight: smallArt.height + Appearance.padding.normal * 2

        Art {
            id: smallArt

            x: Appearance.padding.normal
            y: Appearance.padding.normal
            size: Math.round(Appearance.font.size.small * 2.6)
            corner: Appearance.rounding.small
        }

        Column {
            x: smallArt.x + smallArt.width + Appearance.padding.normal
            width: smallPlay.x - x - Appearance.padding.small
            anchors.verticalCenter: smallArt.verticalCenter

            StyledText {
                width: parent.width
                text: Media.title
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: Media.artist
                color: Appearance.colour.textDim
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }

        Press {
            id: smallPlay

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: smallArt.verticalCenter
            icon: Media.playing ? "pause" : "play_arrow"
            onClicked: Media.toggle()
        }
    }

    medium: Item {
        readonly property real wordsHeight: Appearance.font.line.normal * 2 + Appearance.font.line.small + 2

        implicitWidth: Math.round(Appearance.font.size.small * 24) + root.pad * 2
        implicitHeight: Math.max(mediumArt.y + mediumArt.height, mediumControls.y + mediumControls.height) + root.pad

        Art {
            id: mediumArt

            x: root.pad
            y: root.pad
            size: Math.round(Appearance.font.size.small * 6.4)
        }

        Column {
            x: mediumArt.x + mediumArt.width + root.pad
            width: parent.width - x - root.pad
            y: root.pad
            spacing: 2

            Words {
                width: parent.width
                lines: 2
            }
        }

        Controls {
            id: mediumControls

            x: mediumArt.x + mediumArt.width + root.pad - Appearance.padding.small
            y: root.pad + Math.max(mediumArt.height - height - Appearance.padding.small, parent.wordsHeight)
        }

        Item {
            x: mediumControls.x + mediumControls.width + Appearance.padding.normal
            width: parent.width - x - root.pad
            height: 3
            anchors.verticalCenter: mediumControls.verticalCenter
            visible: Media.length > 0

            SquircleRect {
                anchors.fill: parent
                pill: "object"
                color: Appearance.colour.fillStrong
            }

            SquircleRect {
                width: Math.max(parent.height, parent.width * root.progress)
                height: parent.height
                pill: "object"
                color: Appearance.colour.text
            }
        }
    }

    large: Item {
        implicitWidth: Math.round(Appearance.font.size.small * 20) + root.pad * 2
        implicitHeight: body.implicitHeight + root.pad * 2

        Column {
            id: body

            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
            spacing: Appearance.padding.large

            Art {
                size: parent.width
                corner: Appearance.rounding.large

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Panels.open("media", {})
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Words {
                    width: parent.width
                    lines: 2
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: Media.app
                    color: Appearance.colour.textFaint
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }

            Scrubber {
                width: parent.width
                visible: Media.length > 0
                watched: root.running && root.form === "large"
                perPixel: true
            }

            Controls {
                anchors.horizontalCenter: parent.horizontalCenter
                big: true
            }
        }
    }

    component Art: Item {
        id: art

        property real size: 64
        property real corner: Appearance.rounding.normal

        width: art.size
        height: art.size

        SquircleRect {
            anchors.fill: parent
            radius: art.corner
            color: Appearance.colour.fill
        }

        Icon {
            anchors.centerIn: parent
            visible: !cover.ready
            name: "music_note"
            size: Math.round(art.size * 0.4)
            color: Appearance.colour.textFaint
        }

        SquircleImage {
            id: cover

            anchors.fill: parent
            source: Media.artUrl
            radius: art.corner
        }
    }

    component Words: Column {
        id: words

        property int lines: 1

        spacing: 2

        StyledText {
            width: parent.width
            text: Media.title
            font.pixelSize: Appearance.font.size.normal
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: words.lines
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            visible: text !== ""
            text: Media.artist
            color: Appearance.colour.textDim
            elide: Text.ElideRight
        }
    }

    component Controls: Row {
        id: controls

        property bool big: false

        spacing: controls.big ? Appearance.padding.large : 0

        Press {
            icon: "skip_previous"
            big: controls.big
            onClicked: Media.previous()
        }

        Press {
            icon: Media.playing ? "pause" : "play_arrow"
            big: controls.big
            main: true
            onClicked: Media.toggle()
        }

        Press {
            icon: "skip_next"
            big: controls.big
            onClicked: Media.next()
        }
    }

    component Press: Item {
        id: press

        property string icon: ""
        property bool big: false
        property bool main: false

        signal clicked

        width: Math.round(Appearance.font.iconSize * (press.big ? (press.main ? 2.6 : 2.1) : 1.8))
        height: press.width

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: Appearance.colour.fill
            opacity: pressHover.hovered ? 1 : 0
        }

        Icon {
            anchors.centerIn: parent
            name: press.icon
            size: Math.round(Appearance.font.iconSize * (press.big ? (press.main ? 1.6 : 1.25) : 1.05))
            fill: 1
            color: press.main ? Appearance.colour.text : Appearance.colour.textDim
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
