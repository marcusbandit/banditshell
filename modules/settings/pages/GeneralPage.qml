pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.controls
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
                onActivated: Config.set("windows.edge", !Config.values.windows.edge)

                Toggle {
                    checked: Config.values.windows.edge
                    onToggled: Config.set("windows.edge", !Config.values.windows.edge)
                }
            }

            SettingsRow {
                icon: "swap_horiz"
                label: "Dropping on another window"
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
                onActivated: Config.set("tablet.autoKeyboard", !Config.values.tablet.autoKeyboard)

                Toggle {
                    checked: Config.values.tablet.autoKeyboard
                    onToggled: Config.set("tablet.autoKeyboard", !Config.values.tablet.autoKeyboard)
                }
            }

            SettingsRow {
                icon: "dock_to_bottom"
                label: "Board takes room"
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
                onActivated: Config.set("network.checkForInternet", !Config.values.network.checkForInternet)

                Toggle {
                    checked: Config.values.network.checkForInternet
                    onToggled: Config.set("network.checkForInternet", !Config.values.network.checkForInternet)
                }
            }

            SettingsRow {
                icon: "wifi_find"
                label: "Keep the wifi list fresh"
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
                onActivated: Config.set("cheatsheet.board", !Config.values.cheatsheet.board)

                Toggle {
                    checked: Config.values.cheatsheet.board
                    onToggled: Config.set("cheatsheet.board", !Config.values.cheatsheet.board)
                }
            }
        }

        SettingsCard {
            title: "Your keyboard"

            PathField {
                width: parent.width
                icon: "keyboard"
                label: "Layout file"
                value: Keyboards.path
                detail: Keyboards.error || (Keyboards.board ? `${Keyboards.board.name || Keyboards.stored}, ${Keyboards.variant.toUpperCase()}` : "")
                onCommitted: path => Keyboards.use(path)
            }

            SettingsRow {
                icon: "keyboard_hide"
                label: "Back to the default board"
                visible: !!Keyboards.stored
                onActivated: Keyboards.clear()
            }
        }
    }
}
