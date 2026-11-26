pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

WidgetCard {
    id: root

    property bool running: true
    property bool showExtra: false

    title: "Limits"
    aside: AgentLimits.loading ? "updating" : ""

    Repeater {
        model: AgentLimits.providers

        delegate: Column {
            id: providerBlock

            required property var modelData

            readonly property color providerColor: AgentLimits.colorFor(providerBlock.modelData.id)
            readonly property var extraList: providerBlock.modelData.extra ?? []

            width: parent ? parent.width : 0
            spacing: Appearance.padding.small

            Row {
                width: parent.width
                spacing: Appearance.padding.small

                SquircleRect {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    pill: "object"
                    color: providerBlock.providerColor
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: providerBlock.modelData.name
                    font.pixelSize: Appearance.font.size.normal
                    font.weight: Font.DemiBold
                    color: Appearance.colour.text
                }
            }

            Repeater {
                model: providerBlock.modelData.primary ?? []

                delegate: LimitBar {
                    required property var modelData

                    width: providerBlock.width
                    compact: true
                    label: modelData.label
                    remaining: AgentLimits.remainingPercent(modelData.usedPercent)
                    remainingFraction: AgentLimits.remainingFraction(modelData.usedPercent)
                    elapsedFraction: AgentLimits.paceFraction(modelData.resetsAt, modelData.durationMins)
                    resetText: AgentLimits.formatReset(modelData.resetsAt)
                    accentColor: providerBlock.providerColor
                }
            }

            Repeater {
                model: root.showExtra ? providerBlock.extraList : []

                delegate: LimitBar {
                    required property var modelData

                    width: providerBlock.width
                    compact: true
                    label: modelData.label
                    remaining: AgentLimits.remainingPercent(modelData.usedPercent)
                    remainingFraction: AgentLimits.remainingFraction(modelData.usedPercent)
                    elapsedFraction: AgentLimits.paceFraction(modelData.resetsAt, modelData.durationMins)
                    resetText: AgentLimits.formatReset(modelData.resetsAt)
                    accentColor: providerBlock.providerColor
                }
            }

            StyledText {
                visible: (providerBlock.modelData.primary ?? []).length === 0 && (providerBlock.modelData.error ?? "") !== ""
                width: parent.width
                text: providerBlock.modelData.error
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }
        }
    }

    Item {
        width: parent ? parent.width : 0
        height: footerRow.implicitHeight

        Row {
            id: footerRow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            SquircleRect {
                width: moreLabel.implicitWidth + Appearance.padding.normal
                height: moreLabel.implicitHeight + Appearance.padding.small
                pill: "object"
                color: moreArea.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill

                StyledText {
                    id: moreLabel

                    anchors.centerIn: parent
                    text: root.showExtra ? "Less" : "More"
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textDim
                }

                MouseArea {
                    id: moreArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showExtra = !root.showExtra
                }
            }
        }

        SquircleRect {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: refreshIcon.implicitWidth + Appearance.padding.normal
            height: refreshIcon.implicitHeight + Appearance.padding.small
            pill: "object"
            color: refreshArea.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill

            Icon {
                id: refreshIcon

                anchors.centerIn: parent
                name: "refresh"
                size: Appearance.font.size.small
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
