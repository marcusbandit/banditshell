import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.modules.quickcontrols

ShellRoot {
    PanelWindow {
        anchors.left: true

        implicitWidth: 560
        implicitHeight: 500

        color: Appearance.colour.surfaceSolid
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "banditshell-quickcontrolspreview"

        QuickControls {
            anchors.fill: parent
            border: Appearance.sizes.border

            Component.onCompleted: pinned = true
        }
    }
}
