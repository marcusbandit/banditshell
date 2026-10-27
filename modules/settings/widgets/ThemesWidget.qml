pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Item {
    id: root

    property var row: ({})

    readonly property bool fromWall: SettingsState.v("fromWall")
    readonly property int columns: SettingsView.tiny ? 2 : 3
    readonly property real gap: Appearance.padding.small
    readonly property real cell: (root.width - Appearance.padding.normal * 2 - (root.columns - 1) * root.gap) / root.columns

    readonly property var cards: Themes.catalogue.map(t => Appearance.lightCard({
                name: t.name,
                dim: t.dim,
                mid: t.mid,
                bright: t.bright,
                alarm: t.alarm,
                background: t.background || Appearance.chosenTheme.ramp[1],
                foreground: t.foreground || Appearance.chosenTheme.ramp[9],
                wall: false
            })).concat([{
                    name: "wallpaper",
                    dim: root.fromWall ? Appearance.theme.dim : Appearance.colour.fillStrong,
                    mid: root.fromWall ? Appearance.theme.mid : Appearance.colour.fillStrong,
                    bright: root.fromWall ? Appearance.theme.bright : Appearance.colour.fillStrong,
                    alarm: root.fromWall ? Appearance.theme.alarm : Appearance.colour.fillStrong,
                    background: root.fromWall ? Appearance.theme.ramp[1] : Appearance.colour.fill,
                    foreground: root.fromWall ? Appearance.theme.ramp[9] : Appearance.colour.textDim,
                    wall: true
                }])

    width: parent ? parent.width : 0
    implicitHeight: grid.height + Appearance.padding.small + Appearance.padding.normal

    HoverHandler {
        onHoveredChanged: if (hovered)
            SettingsView.hovered = root.row
    }

    Grid {
        id: grid

        x: Appearance.padding.normal
        y: Appearance.padding.small
        columns: root.columns
        spacing: root.gap

        Repeater {
            model: root.cards

            delegate: Item {
                id: card

                required property var modelData

                readonly property bool on: card.modelData.wall ? root.fromWall : !root.fromWall && Config.values.theme === card.modelData.name
                readonly property bool usable: !card.modelData.wall && !root.fromWall

                width: root.cell
                height: body.implicitHeight + Appearance.padding.normal * 2
                opacity: !card.modelData.wall && root.fromWall ? Appearance.opacity.disabled : 1

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: -4
                    visible: card.on
                    radius: Appearance.rounding.normal + 4
                    color: Appearance.colour.accent
                }

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: -2
                    visible: card.on
                    radius: Appearance.rounding.normal + 2
                    color: Appearance.colour.surfaceSolid
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: card.modelData.background
                }

                Column {
                    id: body

                    x: Appearance.padding.normal
                    y: Appearance.padding.normal
                    width: parent.width - Appearance.padding.normal * 2
                    spacing: Appearance.padding.small

                    StyledText {
                        width: parent.width
                        text: card.modelData.name
                        color: card.modelData.foreground
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 4

                        Repeater {
                            model: [card.modelData.dim, card.modelData.mid, card.modelData.bright, card.modelData.alarm]

                            delegate: SquircleRect {
                                required property var modelData

                                width: 18
                                height: 18
                                radius: 6
                                color: modelData
                            }
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: card.usable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsState.set("theme", card.modelData.name)
                }
            }
        }
    }
}
