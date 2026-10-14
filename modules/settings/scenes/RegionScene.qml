import QtQuick
import qs.config
import qs.components
import qs.modules.settings

SceneGauge {
    id: root

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: SettingsState.v("clock24") ? "14:32" : "2:32 pm"
        font.pixelSize: Appearance.font.size.large
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: SettingsState.v("dateFormat")
    }

    StyledText {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: ({
                Denmark: "1.234,56 kr.",
                "United Kingdom": "£1,234.56",
                "United States": "$1,234.56"
            })[SettingsState.v("region")] ?? ""
        color: Appearance.colour.textFaint
    }
}
