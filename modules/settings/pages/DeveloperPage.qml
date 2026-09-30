pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.modules.settings

Item {
    id: root

    implicitHeight: list.implicitHeight

    Process {
        id: opener
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        SettingsCard {
            title: "Shell"

            SettingsRow {
                icon: "refresh"
                label: "Reload the shell"
                detail: "re-read every QML file; the config is watched already and needs no reload"
                onActivated: Quickshell.reload(true)
            }

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

        SettingsCard {
            title: "Status"

            SettingsRow {
                icon: "check_circle"
                label: "Settings file"
                value: Config.loaded ? "read" : "not read yet"
                interactive: false
            }

            SettingsRow {
                icon: "code"
                label: "Compositor dialect"
                value: !Compositor.isHyprland ? "not hyprland" : !Hypr.parserKnown ? "asking" : Hypr.lua ? "lua" : "legacy"
                interactive: false
            }

            SettingsRow {
                icon: "web_asset"
                label: "This page is held by"
                value: "a window" + (Settings.screenName ? ` (summoned on ${Settings.screenName})` : "")
                interactive: false
            }

            SettingsRow {
                icon: "terminal"
                label: "From a terminal"
                detail: "banditshell settings status · banditshell shell get <key>"
                interactive: false
            }
        }
    }
}
