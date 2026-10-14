import QtQuick
import qs.config
import qs.components
import qs.modules.settings

SceneGauge {
    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: "deployed_code"
        size: 96
        fill: 1
        color: Appearance.colour.accent
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: `BanditShell ${SettingsState.version}`
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: `${Config.values.updates.branch} · ${Config.values.updates.remote}`
        color: Appearance.colour.textFaint
    }
}
