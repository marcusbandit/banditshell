pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    readonly property var streams: Audio.playing.concat(Audio.recording)

    width: parent ? parent.width : 0

    SettingsRowFrame {
        width: root.width
        visible: root.streams.length === 0
        interactive: false
        icon: "music_off"
        label: "Nothing is playing"
        detail: "apps show up here while they make sound"
        onPointed: SettingsView.hovered = root.row
    }

    Repeater {
        model: root.streams

        delegate: SettingsRowFrame {
            id: app

            required property var modelData

            readonly property bool listening: Audio.recording.indexOf(app.modelData) >= 0
            readonly property real level: Audio.streamVolume(app.modelData)

            width: root.width
            icon: app.listening ? "mic" : "graphic_eq"
            label: Audio.streamLabel(app.modelData)
            detail: Audio.streamMuted(app.modelData) ? "muted" : app.listening ? "listening" : "playing"
            interactive: false
            onPointed: SettingsView.hovered = root.row
            lead: app.listening ? null : mark

            Component {
                id: mark

                AppMark {
                    spec: AppIcons.markFor(Audio.streamBinary(app.modelData) || Audio.streamLabel(app.modelData), "colour")
                    fallback: "graphic_eq"
                    color: Appearance.colour.textDim
                }
            }

            SettingsSlider {
                anchors.verticalCenter: parent.verticalCenter
                value: app.level
                from: 0
                to: 1
                step: 0.01
                text: `${Math.round(app.level * 100)}%`
                onMoved: v => Audio.setStreamVolume(app.modelData, v)
            }
        }
    }
}
