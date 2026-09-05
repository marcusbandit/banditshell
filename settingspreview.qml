import QtQuick
import Quickshell
import qs.modules.settings
import qs.services

// The settings page's face, in an ordinary window, at whatever size you ask
// for: `SETTINGS_PREVIEW=400x800 qs -p settingspreview.qml`.
//
// It exists because the page has three shapes (a phone, an unfolded phone, a
// desktop card) and the only way to look at all three on one monitor is to
// draw the same face at three widths. This is the same bargain lockpreview.qml
// makes for the lock screen: the real component, in a surface that can be
// screenshotted and killed. `SETTINGS_PAGE` opens it on a section.
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
            windowed: true
        }
    }
}
