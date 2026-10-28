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
    readonly property real gap: Appearance.padding.small
    readonly property real cardNeed: Math.max(names.implicitWidth, 18 * 4 + 4 * 3) + Appearance.padding.normal * 2
    readonly property bool squeezed: SettingsView.tiny || root.cellAt(3) < root.cardNeed
    readonly property int columns: root.squeezed ? 2 : 3
    readonly property real cell: root.squeezed ? Math.min(root.cellAt(2), root.cardNeed) : root.cellAt(3)
    readonly property var shown: {
        const list = root.cards.slice();
        const last = list.length - 1;
        if (root.squeezed && list.length % 2 === 1 && last > 0 && root.picked(list[last]))
            [list[last - 1], list[last]] = [list[last], list[last - 1]];
        return list;
    }

    function picked(card: var): bool {
        return card.wall ? root.fromWall : !root.fromWall && Config.values.theme === card.name;
    }

    function cellAt(columns: int): real {
        return (root.width - Appearance.padding.normal * 2 - (columns - 1) * root.gap) / columns;
    }

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
    implicitHeight: grid.childrenRect.height + Appearance.padding.small + Appearance.padding.normal

    HoverHandler {
        onHoveredChanged: if (hovered)
            SettingsView.hovered = root.row
    }

    Column {
        id: names

        visible: false

        Repeater {
            model: root.cards

            delegate: StyledText {
                required property var modelData

                text: modelData.name
            }
        }
    }

    Item {
        id: grid

        y: Appearance.padding.small
        width: root.width

        Repeater {
            model: root.shown

            delegate: Item {
                id: card

                required property var modelData
                required property int index

                readonly property int line: Math.floor(card.index / root.columns)
                readonly property int across: Math.min(root.columns, root.shown.length - card.line * root.columns)

                x: (root.width - card.across * root.cell - (card.across - 1) * root.gap) / 2 + (card.index % root.columns) * (root.cell + root.gap)
                y: card.line * (card.height + root.gap)

                readonly property bool on: root.picked(card.modelData)
                readonly property bool usable: !card.modelData.wall && !root.fromWall

                width: root.cell
                height: body.implicitHeight + Appearance.padding.normal * 2
                opacity: !card.modelData.wall && root.fromWall ? Appearance.opacity.disabled : 1

                SquircleRect {
                    anchors.fill: parent
                    visible: card.on
                    radius: Appearance.rounding.normal
                    color: Appearance.colour.accent
                }

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: 2
                    visible: card.on
                    radius: Appearance.rounding.normal - 2
                    color: Appearance.colour.surfaceSolid
                }

                SquircleRect {
                    anchors.fill: parent
                    anchors.margins: card.on ? 4 : 0
                    radius: Appearance.rounding.normal - (card.on ? 4 : 0)
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
