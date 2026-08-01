import QtQuick
import qs.config
import qs.components
import qs.services

// The microphone. This one is real.
//
// Separate from Sound rather than a section of it, because muting your
// microphone is a thing people do in a hurry, mid-call, and it should be one
// reach rather than one reach plus a scan down a panel.
Column {
    id: root

    spacing: Appearance.padding.normal

    Item {
        width: parent.width
        implicitHeight: glyph.implicitHeight

        Icon {
            id: glyph

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            name: Audio.sourceMuted ? "mic_off" : "mic"
            color: Audio.sourceMuted ? Appearance.colour.accent : Appearance.colour.text

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Appearance.padding.small
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleSourceMute()
            }
        }

        Slider {
            anchors.left: glyph.right
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: readout.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            value: Audio.sourceVolume
            dimmed: Audio.sourceMuted
            onMoved: v => Audio.setSourceVolume(v)
        }

        StyledText {
            id: readout

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            width: widest.width
            horizontalAlignment: Text.AlignRight
            text: Audio.sourceMuted ? "muted" : `${Math.round(Audio.sourceVolume * 100)}%`
            font.pixelSize: Appearance.font.size.small
            color: Audio.sourceMuted ? Appearance.colour.textFaint : Appearance.colour.textDim
        }
    }

    // Muted is the state worth shouting about, because the failure mode is
    // talking to nobody for a minute. It is the one accent in this menu.
    StyledText {
        width: parent.width
        visible: Audio.sourceMuted
        text: "microphone is muted"
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.accent
    }

    Separator {
        width: parent.width
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

    // The widest string any readout in this menu can hold.
    TextMetrics {
        id: widest

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "muted"
    }
}
