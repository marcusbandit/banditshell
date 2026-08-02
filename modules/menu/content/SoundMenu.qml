pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Sound, all of it. This one is real.
//
// It is built in two blocks, out and in, and each block is the same three
// things in the same order: the master level, then the individual apps feeding
// it, then which device it uses. Output and input are ONE menu because they are
// one question, whether you can hear and whether you can be heard, and the
// blocks answer it the same way twice rather than making you learn two shapes.
//
// The APPS are the part that makes this a sound panel rather than a volume
// knob. "Turn the browser down" is the thing people actually want from a mixer,
// and it cannot be done from a master level at all: every stream PipeWire has
// gets its own row, its own bead and its own mute, and the row disappears when
// the app stops making noise. Recording streams get the same treatment under
// input, which doubles as the answer to "what is listening to me right now".
//
// Everything here is bound to PipeWire and pushes back through Audio's setters,
// so anything else that changes a level moves it: a media key, another app, the
// far end of a call.
//
// What is playing sits at the bottom as ONE row, so that "turn this down" and
// "shut this up" are the same reach. Art, scrubber, transport and which-player
// belong to the dashboard, which will have room to show them properly.
Column {
    id: root

    spacing: Appearance.padding.normal

    // A master level: the glyph that mutes it, the bead you drag, the number.
    component Level: Item {
        id: level

        required property string glyph
        required property real value
        required property bool muted
        property real max: 1
        // Muting THIS is worth the accent. True for the microphone, where the
        // failure mode is a minute of talking to nobody, and false for the
        // speakers, where you find out immediately.
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

            // Actually fixed, at the width of the widest thing it can say.
            // `width: implicitWidth` is Text's own default and is not fixed at
            // all, so the slider's right anchor jumped whenever the readout went
            // from two digits to three, or to "muted".
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

    // One app's channel. Two lines rather than one: a name and a level both want
    // the width, and a name squeezed into a third of the row elides to
    // "Firef..." exactly when knowing which app it is matters most.
    component Channel: Item {
        id: channel

        required property var node

        readonly property string title: Audio.streamLabel(node)
        readonly property bool muted: Audio.streamMuted(node)
        readonly property real value: Audio.streamVolume(node)

        implicitHeight: name.implicitHeight + Appearance.padding.small + bar.implicitHeight

        // The app's OWN icon, which is how an app is recognised without being
        // read. The category glyph stands in when nothing resolves, so an
        // unrecognised stream still gets a mark rather than a hole.
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

            // The icon is the mute, the same as the glyph on a master level is.
            // A row of its own for a mute button would double the height of
            // every channel to hold a control that is off for all of them.
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

        // WHAT YOU ARE LISTENING THROUGH, not a picture of a loudspeaker. The
        // glyph is the sink's own kind, so the top of the panel answers "am I on
        // the headphones or the laptop" before you have read anything. Muted is
        // the one state that overrides it, because a muted control has to say so
        // louder than it says what it is.
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
        // Capped, because the panel clips where it runs out of screen rather
        // than scrolling: a cap is the difference between a long list and a list
        // whose last row is cut in half.
        model: Audio.playing.slice(0, Appearance.sizes.streamListMax)

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
        model: Audio.recording.slice(0, Appearance.sizes.streamListMax)

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

    // THE LEADING SLOT SAYS WHAT IT IS; the trailing one says which is on.
    //
    // A tick in the icon slot spent the one strong position in the row saying
    // something the row's own highlight already said, and left the actual
    // question, which of these is the headphones, to be worked out from a name
    // like "ALC257 Analog". Kind on the left, name, where it plugs in
    // underneath, tick on the right.
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
}
