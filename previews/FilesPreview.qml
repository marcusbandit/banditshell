import QtQuick
import Quickshell
import qs.config
import qs.modules.files
import qs.services

ShellRoot {
    id: root

    FloatingWindow {
        title: "banditshell-filespreview"

        color: Appearance.colour.surfaceSolid
        implicitWidth: Appearance.sizes.filesWidth
        implicitHeight: Appearance.sizes.filesHeight

        Component.onCompleted: {

            Files.show(Quickshell.env("FILES_PREVIEW") ?? "");
        }

        FilesFace {
            anchors.fill: parent
        }
    }
}
