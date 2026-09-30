pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    spacing: Appearance.padding.normal

    component Level: Item {
        id: level

        required property string glyph
        required property real value
        required property bool muted
        property real max: 1

        property bool urgent: false

        signal requested(real v)
        signal toggled

        implicitHeight: Math.max(mark.implicitHeight, bar.implicitHeight)

        Icon {
            id: mark

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            name: level.glyph
            color: !level.muted ? Appearance.colour.text : level.urgent ? Appearance.colour.accent : Appearance.colour.textFaint

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Appearance.padding.small
                cursorShape: Qt.PointingHandCursor
                onClicked: level.toggled()
            }
        }

        Slider {
            id: bar

            anchors.left: mark.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: readout.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            value: level.value
            to: level.max
            warnAbove: 1
            dimmed: level.muted
            onMoved: v => level.requested(v)
        }

        StyledText {
            id: readout

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: metrics.width
            horizontalAlignment: Text.AlignRight
            text: level.muted ? "muted" : `${Math.round(level.value * 100)}%`
            color: level.muted ? Appearance.colour.textFaint : Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
        }

        TextMetrics {
            id: metrics

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            text: "muted"
        }
    }

    component Channel: Item {
        id: channel

        required property var node

        readonly property string title: Audio.streamLabel(node)
        readonly property bool muted: Audio.streamMuted(node)
        readonly property real value: Audio.streamVolume(node)

        implicitHeight: name.implicitHeight + Appearance.padding.small + bar.implicitHeight

        Item {
            id: art

            anchors.left: parent.left
            anchors.top: parent.top

            width: Appearance.font.iconSize
            height: name.implicitHeight
            opacity: channel.muted ? 0.4 : 1

            Image {
                id: shot

                anchors.centerIn: parent

                width: Appearance.font.iconSize
                height: width
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio

                visible: status === Image.Ready
                source: Apps.iconSourceFor([Audio.streamBinary(channel.node), channel.title])
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
            }

            Icon {
                anchors.centerIn: parent
                visible: !shot.visible
                name: Apps.iconFor(Audio.streamBinary(channel.node) || channel.title)
                color: Appearance.colour.textDim
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Appearance.padding.small
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleStreamMute(channel.node)
            }
        }

        StyledText {
            id: name

            anchors.left: art.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: readout.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.top: parent.top

            text: channel.title
            color: channel.muted ? Appearance.colour.textFaint : Appearance.colour.text
            elide: Text.ElideRight
        }

        StyledText {
            id: readout

            anchors.right: parent.right
            anchors.baseline: name.baseline

            width: metrics.width
            horizontalAlignment: Text.AlignRight
            text: channel.muted ? "muted" : `${Math.round(channel.value * 100)}%`
            color: channel.muted ? Appearance.colour.textFaint : Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
        }

        Slider {
            id: bar

            anchors.left: name.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            value: channel.value
            to: Audio.maxVolume
            warnAbove: 1
            dimmed: channel.muted
            onMoved: v => Audio.setStreamVolume(channel.node, v)
        }

        TextMetrics {
            id: metrics

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            text: "muted"
        }
    }

    StyledText {
        text: "OUTPUT"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Level {
        width: parent.width

        glyph: Audio.muted ? "no_sound" : Audio.deviceIcon(Audio.sink)
        value: Audio.volume
        muted: Audio.muted
        max: Audio.maxVolume
        onRequested: v => Audio.setVolume(v)
        onToggled: Audio.toggleMute()
    }

    StyledText {
        visible: Audio.playing.length > 0
        text: "PLAYING"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Repeater {

        model: Audio.playing

        delegate: Channel {
            required property var modelData

            width: root.width
            node: modelData
        }
    }

    Separator {
        width: parent.width
    }

    StyledText {
        text: "INPUT"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Level {
        width: parent.width

        glyph: Audio.sourceMuted || Audio.sourceVolume <= 0 ? "mic_off" : Audio.deviceIcon(Audio.source)
        value: Audio.sourceVolume
        muted: Audio.sourceMuted
        urgent: true
        onRequested: v => Audio.setSourceVolume(v)
        onToggled: Audio.toggleSourceMute()
    }

    StyledText {
        visible: Audio.recording.length > 0
        text: "RECORDING"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Repeater {
        model: Audio.recording

        delegate: Channel {
            required property var modelData

            width: root.width
            node: modelData
        }
    }

    Separator {
        width: parent.width
    }

    StyledText {
        text: "OUTPUT DEVICE"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Repeater {
        model: Audio.sinks

        delegate: MenuRow {
            id: sinkRow

            required property var modelData

            width: root.width
            icon: Audio.deviceIcon(modelData)
            label: Audio.deviceLabel(modelData)
            detail: Audio.deviceTransport(modelData)
            selected: modelData === Audio.sink
            onActivated: Audio.setSink(modelData)

            Icon {
                visible: sinkRow.selected
                name: "check"
            }
        }
    }

    StyledText {
        text: "INPUT DEVICE"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Repeater {
        model: Audio.sources

        delegate: MenuRow {
            id: sourceRow

            required property var modelData

            width: root.width
            icon: Audio.deviceIcon(modelData)
            label: Audio.deviceLabel(modelData)
            detail: Audio.deviceTransport(modelData)
            selected: modelData === Audio.source
            onActivated: Audio.setSource(modelData)

            Icon {
                visible: sourceRow.selected
                name: "check"
            }
        }
    }

    StyledText {
        visible: !Audio.sources.length
        text: "no input devices"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Separator {
        width: parent.width
        visible: Media.available
    }

    MenuRow {
        width: root.width
        visible: Media.available
        icon: Media.playing ? "pause" : "play_arrow"
        label: Media.title
        detail: Media.artist || Media.app
        onActivated: Media.toggle()
    }
}
