import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.menu.content

// Temporary: the network menu at page width, driven straight into the states a
// cursor would have to reach.
ShellRoot {
    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "#16211c"
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "banditshell-qrpreview"

        mask: Region {
            width: 0
            height: 0
        }

        NetworkMenu {
            id: menu

            x: 200
            y: 60
            width: Appearance.sizes.menuWidth - Appearance.padding.large * 2

            showing: true
            opened: "share"
            colourful: false
        }

        Text {
            x: 200
            y: 20
            color: "#eaf6f0"
            text: `menu height ${Math.round(menu.implicitHeight)}`
        }

        // Turn it over once it has settled, so one run shows both faces.
        Timer {
            interval: 4000
            running: true
            onTriggered: menu.colourful = true
        }
    }
}
