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

        SquircleRect {
            width: parent.width
            height: current.implicitHeight + Appearance.padding.card * 2
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill

            Column {
                id: current

                x: Appearance.padding.card
                y: Appearance.padding.card
                width: parent.width - Appearance.padding.card * 2
                spacing: Appearance.padding.normal

                SquircleImage {
                    id: picture

                    visible: picture.ready
                    width: parent.width
                    height: width * 9 / 16
                    radius: Appearance.rounding.normal
                    fillMode: Image.PreserveAspectCrop
                    source: Wallpaper.faceOf(Wallpaper.current)
                }

                SquircleRect {
                    visible: !picture.ready
                    width: parent.width
                    height: width * 9 / 16
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill

                    StyledText {
                        anchors.centerIn: parent

                        text: Wallpaper.ready ? "the file is not on disk" : "no wallpaper set"
                        color: Appearance.colour.textFaint
                    }
                }

                StyledText {
                    width: parent.width
                    text: Wallpaper.name || "nothing set"
                    wrapMode: Text.Wrap
                    color: Appearance.colour.text
                }

                StyledText {
                    width: parent.width
                    visible: !!Wallpaper.kind
                    text: Wallpaper.kind
                    wrapMode: Text.Wrap
                    color: Appearance.colour.textFaint
                }
            }
        }

        SettingsCard {
            title: "Wallpaper"

            SettingsRow {
                icon: "wallpaper"
                label: "Show a wallpaper"
                onActivated: Wallpaper.toggle()

                Toggle {
                    checked: Wallpaper.enabled
                    onToggled: Wallpaper.toggle()
                }
            }

            SettingsRow {
                visible: Wallpaper.available.some(p => Wallpaper.movesOf(p)) || Wallpaper.moves
                icon: "motion_photos_on"
                label: "Play animated wallpapers"
                detail: "only on an empty workspace"
                onActivated: Config.set("wallpaper.animate", !Config.values.wallpaper.animate)

                Toggle {
                    checked: Config.values.wallpaper.animate
                    onToggled: Config.set("wallpaper.animate", !Config.values.wallpaper.animate)
                }
            }
        }

        SettingsGroup {
            heading: `Choose, ${Wallpaper.available.length} in the folder`

            PathField {
                width: parent.width
                icon: "folder"
                label: "Wallpaper folder"
                value: Config.values.wallpaper.dir
                placeholder: "~/Pictures/Wallpapers"
                tip: "type a different folder"
                detail: {
                    const n = Wallpaper.available.length;
                    if (!n)
                        return "nothing usable in it";
                    const fit = Wallpaper.fittedFor(Wallpaper.screenAspect(Wallpaper.here)).length;
                    return fit < n ? `${fit} of them fit ${Wallpaper.here}` : "read all the way down";
                }
                onCommitted: path => Config.set("wallpaper.dir", path)
            }

            SquircleRect {
                width: parent.width
                height: grid.implicitHeight + Appearance.padding.card * 2
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                Grid {
                    id: grid

                    readonly property int cell: Math.floor((width - (columns - 1) * spacing) / columns)

                    x: Appearance.padding.card
                    y: Appearance.padding.card
                    width: parent.width - Appearance.padding.card * 2
                    columns: Math.max(2, Math.floor(width / (Appearance.sizes.settingsPane / 2)))
                    spacing: Appearance.padding.small

                    Repeater {
                        model: Wallpaper.available

                        delegate: Item {
                            id: tile

                            required property string modelData

                            readonly property bool current: Wallpaper.current === tile.modelData

                            width: grid.cell
                            height: grid.cell * 9 / 16

                            SquircleImage {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                fillMode: Image.PreserveAspectCrop
                                source: Wallpaper.faceOf(tile.modelData)
                            }

                            SquircleRect {
                                anchors.fill: parent
                                visible: tile.current
                                radius: Appearance.rounding.small
                                color: "transparent"
                                stroke: Appearance.colour.accent
                                strokeWidth: Appearance.font.stem * 2
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Wallpaper.setFrom(tile.modelData, 0.5, 0.5)
                            }
                        }
                    }
                }
            }
        }
    }
}
