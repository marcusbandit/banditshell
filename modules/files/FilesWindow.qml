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

    Connections {
        target: Files

        function onWindowOpenChanged(): void {
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

        active: Files.helpersMissing
        sourceComponent: HelpersMissing {}
    }

    Loader {
        id: face

        anchors.fill: parent

        focus: true
        active: !Files.helpersMissing
        sourceComponent: FilesFace {}
    }

}
