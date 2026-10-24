pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.modules.panel
import qs.services

FloatingWindow {
    id: win

    title: Files.windowTitle

    color: Appearance.colour.surfaceSolid

    implicitWidth: Appearance.sizes.filesWidth
    implicitHeight: Appearance.sizes.filesHeight

    visible: false

    property bool opened: false

    function follow(): void {
        if (Files.windowOpen)
            win.opened = true;
        win.visible = Files.windowOpen;
    }

    Component.onCompleted: win.follow()

    TraceFrames {
        label: "files"
    }

    Connections {
        target: Files

        function onWindowOpenChanged(): void {
            win.follow();
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
