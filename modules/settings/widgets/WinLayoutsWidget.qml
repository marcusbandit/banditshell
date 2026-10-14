pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.controls
import qs.modules.settings
import qs.modules.settings.scenes
import "../catalogue.js" as Catalogue

Column {
    id: root

    property var row: ({})

    readonly property string picked: SettingsState.v("layout")
    readonly property int columns: Math.max(1, Math.floor((root.width + Appearance.padding.small) / (128 + Appearance.padding.small)))
    readonly property real cell: (root.width - (root.columns - 1) * Appearance.padding.small) / root.columns

    width: parent ? parent.width : 0
    topPadding: Appearance.padding.small
    bottomPadding: Appearance.padding.small

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                SettingsView.hovered = root.row;
            else
                SettingsView.layoutHover = "";
        }
    }

    Grid {
        columns: root.columns
        spacing: Appearance.padding.small

        Repeater {
            model: Catalogue.LAYOUTS

            delegate: Item {
                id: card

                required property var modelData

                readonly property bool on: root.picked === card.modelData.id

                width: root.cell
                height: Appearance.padding.normal * 2 + mini.height + Appearance.padding.small + Appearance.font.line.small

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.large
                    color: hover.hovered && !card.on ? Appearance.colour.fillStrong : Appearance.colour.fill

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: Appearance.colour.accentFill
                        visible: card.on
                    }
                }

                LayoutMini {
                    id: mini

                    x: Appearance.padding.small
                    y: Appearance.padding.normal
                    width: parent.width - Appearance.padding.small * 2
                    height: Math.round(width * 10 / 16)
                    layout: card.modelData.id
                    lit: card.on
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: mini.y + mini.height + Appearance.padding.small
                    width: Math.min(implicitWidth, parent.width - Appearance.padding.small * 2)
                    text: card.modelData.name
                    elide: Text.ElideRight
                    color: card.on || hover.hovered ? Appearance.colour.text : Appearance.colour.textDim
                }

                HoverHandler {
                    id: hover

                    onHoveredChanged: if (hovered)
                        SettingsView.layoutHover = card.modelData.id
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsState.set("layout", card.modelData.id)
                }
            }
        }
    }

    MenuLayer {
        width: root.width
        open: root.picked === "custom"

        SettingsRowFrame {
            width: parent.width
            interactive: false
            icon: "extension"
            label: "Custom layout"
            detail: SettingsState.v("customLayout") || "nothing set up yet"

            SettingsTool {
                anchors.verticalCenter: parent.verticalCenter
                icon: "info"
                tip: "custom layouts are still being worked out. this is where yours will plug in."
            }

            Button {
                anchors.verticalCenter: parent.verticalCenter
                size: 0
                text: "Add"
                onClicked: SettingsView.drop("custom layouts are still being worked out · this will pick one", "extension")
            }
        }
    }
}
