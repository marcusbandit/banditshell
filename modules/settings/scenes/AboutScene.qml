import QtQuick
import qs.config
import qs.components
import qs.modules.settings

SceneGauge {
    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: "deployed_code"
        size: Appearance.icon.hero
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
        text: `${SettingsState.followedBranch} · ${Config.values.updates.remote}`
        color: Appearance.colour.textFaint
    }
}
