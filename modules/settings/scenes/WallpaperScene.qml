import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Item {
    readonly property real stageHeight: 220

    SquircleImage {
        anchors.fill: parent
        visible: SettingsState.v("wallOn")
        radius: Appearance.rounding.large
        source: Wallpaper.faceOf(Wallpaper.currentOn(Settings.screenName))
        fillMode: Image.PreserveAspectCrop
    }

    SquircleRect {
        anchors.fill: parent
        visible: !SettingsState.v("wallOn")
        radius: Appearance.rounding.large
        color: Appearance.colour.surfaceSolid
    }
}
