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

    property bool opened: false

    Connections {
        target: Settings

        function onOpenChanged(): void {
            if (Settings.open)
                win.opened = true;
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

    Loader {
        id: face

        anchors.fill: parent

        focus: true
        active: win.opened

        sourceComponent: SettingsFace {
            focus: true
            showing: Settings.open
        }
    }
}
