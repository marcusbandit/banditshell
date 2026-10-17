pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.media
import qs.services

Column {
    id: root

    property string family: Appearance.font.lock

    property bool watched: true

    readonly property bool music: Media.hasTrack
    readonly property bool unplugged: Battery.available && Battery.onBattery
    readonly property bool noticed: alerts.total > 0

    readonly property real artSize: Appearance.font.line.small + Appearance.padding.small * 2

    readonly property real reach: root.implicitHeight + (root.music ? (deck.height + Appearance.padding.normal) * (1 - open.value) : 0)
    readonly property real deckWidth: Appearance.sizes.lockField * 0.8

    readonly property string remaining: {
        const s = Battery.secondsLeft;
        if (s <= 0)
            return "";
        const hours = Math.floor(s / 3600);
        const minutes = Math.round((s % 3600) / 60);
        return hours > 0 ? `${hours} h ${minutes} min left` : `${minutes} min left`;
    }

    spacing: Appearance.padding.large

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.noticed
        spacing: Appearance.padding.normal

        LockAlerts {
            id: alerts

            anchors.verticalCenter: parent.verticalCenter
            family: root.family
            badged: false
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: alerts.total === 1 ? "1 notification" : `${alerts.total} notifications`
            color: Appearance.colour.textDim
            font.family: root.family
            font.pixelSize: Appearance.font.size.small
            font.variableAxes: ({ "wght": 500 })
            renderType: Text.NativeRendering
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.unplugged
        spacing: Appearance.padding.normal

        BatteryMeter {
            anchors.verticalCenter: parent.verticalCenter
            level: Battery.percentage
            charging: Battery.charging
            low: Battery.percentage <= Battery.lowThreshold
            colour: Appearance.colour.textDim
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.remaining !== "" ? `${Battery.percent}%, ${root.remaining}` : `${Battery.percent}%`
            color: Appearance.colour.textDim
            font.family: root.family
            font.pixelSize: Appearance.font.size.small
            font.features: ({ "tnum": 1 })
            renderType: Text.NativeRendering
        }
    }

    Item {
        id: player

        objectName: "player"
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.deckWidth
        height: line.height + (deck.height + Appearance.padding.normal) * open.value
        visible: root.music

        property bool pinned: false

        readonly property bool wanted: near.hovered || player.pinned

        Follow {
            id: open

            target: player.wanted ? 1 : 0
            speed: player.wanted ? Appearance.animation.revealSpeed : Appearance.animation.revealSpeed * 0.5
            epsilon: 0.004
        }

        HoverHandler {
            id: near

            margin: Appearance.padding.large
        }

        TapHandler {
            onTapped: player.pinned = !player.pinned
        }

        Row {
            id: line

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.normal
            opacity: 0.6 + 0.4 * open.value

            ArtCrossfade {
                anchors.verticalCenter: parent.verticalCenter
                width: root.artSize
                height: root.artSize
                radius: Appearance.rounding.small
                source: Media.artUrl
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    width: Math.min(implicitWidth, root.deckWidth - root.artSize * 2)
                    text: Media.title
                    color: Appearance.colour.text
                    elide: Text.ElideRight
                    font.family: root.family
                    font.pixelSize: Appearance.font.size.small
                    font.variableAxes: ({ "wght": 550 })
                    renderType: Text.NativeRendering
                }

                Text {
                    width: Math.min(implicitWidth, root.deckWidth - root.artSize * 2)
                    visible: !!Media.artist
                    text: Media.artist
                    color: Appearance.colour.textDim
                    elide: Text.ElideRight
                    font.family: root.family
                    font.pixelSize: Appearance.font.size.small
                    renderType: Text.NativeRendering
                }
            }

            Equalizer {
                anchors.verticalCenter: parent.verticalCenter
                playing: Media.playing && !Appearance.lessMotion
                color: Appearance.colour.accent
            }
        }

        Column {
            id: deck

            y: line.height + Appearance.padding.normal * open.value
            width: parent.width
            spacing: Appearance.padding.small
            opacity: open.value
            enabled: open.value > 0.5

            Scrubber {
                width: parent.width
                visible: Media.length > 0
                watched: root.watched && root.music && open.value > 0.01
                family: root.family
            }

            MediaTransport {
                anchors.horizontalCenter: parent.horizontalCenter
                zoom: 0.85
            }
        }
    }
}
