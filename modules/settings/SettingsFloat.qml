pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

FloatingWindow {
    id: win

    title: Settings.windowTitle

    color: Appearance.colour.surfaceSolid

    implicitWidth: Settings.homeWidth
    implicitHeight: Settings.homeHeight

    visible: false

    Connections {
        target: Settings

        function onOpenChanged(): void {
            win.visible = Settings.open;
        }
    }

    onVisibleChanged: {
        if (!win.visible && Settings.open) {
            Settings.hide();
            return;
        }

        if (win.visible)
            face.forceActiveFocus();
    }

    SettingsFace {
        id: face

        anchors.fill: parent
    }
}
