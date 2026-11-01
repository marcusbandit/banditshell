import QtQuick
import Quickshell
import qs.config
import qs.components

Item {
    id: root

    readonly property string login: Quickshell.env("USER") || "you"

    implicitWidth: 40
    implicitHeight: 40

    SquircleRect {
        anchors.fill: parent
        visible: !picture.ready
        pill: "object"
        color: Appearance.colour.accentFill
    }

    StyledText {
        anchors.centerIn: parent
        visible: !picture.ready
        text: root.login.charAt(0).toUpperCase()
        font.pixelSize: root.height > 64 ? Appearance.font.size.display : Appearance.font.size.normal
        font.weight: Font.DemiBold
        color: Appearance.colour.accent
    }

    SquircleImage {
        id: picture

        anchors.fill: parent
        source: SettingsState.face ? `file://${SettingsState.face}` : ""
        radius: width / 2
        power: 2
    }
}
