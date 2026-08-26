pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// GENERAL: the switches that are about how the shell behaves rather than how
// it looks.
//
// A switch lands here when flipping it changes what the shell DOES and not
// what it wears. Whether the edges are a finger wide, whether the bottom edge
// lifts windows, whether the fold brings the keyboard up: none of those is an
// appearance, and putting them beside the palettes would make the appearance
// page a list of everything, which is the same as no page at all.
//
// EVERY ROW HERE IS ALSO A TERMINAL COMMAND. Each one reads and writes one key
// of config.json through Config, so `banditshell shell set <key> <value>` and
// the toggle on the row are the same deed by two hands; the row is the key
// given a sentence. That is why the page holds nothing that is not a key:
// anything a row did that the CLI could not would be a second way of doing
// things, and config/Config.qml is careful that there is one.
//
// GROUPED BY THE PART OF THE SHELL THEY BELONG TO, under a quiet eyebrow each,
// because a General page is scanned by heading first: nobody reads ten switches
// top to bottom looking for the wifi one, they look for the word "Network" and
// then read three. A phone's General page is the same shape for the same
// reason. Inside a group the rows are in the order you would ask the questions.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.small / 2

        // ----------------------------------------------------------- touch

        StyledText {
            text: "Touch"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
        }

        // The one setting in `control` that is a trade rather than a taste,
        // which is why it is the only one of that block on a page: ten pixels
        // of edge is plenty for a cursor and a miss for a fingertip, and the
        // wider band is claimed from the windows underneath. The detail says
        // the cost, because a switch that only names the benefit is a switch
        // you find out about later.
        MenuRow {
            width: list.width
            icon: "touch_app"
            label: "Finger-sized edges"
            detail: "widen the screen edges to a fingertip; costs the windows a few pixels"
            tip: Config.values.control.touchEdges ? "narrow them back" : "widen them"
            onActivated: Config.set("control.touchEdges", !Config.values.control.touchEdges)

            Toggle {
                checked: Config.values.control.touchEdges
                onToggled: Config.set("control.touchEdges", !Config.values.control.touchEdges)
            }
        }

        // --------------------------------------------------------- windows

        // The bottom-edge window drag, a finger only, never the mouse; the
        // long argument for it is on the `windows` block in config/Config.qml
        // and in modules/windows/. Three questions in the order they arise:
        // whether the edge does it at all, what happens when the window lands
        // on another, and whether you go with it when it lands on a different
        // workspace.
        StyledText {
            text: "Windows"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
            topPadding: Appearance.padding.normal
        }

        MenuRow {
            width: list.width
            icon: "swipe_up"
            label: "Bottom edge lifts windows"
            detail: "a finger on the bottom edge picks up the window above it"
            tip: Config.values.windows.edge ? "give the edge back to the launcher" : "let it lift windows"
            onActivated: Config.set("windows.edge", !Config.values.windows.edge)

            Toggle {
                checked: Config.values.windows.edge
                onToggled: Config.set("windows.edge", !Config.values.windows.edge)
            }
        }

        // A SEGMENTED CONTROL, not a switch, for Segments' own reason: "swap"
        // is not "not move". Both are named things a drop can do, and a switch
        // labelled with one of them would be asking you to read its off state
        // as the other. The row is inert because there is no sensible thing for
        // a press on the body to do: a two-way choice flipped by a click on the
        // label would be the switch this control exists not to be.
        //
        // The key is a string and the control speaks indices, so the two are
        // translated at the edge, both ways, off the same list: the option
        // array is the model and the map in one, so a third mode added to it
        // would appear here and be written correctly without a branch.
        MenuRow {
            width: list.width
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

        MenuRow {
            width: list.width
            icon: "follow_the_signs"
            label: "Go with a sent window"
            detail: "switch to the workspace you dropped it on"
            tip: Config.values.windows.follow ? "stay where you are" : "follow it"
            onActivated: Config.set("windows.follow", !Config.values.windows.follow)

            Toggle {
                checked: Config.values.windows.follow
                onToggled: Config.set("windows.follow", !Config.values.windows.follow)
            }
        }

        // ---------------------------------------------------------- tablet

        // The fold: the machine folded over, and the on-screen keyboard that
        // replaces the one now facing the table. See the `tablet` block in
        // config/Config.qml for why docked is the default despite the reflow.
        StyledText {
            text: "Tablet"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
            topPadding: Appearance.padding.normal
        }

        MenuRow {
            width: list.width
            icon: "keyboard"
            label: "Keyboard on fold"
            detail: "bring the on-screen board up when the machine folds over"
            tip: Config.values.tablet.autoKeyboard ? "leave it to the keybind" : "bring it up by itself"
            onActivated: Config.set("tablet.autoKeyboard", !Config.values.tablet.autoKeyboard)

            Toggle {
                checked: Config.values.tablet.autoKeyboard
                onToggled: Config.set("tablet.autoKeyboard", !Config.values.tablet.autoKeyboard)
            }
        }

        MenuRow {
            width: list.width
            icon: "dock_to_bottom"
            label: "Board takes room"
            detail: "docked reserves space; off, it floats over the window"
            tip: Config.values.tablet.docked ? "let it float" : "dock it"
            onActivated: Config.set("tablet.docked", !Config.values.tablet.docked)

            Toggle {
                checked: Config.values.tablet.docked
                onToggled: Config.set("tablet.docked", !Config.values.tablet.docked)
            }
        }

        // --------------------------------------------------------- network

        // The two questions NetworkManager will not answer unasked. Both are
        // session-long on purpose: the second one costs a second and a half of
        // frozen shell each time it changes, which is why it is a setting made
        // once here and not a thing a menu guesses at while you look at it.
        StyledText {
            text: "Network"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
            topPadding: Appearance.padding.normal
        }

        MenuRow {
            width: list.width
            icon: "travel_explore"
            label: "Check for internet"
            detail: "one small request a minute; tells a captive portal from the real thing"
            tip: Config.values.network.checkForInternet ? "stop checking" : "start checking"
            onActivated: Config.set("network.checkForInternet", !Config.values.network.checkForInternet)

            Toggle {
                checked: Config.values.network.checkForInternet
                onToggled: Config.set("network.checkForInternet", !Config.values.network.checkForInternet)
            }
        }

        MenuRow {
            width: list.width
            icon: "wifi_find"
            label: "Keep the wifi list fresh"
            detail: "scan all session long rather than only while looking"
            tip: Config.values.network.keepListFresh ? "stop scanning" : "keep scanning"
            onActivated: Config.set("network.keepListFresh", !Config.values.network.keepListFresh)

            Toggle {
                checked: Config.values.network.keepListFresh
                onToggled: Config.set("network.keepListFresh", !Config.values.network.keepListFresh)
            }
        }

        // ---------------------------------------------------------- hotkeys

        // The sheet asks these two itself, as Segments in its header, and they
        // are here as well because the sheet is a thing you open to look
        // something up and close, not a place you go to change how it opens.
        // Same keys, so the two agree the instant either is touched.
        StyledText {
            text: "Hotkey sheet"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
            topPadding: Appearance.padding.normal
        }

        MenuRow {
            width: list.width
            icon: "keyboard_alt"
            label: "Show the keyboard"
            detail: "a drawn board with the bound keys lit, instead of the list"
            tip: Config.values.cheatsheet.board ? "back to the list" : "draw the board"
            onActivated: Config.set("cheatsheet.board", !Config.values.cheatsheet.board)

            Toggle {
                checked: Config.values.cheatsheet.board
                onToggled: Config.set("cheatsheet.board", !Config.values.cheatsheet.board)
            }
        }

        MenuRow {
            width: list.width
            icon: "special_character"
            label: "Modifier symbols"
            detail: "a penguin and arrows instead of SUPER and SHIFT"
            tip: Config.values.cheatsheet.symbols ? "spell them out" : "use the marks"
            onActivated: Config.set("cheatsheet.symbols", !Config.values.cheatsheet.symbols)

            Toggle {
                checked: Config.values.cheatsheet.symbols
                onToggled: Config.set("cheatsheet.symbols", !Config.values.cheatsheet.symbols)
            }
        }
    }
}
