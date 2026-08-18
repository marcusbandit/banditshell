import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.modules.menu.content

// Temporary: the battery menu at page width, plus the sidebar meter at native
// size and blown up, charging and not, so the bolt can be judged at the size it
// is actually drawn.
ShellRoot {
    PanelWindow {
        anchors {
            top: true
            left: true
        }

        implicitWidth: Appearance.sizes.menuWidth + 300
        implicitHeight: 620

        color: "#16211c"
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "banditshell-batterypreview"

        mask: Region {
            width: 0
            height: 0
        }

        Column {
            x: 40
            y: 30
            spacing: 28

            BatteryMenu {
                width: Appearance.sizes.menuWidth - Appearance.padding.large * 2
            }

            // Native size, the row as the sidebar draws it.
            Row {
                spacing: 16

                Repeater {
                    model: [
                        {
                            level: 0.08,
                            charging: false
                        },
                        {
                            level: 0.08,
                            charging: true
                        },
                        {
                            level: 0.5,
                            charging: false
                        },
                        {
                            level: 0.5,
                            charging: true
                        },
                        {
                            level: 0.92,
                            charging: false
                        },
                        {
                            level: 0.92,
                            charging: true
                        }
                    ]

                    delegate: BatteryMeter {
                        required property var modelData

                        level: modelData.level
                        charging: modelData.charging
                    }
                }
            }

            // The same row at 5x. `alert` is the worst case for a green bolt: a
            // low battery on the charger, where StatusIcon turns the fill accent
            // too and the bolt is sitting on its own colour.
            Row {
                spacing: 40

                Repeater {
                    model: [
                        {
                            level: 0.08,
                            charging: true,
                            alert: true
                        },
                        {
                            level: 0.35,
                            charging: true,
                            alert: false
                        },
                        {
                            level: 0.92,
                            charging: true,
                            alert: false
                        },
                        {
                            level: 0.5,
                            charging: false,
                            alert: false
                        }
                    ]

                    delegate: Item {
                        required property var modelData

                        implicitWidth: meter.width * 5
                        implicitHeight: meter.height * 5

                        BatteryMeter {
                            id: meter

                            anchors.centerIn: parent
                            scale: 5

                            level: parent.modelData.level
                            charging: parent.modelData.charging
                            colour: parent.modelData.alert ? Appearance.colour.accent : Appearance.colour.text
                        }
                    }
                }
            }
        }
    }
}
