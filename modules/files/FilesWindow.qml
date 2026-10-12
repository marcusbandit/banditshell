pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.services

FloatingWindow {
    id: win

    title: Files.windowTitle

    color: Appearance.colour.surfaceSolid

    implicitWidth: Appearance.sizes.filesWidth
    implicitHeight: Appearance.sizes.filesHeight

    visible: false

    property bool opened: false

    Connections {
        target: Files

        function onWindowOpenChanged(): void {
            if (Files.windowOpen)
                win.opened = true;
            win.visible = Files.windowOpen;
        }
    }

    onVisibleChanged: {
        if (!win.visible && Files.windowOpen) {
            Files.hide();
            return;
        }

        if (win.visible)
            face.forceActiveFocus();
    }

    Loader {
        anchors.fill: parent

        active: win.opened && Files.helpersMissing
        sourceComponent: HelpersMissing {}
    }

    Loader {
        id: face

        anchors.fill: parent

        focus: true
        active: win.opened && !Files.helpersMissing
        sourceComponent: FilesFace {}
    }
}
