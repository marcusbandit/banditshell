pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config
import qs.components
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

        Row {
            width: list.width
            spacing: Appearance.padding.normal

            SquircleRect {
                id: mark

                readonly property int ribs: 3
                readonly property real pitch: Appearance.padding.small
                readonly property real span: Appearance.font.size.large * 2

                width: mark.span
                height: mark.span
                radius: Appearance.rounding.normal
                color: Appearance.colour.accentFill
                stroke: Appearance.colour.accent
                strokeWidth: Appearance.font.stem

                Repeater {
                    model: mark.ribs

                    SquircleRect {
                        id: rib

                        required property int index

                        readonly property real reach: (rib.index + 1) / (mark.ribs + 1) * mark.span / Math.SQRT2

                        width: rib.reach * 2
                        height: Appearance.font.stem
                        radius: rib.height / 2

                        x: mark.span - rib.reach / Math.SQRT2 - rib.width / 2
                        y: mark.span - rib.reach / Math.SQRT2 - rib.height / 2
                        rotation: -45

                        color: Appearance.colour.accent
                    }
                }
            }

            Column {
                width: list.width - mark.width - Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: "banditshell"
                    font.pixelSize: Appearance.font.size.large
                    color: Appearance.colour.text
                }

                StyledText {
                    width: parent.width
                    text: (Device.version || "unknown version") + (Device.commitDate ? ` · ${Device.commitDate}` : "")
                    wrapMode: Text.Wrap
                    color: Appearance.colour.textFaint
                }

                StyledText {
                    width: parent.width
                    text: "a desktop shell written to be understood"
                    wrapMode: Text.Wrap
                    color: Appearance.colour.textDim
                }
            }
        }

        SettingsCard {
            title: "Running on"

            SettingsRow {
                icon: "desktop_windows"
                label: "Compositor"
                value: [Compositor.name, Device.compositorVersion].filter(p => p).join(" ")
                interactive: false
            }

            SettingsRow {
                visible: Compositor.isHyprland
                icon: "code"
                label: "Config dialect"
                value: !Hypr.parserKnown ? "asking" : Hypr.lua ? "lua" : "legacy"
                interactive: false
            }

            SettingsRow {
                visible: !Compositor.isHyprland
                icon: "info"
                label: "Hyprland-only features are off"
                detail: "the shell runs, and everything that speaks to the compositor waits for Hyprland"
                interactive: false
            }
        }

        SettingsCard {
            title: "Read more"

            SettingsRow {
                icon: "menu_book"
                label: "Design notes"
                detail: "DESIGN.md: the reasons behind every part of it"
                onActivated: opener.exec(["xdg-open", `${Device.shellDir}/DESIGN.md`])
            }

            SettingsRow {
                icon: "folder"
                label: "Source"
                detail: Device.shellDir
                onActivated: opener.exec(["xdg-open", Device.shellDir])
            }

            SettingsRow {
                icon: "description"
                label: "Settings file"
                detail: Config.path
                onActivated: opener.exec(["xdg-open", Config.path])
            }

            SettingsRow {
                icon: "keyboard"
                label: "Hotkeys"
                detail: "every bind the compositor knows, drawn live"
                onActivated: Shell.forScreen(Settings.screenName)?.hotkeys.show()
            }
        }
    }
}
