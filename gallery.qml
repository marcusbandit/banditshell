import QtQuick
import Quickshell
import qs.config
import qs.modules.gallery

// The component gallery, in a plain window of its own: the same bargain
// settingspreview.qml makes, with the difference that this one is not
// photographed and killed - it is a workbench, meant to stay open next to
// whatever is being built, so it takes focus and no timeout is set.
//
//     GALLERY_SIZE=1280x800 qs -p ./gallery.qml
//
// Or, the ordinary way: `banditshell gallery [WxH]`.
//
// Its surface is SOLID, not a shell layer: this is one of the surfaces the
// compositor frames and does not blur (Appearance.colour.surfaceSolid), and
// the components on it are being judged for the shell, so they sit on the
// same material they will live on.
ShellRoot {
    id: root

    readonly property var size: (Quickshell.env("GALLERY_SIZE") || "1280x800").split("x").map(Number)

    Component.onCompleted: {
        // GALLERY_PAGE=<key> opens the register on one component: the deep
        // link a later `banditshell gallery <key>` will use, and the way a
        // screenshot points at the page it is checking.
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

        // CLOSING THE WINDOW QUITS. Quickshell is a shell: by default it
        // keeps running with no windows, which for a workbench surface means
        // every close left a windowless process squatting on the config path
        // - the husk graveyard. A gallery with no window is nothing.
        onVisibleChanged: if (!visible) Qt.quit()

        Gallery {
            anchors.fill: parent
        }
    }
}
