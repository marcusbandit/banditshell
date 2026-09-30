pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        SettingsCard {
            title: "Palette"

            Repeater {
                model: Themes.availableNames

                delegate: SettingsRow {
                    id: row

                    required property string modelData

                    readonly property var accents: Themes.accentsFor(row.modelData)

                    label: row.modelData
                    selected: Themes.activeName === row.modelData
                    onActivated: Themes.apply(row.modelData)

                    Row {
                        spacing: Appearance.padding.small

                        Repeater {
                            model: [row.accents.dim, row.accents.mid, row.accents.bright]

                            delegate: SquircleRect {
                                required property color modelData

                                width: Appearance.font.size.small
                                height: width
                                radius: Appearance.rounding.small
                                color: modelData
                            }
                        }
                    }
                }
            }
        }

        SettingsCard {
            title: "Type"

            SettingsRow {
                icon: "text_fields"
                label: "Font"
                value: Appearance.font.family
                chevron: true
                onActivated: Settings.setPage("font")
            }
        }

        SettingsCard {
            title: "Wallpaper"

            SettingsRow {
                icon: "wallpaper"
                label: "Wallpaper"
                value: Wallpaper.name
                chevron: true
                onActivated: Settings.setPage("wallpaper")
            }
        }

        SettingsCard {
            title: "Compositor"

            SettingsRow {
                icon: "crop_square"
                label: "Corners and gaps from the compositor"
                onActivated: Config.set("compositor.follow", !Config.values.compositor.follow)

                Toggle {
                    checked: Config.values.compositor.follow
                    onToggled: Config.set("compositor.follow", !Config.values.compositor.follow)
                }
            }

            SettingsRow {
                icon: "border_color"
                label: "Push the theme onto window borders"
                onActivated: Config.set("compositor.pushBorders", !Config.values.compositor.pushBorders)

                Toggle {
                    checked: Config.values.compositor.pushBorders
                    onToggled: Config.set("compositor.pushBorders", !Config.values.compositor.pushBorders)
                }
            }
        }

        SettingsCard {
            title: "Theme from wallpaper"
            visible: Wallpaper.palette.length > 0

            SettingsRow {
                icon: "colorize"
                label: "Theme from wallpaper"
                detail: "not worn yet"
                onActivated: Config.set("themeFromWallpaper", !Config.values.themeFromWallpaper)

                Row {
                    spacing: Appearance.padding.normal

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.font.stem

                        Repeater {
                            model: Wallpaper.palette

                            delegate: SquircleRect {
                                required property var modelData

                                readonly property real swatch: Appearance.font.size.normal

                                width: Math.max(Appearance.font.stem * 2, Math.round(swatch * Math.min(1, modelData.share * 2.5)))
                                height: swatch
                                radius: Appearance.rounding.small
                                color: modelData.colour
                            }
                        }
                    }

                    Toggle {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Config.values.themeFromWallpaper
                        onToggled: Config.set("themeFromWallpaper", !Config.values.themeFromWallpaper)
                    }
                }
            }
        }
    }
}
