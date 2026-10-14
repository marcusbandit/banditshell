pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "../catalogue.js" as Catalogue

Column {
    id: root

    property var row: ({})

    readonly property string mode: SettingsState.v("mode")
    readonly property int columns: SettingsView.tiny ? 3 : 5
    readonly property real cell: (root.width - (root.columns - 1) * Appearance.padding.small) / root.columns

    width: parent ? parent.width : 0
    topPadding: Appearance.padding.small

    HoverHandler {
        onHoveredChanged: if (hovered)
            SettingsView.hovered = root.row
    }

    Grid {
        columns: root.columns
        spacing: Appearance.padding.small
        bottomPadding: Appearance.padding.small

        Repeater {
            model: Catalogue.MODES

            delegate: Item {
                id: mode

                required property var modelData

                readonly property bool on: root.mode === mode.modelData.id

                width: root.cell
                height: Appearance.padding.card * 2 + Math.round(Appearance.font.iconSize * 1.4) + 4 + 4 + Appearance.font.line.small

                SquircleRect {
                    anchors.fill: parent
                    radius: Appearance.rounding.large
                    color: hover.hovered && !mode.on ? Appearance.colour.fillStrong : Appearance.colour.fill

                    SquircleRect {
                        anchors.fill: parent
                        radius: Appearance.rounding.large
                        color: Appearance.colour.accentFill
                        visible: mode.on
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Icon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        name: mode.modelData.icon
                        size: Math.round(Appearance.font.iconSize * 1.4)
                        fill: mode.on ? 1 : 0
                        color: mode.on ? Appearance.colour.accent : Appearance.colour.textFaint
                        bottomPadding: 4
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: mode.modelData.name
                        color: mode.on || hover.hovered ? Appearance.colour.text : Appearance.colour.textDim
                    }
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const n = Object.keys(mode.modelData.set).length;
                        SettingsState.setMode(mode.modelData.id);
                        SettingsView.drop(mode.modelData.id === "none" ? "back to everything as set" : `${mode.modelData.id} mode · ${n} settings changed`, mode.modelData.icon);
                    }
                }
            }
        }
    }

    StyledText {
        x: Appearance.padding.normal
        width: root.width - Appearance.padding.normal * 2
        topPadding: Appearance.padding.small
        bottomPadding: Appearance.padding.normal
        text: "a mode flips a few settings and puts them back when you leave it. its glyph sits above the status icons."
        color: Appearance.colour.textFaint
        wrapMode: Text.WordWrap
    }
}
