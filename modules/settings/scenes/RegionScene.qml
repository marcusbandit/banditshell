import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

SceneGauge {
    id: root

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: SettingsState.timeExample
        font.pixelSize: Appearance.font.size.large
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: TimeFormat.dateText(new Date(SettingsState.tick), "year")
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: SettingsState.moneyExample
        color: Appearance.colour.textFaint
    }
}
