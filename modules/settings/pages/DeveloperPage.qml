pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// DEVELOPER: the levers you pull when you are working ON the shell rather than
// in it.
//
// THERE IS NO DEBUG FLAG, and the page is not where one has been left out.
// Nothing in this shell has a verbose mode: a service that has something to say
// says it with console.warn and it lands in `banditshell log`, every time, so
// there is no state to flip before a problem is visible and no chance the one
// time it happened was the time logging was off. A debug switch is a promise
// that the quiet path and the loud path behave the same, and the only way to
// keep that promise is not to have two paths.
//
// So what is left is ACTIONS and FACTS. Everything on this page is one of the
// CLI's verbs given a row (`banditshell shell reload`, `banditshell settings
// status`), and the facts are the answers those verbs print, shown live rather
// than fetched: a status row bound to the property it reports is right by
// construction, where one that ran a command and pasted the output is right
// until the next change.
//
// The file rows open with xdg-open rather than a chooser or an editor of the
// shell's own, for the icons page's reason: the desktop already has an opener
// and every shell that has written its own has written a worse one.
Item {
    id: root

    implicitHeight: list.implicitHeight

    // ONE PROCESS FOR BOTH FILE ROWS. xdg-open forks and exits at once, so a
    // second press before the first has returned is not a case worth a second
    // Process; `exec` replaces the command and runs it.
    Process {
        id: opener
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.large

        // ----------------------------------------------------------- shell

        SettingsCard {
            title: "Shell"

            // The detail says the one thing a reload button always gets
            // asked: no, you do not need it for the config. Config.qml watches
            // its file, and a reload here is for QML that changed, which
            // nothing watches.
            SettingsRow {
                icon: "refresh"
                label: "Reload the shell"
                detail: "re-read every QML file; the config is watched already and needs no reload"
                onActivated: Quickshell.reload(true)
            }

            // The rules go in once, at startup, and the compositor forgets
            // them on its own reload; this is the same call Settings makes
            // then, offered again for the day hyprland was restarted under a
            // running shell.
            SettingsRow {
                icon: "rule"
                label: "Reinstall the window rules"
                detail: "tell the compositor again how the settings window floats"
                onActivated: Settings.installRules()
            }

            SettingsRow {
                icon: "sync"
                label: "Re-read the compositor"
                detail: "rounding, gaps and border, if you changed them in hyprland.conf"
                onActivated: Compositor.refresh()
            }
        }

        // ----------------------------------------------------------- files

        // The path IS the detail, because a row that says "open the config"
        // and a row that says where the config is are the same row, and the
        // second one is the one you can copy out of a screenshot.
        SettingsCard {
            title: "Files"

            SettingsRow {
                icon: "data_object"
                label: "config.json"
                detail: Config.path
                onActivated: opener.exec(["xdg-open", Config.path])
            }

            SettingsRow {
                readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`

                icon: "folder_open"
                label: "State folder"
                detail: dir
                onActivated: opener.exec(["xdg-open", dir])
            }
        }

        // ---------------------------------------------------------- status

        // FACTS, not controls, so the rows are inert for ScreensPage's reason:
        // a row that lit on hover and swallowed the press would be promising a
        // thing it cannot do. Each answer is the row's `value`, which sits
        // beside its label while it fits so the group reads as a table, and
        // drops under it rather than being squeezed when it does not.
        SettingsCard {
            title: "Status"

            SettingsRow {
                icon: "check_circle"
                label: "Settings file"
                value: Config.loaded ? "read" : "not read yet"
                interactive: false
            }

            // Three-way, because the answer is three-way: `lua` reads false
            // while the probe is still out, and false is also a real answer,
            // so a row that showed "legacy" before the compositor had replied
            // would be stating a guess as a fact. See Hypr.parserKnown.
            SettingsRow {
                icon: "code"
                label: "Compositor dialect"
                value: !Compositor.isHyprland ? "not hyprland" : !Hypr.parserKnown ? "asking" : Hypr.lua ? "lua" : "legacy"
                interactive: false
            }

            SettingsRow {
                icon: "web_asset"
                label: "This page is held by"
                value: (Settings.floating ? "a window" : "the shell") + (Settings.screenName ? ` on ${Settings.screenName}` : "")
                interactive: false
            }

            // A detail rather than a value, the one exception in the group:
            // this is not an answer but two commands, and they belong under
            // the label where they can wrap, not beside it.
            SettingsRow {
                icon: "terminal"
                label: "From a terminal"
                detail: "banditshell settings status · banditshell shell get <key>"
                interactive: false
            }
        }
    }
}
