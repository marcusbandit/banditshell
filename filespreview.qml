import QtQuick
import Quickshell
import qs.config
import qs.modules.files
import qs.services

// The file browser, in an ordinary window, without the running shell:
// `qs -p filespreview.qml`, or `banditshell filespreview`.
//
// Same bargain as lockpreview.qml and settingspreview.qml: the REAL component,
// in a surface that can be screenshotted and killed. It matters more here than
// for either of those, because this window owns a live pty - looking at the
// browser by restarting the shell would mean restarting every session in it,
// and a preview instance can be thrown away without touching the one being used.
//
// FILES_PREVIEW names a directory to open on, so a screenshot can be of a
// folder chosen to have something worth drawing in it rather than of whatever
// home happens to hold.
ShellRoot {
    id: root

    FloatingWindow {
        title: "banditshell-filespreview"

        color: Appearance.colour.surfaceSolid
        implicitWidth: Appearance.sizes.filesWidth
        implicitHeight: Appearance.sizes.filesHeight

        Component.onCompleted: {
            const where = Quickshell.env("FILES_PREVIEW");
            if (where)
                Files.cwd = where;
            Files.windowOpen = true;
        }

        FilesFace {
            anchors.fill: parent
        }
    }
}
