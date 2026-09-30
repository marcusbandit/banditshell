import Quickshell
import Quickshell.Wayland
import qs.modules.lock

ShellRoot {
    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "black"
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "banditshell-lockpreview"

        mask: Region {
            width: 0
            height: 0
        }

        LockFace {
            anchors.fill: parent
            active: true

            previewDots: 6
        }
    }
}
