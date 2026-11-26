pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    readonly property var toggleList: [
        { id: "claude", name: "Claude" },
        { id: "antigravity", name: "Antigravity" },
        { id: "codex", name: "Codex" }
    ]

    spacing: Appearance.padding.normal

    Repeater {
        model: AgentLimits.providers

        delegate: Column {
            id: section

            required property var modelData

            readonly property color providerColor: AgentLimits.colorFor(section.modelData.id)

            width: root.width
            spacing: Appearance.padding.small

            Row {
                width: parent.width
                spacing: Appearance.padding.small

                SquircleRect {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    pill: "object"
                    color: section.providerColor
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: section.modelData.name
                    font.pixelSize: Appearance.font.size.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colour.text
                }
            }

            Repeater {
                model: section.modelData.primary ?? []

                delegate: LimitBar {
                    required property var modelData

                    width: section.width
                    label: modelData.label
                    remaining: AgentLimits.remainingPercent(modelData.usedPercent)
                    remainingFraction: AgentLimits.remainingFraction(modelData.usedPercent)
                    elapsedFraction: AgentLimits.paceFraction(modelData.resetsAt, modelData.durationMins)
                    resetText: AgentLimits.formatReset(modelData.resetsAt)
                    accentColor: section.providerColor
                }
            }

            Repeater {
                model: section.modelData.extra ?? []

                delegate: LimitBar {
                    required property var modelData

                    width: section.width
                    label: modelData.label
                    remaining: AgentLimits.remainingPercent(modelData.usedPercent)
                    remainingFraction: AgentLimits.remainingFraction(modelData.usedPercent)
                    elapsedFraction: AgentLimits.paceFraction(modelData.resetsAt, modelData.durationMins)
                    resetText: AgentLimits.formatReset(modelData.resetsAt)
                    accentColor: section.providerColor
                }
            }

            StyledText {
                visible: (section.modelData.primary ?? []).length === 0 && (section.modelData.error ?? "") !== ""
                width: parent.width
                text: section.modelData.error
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }
        }
    }

    StyledText {
        visible: AgentLimits.providers.length === 0
        width: root.width
        text: AgentLimits.loading ? "Checking limits..." : "No providers enabled"
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textDim
    }

    Separator {
        width: root.width
    }

    Item {
        width: root.width
        height: Math.max(toggles.implicitHeight, refreshButton.implicitHeight)

        Row {
            id: toggles

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            Repeater {
                model: root.toggleList

                delegate: SquircleRect {
                    id: chip

                    required property var modelData

                    readonly property bool active: Config.values.agentLimits?.[chip.modelData.id] ?? false
                    readonly property color tone: AgentLimits.colorFor(chip.modelData.id)

                    width: chipRow.implicitWidth + Appearance.padding.normal
                    height: chipRow.implicitHeight + Appearance.padding.small
                    pill: "object"
                    color: chip.active ? Appearance.withAlpha(chip.tone, 0.22) : Appearance.colour.fill

                    Row {
                        id: chipRow

                        anchors.centerIn: parent
                        spacing: 5

                        SquircleRect {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6
                            height: 6
                            pill: "object"
                            color: chip.active ? chip.tone : Appearance.colour.textGhost
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: chip.modelData.name
                            font.pixelSize: Appearance.font.size.small
                            color: chip.active ? Appearance.colour.text : Appearance.colour.textDim
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.set("agentLimits." + chip.modelData.id, !chip.active)
                    }
                }
            }
        }

        SquircleRect {
            id: refreshButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: refreshIcon.implicitWidth + Appearance.padding.normal
            implicitHeight: refreshIcon.implicitHeight + Appearance.padding.small
            pill: "object"
            color: refreshArea.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill

            Icon {
                id: refreshIcon

                anchors.centerIn: parent
                name: "refresh"
                size: Appearance.font.size.normal
                color: AgentLimits.loading ? Appearance.colour.accent : Appearance.colour.textDim
            }

            MouseArea {
                id: refreshArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: AgentLimits.refresh()
            }
        }
    }
}
