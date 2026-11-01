pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services
import "catalogue.js" as Catalogue
import "profile.js" as Profile

Column {
    id: root

    readonly property var s: SettingsState
    readonly property real tileGap: Appearance.padding.normal
    readonly property int columns: SettingsView.tiny ? 2 : 3
    readonly property real tileWidth: Math.floor((root.width - root.tileGap * (root.columns - 1)) / root.columns)
    property real uptime: 0

    readonly property var tiles: [
        { page: "colour", icon: "palette", title: "Colour", line: "theme and accent" },
        { page: "wallpaper", icon: "wallpaper", title: "Wallpaper", line: "pick a new one" },
        { page: "widgets", icon: "widgets", title: "Widgets", line: "on your desktop" },
        { page: "sidebar", icon: "side_navigation", title: "Sidebar", line: "workspaces and status" },
        { page: "notifications", icon: "notifications", title: "Notifications", line: "popups and sounds" },
        { page: "lock", icon: "lock", title: "Lock and idle", line: "when the screen locks" }
    ].filter(t => !!Catalogue.PAGE_BY_ID[t.page])

    spacing: Appearance.padding.large

    WallClock {
        id: clock

        precision: WallClock.Minutes
        enabled: root.visible
        onDateChanged: uptimeFile.reload()
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptime = Number(text().split(" ")[0]) || 0
    }

    Column {
        width: parent.width
        topPadding: Appearance.padding.normal
        spacing: Appearance.padding.small

        SettingsAvatar {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 88
            height: 88
        }

        Item {
            width: 1
            height: Appearance.padding.small
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: `${Profile.greeting(clock.hours)}, ${Quickshell.env("USER") || "you"}`
            font.pixelSize: Appearance.font.size.display
            font.weight: Font.DemiBold
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: `${TimeFormat.dateText(clock.date, "headline") ?? ""} · ${TimeFormat.time(clock.date, false)}`
            color: Appearance.colour.textFaint
        }

        Item {
            width: 1
            height: Appearance.padding.small
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.small

            Chip {
                icon: "palette"
                text: root.s.v("fromWall") ? "Colours from the wallpaper" : `${String(root.s.v("theme")).charAt(0).toUpperCase()}${String(root.s.v("theme")).slice(1)} theme`
            }

            Chip {
                icon: "schedule"
                text: Profile.uptimeText(root.uptime)
                visible: root.uptime > 0
            }

            Chip {
                glyph: Profile.distroGlyph(SettingsState.os)
                text: SettingsState.os
            }
        }
    }

    Item {
        width: parent.width
        height: hint.implicitHeight + Appearance.padding.card * 2

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill
        }

        Item {
            id: bulb

            x: Appearance.padding.card
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40

            SquircleRect {
                anchors.fill: parent
                pill: "object"
                color: Appearance.colour.accentFill
            }

            Icon {
                anchors.centerIn: parent
                name: "lightbulb"
                color: Appearance.colour.accent
            }
        }

        Column {
            id: hint

            x: bulb.x + bulb.width + Appearance.padding.card
            width: parent.width - x - Appearance.padding.card
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                text: "Make yourself at home"
                font.weight: Font.DemiBold
            }

            StyledText {
                width: parent.width
                text: "Point at the bottom right corner to open settings from anywhere. Drag the top edge to move this window."
                color: Appearance.colour.textFaint
                wrapMode: Text.WordWrap
            }
        }
    }

    StyledText {
        x: Appearance.padding.small
        text: "Make it yours"
        font.pixelSize: Appearance.font.size.normal
        font.weight: Font.DemiBold
    }

    Flow {
        width: parent.width
        spacing: root.tileGap

        Repeater {
            model: root.tiles

            delegate: Item {
                id: tile

                required property var modelData

                width: root.tileWidth
                height: 64

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.fill
                    opacity: lift.value

                    Follow {
                        id: lift

                        target: tileHover.hovered ? 1 : 0
                        speed: Appearance.animation.revealSpeed
                        epsilon: Appearance.animation.fadeEpsilon
                        startsAtTarget: true
                    }
                }

                Item {
                    id: mark

                    x: Appearance.padding.card
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.small
                        color: Appearance.colour.fillStrong
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: tile.modelData.icon
                        color: Appearance.colour.text
                    }
                }

                Column {
                    x: mark.x + mark.width + Appearance.padding.normal
                    width: parent.width - x - Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        width: parent.width
                        text: tile.modelData.title
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: tile.modelData.line
                        color: Appearance.colour.textFaint
                        elide: Text.ElideRight
                    }
                }

                HoverHandler {
                    id: tileHover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsView.go(tile.modelData.page)
                }
            }
        }
    }

    component Chip: Item {
        id: chip

        property string icon: ""
        property string glyph: ""
        property string text: ""

        implicitWidth: chipRow.implicitWidth + Appearance.padding.normal * 2
        implicitHeight: 30

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: Appearance.colour.fill
            stroke: Appearance.colour.separator
            strokeWidth: 1
        }

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: Appearance.padding.small

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.icon !== ""
                name: chip.icon
                size: Math.round(Appearance.font.iconSize * 0.9)
                color: Appearance.colour.textDim
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: chip.glyph !== ""
                text: chip.glyph
                font.family: Appearance.font.brand
                color: Appearance.colour.textDim
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.text
                color: Appearance.colour.textDim
            }
        }
    }
}
