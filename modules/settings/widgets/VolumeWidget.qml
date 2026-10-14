import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

SettingsRowFrame {
    id: root

    property var row: ({})

    readonly property real ceiling: Audio.maxVolume
    readonly property real level: Math.min(Audio.volume, root.ceiling)

    width: parent ? parent.width : 0
    icon: Audio.muted ? "volume_off" : "volume_up"
    label: "Volume"
    detail: Audio.muted ? "muted" : ""
    interactive: false
    onPointed: SettingsView.hovered = root.row

    SettingsTool {
        anchors.verticalCenter: parent.verticalCenter
        icon: Audio.muted ? "volume_off" : "volume_mute"
        tip: Audio.muted ? "unmute" : "mute"
        on: Audio.muted
        onClicked: Audio.toggleMute()
    }

    SettingsSlider {
        anchors.verticalCenter: parent.verticalCenter
        value: root.level
        from: 0
        to: root.ceiling
        step: 0.01
        warnAbove: root.ceiling > 1 ? 1 : root.ceiling
        text: `${Math.round(root.level * 100)}%`
        onMoved: v => Audio.setVolume(v)
    }
}
