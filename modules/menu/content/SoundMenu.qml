import QtQuick
import qs.config
import qs.components
import qs.services

// Sound, both directions of it. This one is real.
//
// Output and input are ONE menu because they are one question: can I hear, and
// can they hear me. They used to be two gauges in the bar on the argument that
// muting a microphone happens in a hurry, mid-call, and should be one reach.
// That reasoning bought a saved glance with a whole slot, and it only holds
// while the mic is buried: with both levels as the first two things in the
// panel, the reach is the same one and the bar is a slot shorter.
//
// The sliders are bound to PipeWire and push back through Audio's setters, so
// anything else that changes a level (a key, another app, another shell) moves
// them.
//
// What is playing sits at the bottom as ONE row, deliberately. It is here only
// so that "turn this down" and "shut this up" are the same reach; art, scrubber,
// transport and which-player belong to the dashboard, which will have the room
// to show them properly.
Column {
    id: root

    spacing: Appearance.padding.normal

    StyledText {
        text: "OUTPUT"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Item {
        width: parent.width
        implicitHeight: outIcon.implicitHeight

        Icon {
            id: outIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            name: Audio.icon(Audio.volume, Audio.muted)
            color: Audio.muted ? Appearance.colour.textFaint : Appearance.colour.text

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Appearance.padding.small
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleMute()
            }
        }

        Slider {
            anchors.left: outIcon.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: outPct.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            value: Audio.volume
            to: Audio.maxVolume
            warnAbove: 1
            dimmed: Audio.muted
            onMoved: v => Audio.setVolume(v)
        }

        StyledText {
            id: outPct

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            // Actually fixed, at the width of the widest thing it can say.
            // `width: implicitWidth` is Text's own default and is not fixed at
            // all, so the slider's right anchor jumped whenever the readout went
            // from two digits to three, or to "muted".
            width: widest.width
            horizontalAlignment: Text.AlignRight
            text: Audio.muted ? "muted" : `${Math.round(Audio.volume * 100)}%`
            color: Audio.muted ? Appearance.colour.textFaint : Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
        }
    }

    StyledText {
        text: "INPUT"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    Item {
        width: parent.width
        implicitHeight: inIcon.implicitHeight

        Icon {
            id: inIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            name: Audio.sourceMuted || Audio.sourceVolume <= 0 ? "mic_off" : "mic"

            // Accent, where a muted OUTPUT only dims. Muting the speakers is a
            // choice you can hear the consequences of immediately; muting the
            // microphone is one you find out about a minute later, and it is the
            // same state the bar raises its alert for.
            color: Audio.sourceMuted ? Appearance.colour.accent : Appearance.colour.text

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Appearance.padding.small
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleSourceMute()
            }
        }

        Slider {
            anchors.left: inIcon.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: inPct.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            value: Audio.sourceVolume
            dimmed: Audio.sourceMuted
            onMoved: v => Audio.setSourceVolume(v)
        }

        StyledText {
            id: inPct

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: widest.width
            horizontalAlignment: Text.AlignRight
            text: Audio.sourceMuted ? "muted" : `${Math.round(Audio.sourceVolume * 100)}%`
            color: Audio.sourceMuted ? Appearance.colour.textFaint : Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
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
            required property var modelData

            width: root.width
            icon: modelData === Audio.sink ? "check" : ""
            label: Audio.label(modelData)
            selected: modelData === Audio.sink
            onActivated: Audio.setSink(modelData)
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
            required property var modelData

            width: root.width
            icon: modelData === Audio.source ? "check" : ""
            label: Audio.label(modelData)
            selected: modelData === Audio.source
            onActivated: Audio.setSource(modelData)
        }
    }

    StyledText {
        visible: !Audio.sources.length
        text: "no input devices"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    // The bonus. Present only while something is playing, so an idle machine
    // does not carry a row that says nothing.
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

    // The widest string any readout in this menu can hold.
    TextMetrics {
        id: widest

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "muted"
    }
}
