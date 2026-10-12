import QtQuick
import Quickshell
import qs.config
import qs.modules.gallery

ShellRoot {
    id: root

    readonly property var size: (Quickshell.env("GALLERY_SIZE") || "1280x800").split("x").map(Number)

    Component.onCompleted: {

        const page = Quickshell.env("GALLERY_PAGE");
        if (page && Registry.entryFor(page))
            Registry.current = page;
    }

    FloatingWindow {
        id: window

        title: "banditshell-gallery"
        color: Appearance.colour.surfaceSolid
        implicitWidth: root.size[0]
        implicitHeight: root.size[1]

        onVisibleChanged: if (!visible) Qt.quit()

        Gallery {
            anchors.fill: parent
        }
    }
}
