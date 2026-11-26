pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool rail: false

    readonly property bool shown: AgentLimits.sidebarWanted && AgentLimits.ready
    readonly property bool hovered: area.containsMouse
    readonly property real barHeight: root.rail ? 54 : 44

    signal requested(bool deliberate)
    signal released

    visible: root.shown
    implicitHeight: root.shown ? stack.implicitHeight + Appearance.padding.small * 2 : 0

    SquircleRect {
        anchors.fill: parent
        anchors.leftMargin: root.rail ? 2 : Appearance.padding.hair
        anchors.rightMargin: root.rail ? 2 : Appearance.padding.hair
        radius: Appearance.rounding.small
        color: Appearance.colour.fill
        opacity: hoverGlow.value
        visible: hoverGlow.value > 0.01
    }

    Follow {
        id: hoverGlow

        target: area.containsMouse ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
    }

    Column {
        id: stack

        anchors.centerIn: parent
        spacing: root.rail ? Appearance.padding.normal : Appearance.padding.large

        Repeater {
            model: AgentLimits.compact

            delegate: Column {
                id: group

                required property var modelData

                readonly property color tone: AgentLimits.colorFor(group.modelData.id)
                readonly property int count: group.modelData.windows.length
                readonly property real barWidth: root.rail ? (group.count > 1 ? 6 : 8) : (group.count > 1 ? 10 : 14)

                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 4

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.rail ? 3 : 6

                    Repeater {
                        model: group.modelData.windows

                        delegate: Column {
                            id: col

                            required property var modelData

                            readonly property int pct: AgentLimits.remainingPercent(col.modelData.usedPercent)
                            readonly property real rem: AgentLimits.remainingFraction(col.modelData.usedPercent)
                            readonly property real pace: AgentLimits.paceFraction(col.modelData.resetsAt, col.modelData.durationMins)

                            spacing: 3

                            Item {
                                id: track

                                anchors.horizontalCenter: parent.horizontalCenter
                                width: group.barWidth
                                height: root.barHeight

                                Follow {
                                    id: level

                                    target: col.rem
                                    speed: Appearance.animation.trackSpeed
                                    epsilon: 0.002
                                    startsAtTarget: true
                                }

                                SquircleRect {
                                    anchors.fill: parent
                                    pill: "object"
                                    color: Appearance.colour.fillStronger
                                }

                                SquircleRect {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: level.value > 0 ? Math.max(track.width, Math.round(track.height * level.value)) : 0
                                    visible: height > 0
                                    pill: "object"
                                    color: group.tone
                                }

                                Rectangle {
                                    visible: col.pace >= 0 && col.pace <= 1
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    y: Math.max(1, Math.min(track.height - 3, Math.round(track.height * (1 - col.pace)) - 1))
                                    height: 2
                                    color: Appearance.colour.text
                                }
                            }

                            StyledText {
                                visible: !root.rail
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: col.pct + "%"
                                font.pixelSize: Math.max(9, Appearance.font.size.small - 2)
                                color: Appearance.colour.textDim
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        enabled: root.shown
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.requested(false)
        onExited: root.released()
        onClicked: root.requested(true)
    }
}
