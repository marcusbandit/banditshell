import QtQuick
import Quickshell
import qs.modules.settings
import qs.services

ShellRoot {
    id: root

    readonly property var size: (Quickshell.env("SETTINGS_PREVIEW") || "560x560").split("x").map(Number)

    FloatingWindow {
        title: "banditshell-settingspreview"
        implicitWidth: root.size[0]
        implicitHeight: root.size[1]

        Component.onCompleted: {
            const page = Quickshell.env("SETTINGS_PAGE");
            if (page)
                Settings.setPage(page);
        }

        SettingsFace {
            anchors.fill: parent
        }
    }
}
