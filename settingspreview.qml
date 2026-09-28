import QtQuick
import Quickshell
import qs.modules.settings
import qs.services

// The settings page's face, in an ordinary window, at whatever size you ask
// for: `SETTINGS_PREVIEW=400x800 qs -p settingspreview.qml`.
//
// The page has one shape now (the rail and the content, side by side), but a
// page at one width is not a page at every width, and the only way to look at
// it narrow is to draw the same face at that width. This is the same bargain
// lockpreview.qml makes for the lock screen: the real component, in a surface
// that can be screenshotted and killed. `SETTINGS_PAGE` opens it on a section.
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
