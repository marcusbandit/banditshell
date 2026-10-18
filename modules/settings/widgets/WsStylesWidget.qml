pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings

Item {
    id: root

    property var row: ({})

    readonly property real gap: Appearance.padding.small
    readonly property real cell: (root.width - Appearance.padding.normal * 2 - 2 * root.gap) / 3

    width: parent ? parent.width : 0
    implicitHeight: cards.height + Appearance.padding.small + Appearance.padding.normal

    HoverHandler {
        onHoveredChanged: if (hovered)
            SettingsView.hovered = root.row
    }

    Row {
        id: cards

        x: Appearance.padding.normal
        y: Appearance.padding.small
        spacing: root.gap

        Repeater {
            model: ["plates", "map", "blocks"]

            delegate: Item {
                id: card

                required property string modelData

                readonly property bool on: SettingsState.v("wsStyle") === card.modelData

                width: root.cell
                height: Appearance.padding.normal * 2 + 104 + Appearance.padding.small + Appearance.font.line.small

                FollowColour {
                    id: tone

                    target: tap.pressed && !card.on ? Appearance.colour.fillStronger : tap.containsMouse && !card.on ? Appearance.colour.fillStrong : Appearance.colour.fill
                    speed: Appearance.animation.revealSpeed
                }

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: tone.value

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.accentFill
                        visible: card.on
                    }
                }

                Item {
                    id: mini

                    y: Appearance.padding.normal
                    width: parent.width
                    height: 104
                    clip: true

                    MiniWorkspaces {
                        anchors.centerIn: parent
                        width: implicitWidth
                        height: implicitHeight
                        style: card.modelData
                        colourful: SettingsState.v("iconMode") === "colour"
                        scale: 0.6
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: mini.y + mini.height + Appearance.padding.small
                    text: card.modelData
                    color: card.on ? Appearance.colour.text : Appearance.colour.textDim
                }

                MouseArea {
                    id: tap

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsState.set("wsStyle", card.modelData)
                }
            }
        }
    }
}
