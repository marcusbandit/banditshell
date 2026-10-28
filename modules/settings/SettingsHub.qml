pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "catalogue.js" as Catalogue

Column {
    id: root

    property var cat: SettingsView.cat
    readonly property var s: SettingsState
    readonly property var note: root.cat ? root.cat.suggest(root.s) : null
    readonly property var tiles: (root.cat?.tiles ?? []).filter(t => Catalogue.present(t, SettingsState))
    readonly property int columns: SettingsView.compact && !SettingsView.tiny && root.tiles.length === 4 ? 4 : 2

    function tileOn(k: string): bool {
        return !!root.s.v(k);
    }

    function flip(t: var): void {
        const on = root.tileOn(t.k);
        if (t.k === "warm")
            SettingsState.set("warmth", on ? 0 : 45);
        else
            SettingsState.set(t.k, !on);
    }

    function follow(note: var): void {
        if (note.go)
            return SettingsView.go(note.go);
        SettingsState.set(note.set[0], note.set[1]);
        SettingsView.drop(`${note.label.toLowerCase()} · done`, note.icon);
    }

    width: parent ? parent.width : 0
    spacing: 0

    SettingsRowFrame {
        width: root.width
        visible: !!root.note
        notice: true
        icon: root.note?.icon ?? ""
        label: root.note?.label ?? ""
        detail: root.note?.detail ?? ""
        onActivated: root.follow(root.note)

        Button {
            visible: !!root.note?.set
            anchors.verticalCenter: parent.verticalCenter
            size: 0
            style: "accent"
            text: "Do it"
            onClicked: root.follow(root.note)
        }

        Icon {
            visible: !root.note?.set
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            color: Appearance.colour.accent
        }
    }

    Item {
        width: 1
        height: root.note ? Appearance.padding.card : 0
    }

    Flow {
        id: grid

        width: root.width
        spacing: Appearance.padding.small

        readonly property real cell: Math.floor((width - (root.columns - 1) * spacing) / root.columns)

        Repeater {
            model: root.tiles

            delegate: Item {
                id: tile

                required property var modelData
                required property int index

                readonly property bool lead: tile.index === 0 && root.tiles.length % 2 === 1
                readonly property bool on: root.tileOn(tile.modelData.k)
                readonly property bool off: !!tile.modelData.dis && tile.modelData.dis(root.s)
                readonly property string det: tile.modelData.det ? String(tile.modelData.det(root.s)) : tile.on ? "on" : "off"

                width: tile.lead ? grid.width : grid.cell
                height: Appearance.padding.card * 2 + Appearance.icon.large + Appearance.padding.small + Appearance.font.line.small * 2 + 4
                opacity: tile.off ? Appearance.opacity.disabled : 1
                scale: squeeze.value

                Follow {
                    id: squeeze

                    target: press.pressed && !tile.off ? 0.96 : 1
                    speed: Appearance.animation.revealSpeed
                    epsilon: Appearance.animation.fadeEpsilon
                    startsAtTarget: true
                }

                FollowColour {
                    id: tileTone

                    target: press.pressed && !tile.on && !tile.off ? Appearance.colour.fillStronger : tileHover.hovered && !tile.on && !tile.off ? Appearance.colour.fillStrong : Appearance.colour.fill
                    speed: Appearance.animation.revealSpeed
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.large
                    color: tileTone.value

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: Appearance.colour.accentFill
                        visible: tile.on
                    }
                }

                Column {
                    x: Appearance.padding.card
                    y: Appearance.padding.card
                    width: parent.width - Appearance.padding.card * 2
                    spacing: 2

                    Icon {
                        name: tile.modelData.icon
                        size: Appearance.icon.large
                        fill: tile.on ? 1 : 0
                        color: tile.on ? Appearance.colour.accent : Appearance.colour.textFaint
                    }

                    Item {
                        width: 1
                        height: Appearance.padding.small - 2
                    }

                    StyledText {
                        width: parent.width
                        text: tile.modelData.label
                        elide: Text.ElideRight
                        color: tile.on || tileHover.hovered ? Appearance.colour.text : Appearance.colour.textDim
                    }

                    StyledText {
                        width: parent.width
                        text: tile.det
                        elide: Text.ElideRight
                        color: Appearance.colour.textFaint
                    }
                }

                HoverHandler {
                    id: tileHover
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    enabled: !tile.off
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.flip(tile.modelData)
                }
            }
        }
    }

    Item {
        width: 1
        height: Appearance.padding.large
    }

    Repeater {
        model: (root.cat?.pages ?? []).filter(p => Catalogue.present(p, SettingsState))

        delegate: SettingsRowFrame {
            id: page

            required property var modelData

            width: root.width
            icon: page.modelData.icon
            label: Catalogue.nameOf(page.modelData, SettingsState)
            detail: String(page.modelData.status(root.s) ?? "")
            off: false
            onActivated: SettingsView.go(page.modelData.id)

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron_right"
                color: Appearance.colour.textFaint
            }
        }
    }
}
