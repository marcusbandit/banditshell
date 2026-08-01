import QtQuick
import qs.config
import qs.components
import qs.services

// Sound. This one is real.
//
// Output level, input level, and which device is the output. The sliders are
// bound to PipeWire and push back through Audio's setters, so anything else that
// changes the volume (a key, another app, another shell) moves them.
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

            // Fixed width, so the slider does not twitch as the number changes
            // from two digits to three.
            width: implicitWidth
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
            color: Audio.sourceMuted ? Appearance.colour.textFaint : Appearance.colour.text

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

            width: implicitWidth
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
        text: "DEVICE"
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
}
