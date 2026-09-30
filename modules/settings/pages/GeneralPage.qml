pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings

Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        SettingsCard {
            title: "Touch"

            SettingsRow {
                icon: "touch_app"
                label: "Finger-sized edges"
                detail: "widen the screen edges to a fingertip; costs the windows a few pixels"
                onActivated: Config.set("control.touchEdges", !Config.values.control.touchEdges)

                Toggle {
                    checked: Config.values.control.touchEdges
                    onToggled: Config.set("control.touchEdges", !Config.values.control.touchEdges)
                }
            }
        }

        SettingsCard {
            title: "Windows"

            SettingsRow {
                icon: "swipe_up"
                label: "Bottom edge lifts windows"
                detail: "a finger on the bottom edge picks up the window above it"
                onActivated: Config.set("windows.edge", !Config.values.windows.edge)

                Toggle {
                    checked: Config.values.windows.edge
                    onToggled: Config.set("windows.edge", !Config.values.windows.edge)
                }
            }

            SettingsRow {
                icon: "swap_horiz"
                label: "Dropping on another window"
                detail: "move shuffles the others along, swap exchanges the two"
                interactive: false

                Segments {
                    readonly property var modes: ["move", "swap"]

                    options: modes
                    current: Math.max(0, modes.indexOf(Config.values.windows.mode))
                    onPicked: i => Config.set("windows.mode", modes[i])
                }
            }

            SettingsRow {
                icon: "follow_the_signs"
                label: "Go with a sent window"
                detail: "switch to the workspace you dropped it on"
                onActivated: Config.set("windows.follow", !Config.values.windows.follow)

                Toggle {
                    checked: Config.values.windows.follow
                    onToggled: Config.set("windows.follow", !Config.values.windows.follow)
                }
            }
        }

        SettingsCard {
            title: "Tablet"

            SettingsRow {
                icon: "keyboard"
                label: "Keyboard on fold"
                detail: "bring the on-screen board up when the machine folds over"
                onActivated: Config.set("tablet.autoKeyboard", !Config.values.tablet.autoKeyboard)

                Toggle {
                    checked: Config.values.tablet.autoKeyboard
                    onToggled: Config.set("tablet.autoKeyboard", !Config.values.tablet.autoKeyboard)
                }
            }

            SettingsRow {
                icon: "dock_to_bottom"
                label: "Board takes room"
                detail: "docked reserves space; off, it floats over the window"
                onActivated: Config.set("tablet.docked", !Config.values.tablet.docked)

                Toggle {
                    checked: Config.values.tablet.docked
                    onToggled: Config.set("tablet.docked", !Config.values.tablet.docked)
                }
            }
        }

        SettingsCard {
            title: "Network"

            SettingsRow {
                icon: "travel_explore"
                label: "Check for internet"
                detail: "one small request a minute; tells a captive portal from the real thing"
                onActivated: Config.set("network.checkForInternet", !Config.values.network.checkForInternet)

                Toggle {
                    checked: Config.values.network.checkForInternet
                    onToggled: Config.set("network.checkForInternet", !Config.values.network.checkForInternet)
                }
            }

            SettingsRow {
                icon: "wifi_find"
                label: "Keep the wifi list fresh"
                detail: "scan all session long rather than only while looking"
                onActivated: Config.set("network.keepListFresh", !Config.values.network.keepListFresh)

                Toggle {
                    checked: Config.values.network.keepListFresh
                    onToggled: Config.set("network.keepListFresh", !Config.values.network.keepListFresh)
                }
            }
        }

        SettingsCard {
            title: "Hotkey sheet"

            SettingsRow {
                icon: "keyboard_alt"
                label: "Show the keyboard"
                detail: "a drawn board with the bound keys lit, instead of the list"
                onActivated: Config.set("cheatsheet.board", !Config.values.cheatsheet.board)

                Toggle {
                    checked: Config.values.cheatsheet.board
                    onToggled: Config.set("cheatsheet.board", !Config.values.cheatsheet.board)
                }
            }

            SettingsRow {
                icon: "special_character"
                label: "Modifier symbols"
                detail: "a penguin and arrows instead of SUPER and SHIFT"
                onActivated: Config.set("cheatsheet.symbols", !Config.values.cheatsheet.symbols)

                Toggle {
                    checked: Config.values.cheatsheet.symbols
                    onToggled: Config.set("cheatsheet.symbols", !Config.values.cheatsheet.symbols)
                }
            }
        }
    }
}
