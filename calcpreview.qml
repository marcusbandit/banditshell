import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.menu.content

// Temporary: the calculator at page width, on a plain surface, so the keypad can
// be driven by hand without opening the shell.
ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
        }

        margins {
            top: 60
            left: 200
        }

        implicitWidth: calc.width + Appearance.padding.large * 2
        implicitHeight: calc.implicitHeight + Appearance.padding.large * 2 + 40

        color: "#16211c"
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "banditshell-calcpreview"

        CalculatorMenu {
            id: calc

            x: Appearance.padding.large
            y: Appearance.padding.large + 40
            width: Appearance.sizes.menuWidth - Appearance.padding.large * 2
        }

        Text {
            x: Appearance.padding.large
            y: Appearance.padding.large
            color: "#eaf6f0"
            text: `menu height ${Math.round(calc.implicitHeight)}`
        }
    }
}
