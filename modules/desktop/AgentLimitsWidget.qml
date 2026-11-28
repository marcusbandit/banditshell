pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

DeskWidget {
    id: root

    property bool running: true

    readonly property real pad: Appearance.padding.card

    function paceWords(note: var): string {
        if (!note)
            return "";
        if (note.kind === "ahead")
            return `Take a break for ${note.time}`;
        if (note.kind === "behind")
            return `You wasted ${note.time}`;
        return "Right on pace";
    }

    function tightest(windows: var): var {
        let best = null;
        for (const w of windows ?? []) {
            const left = AgentLimits.remainingFraction(w.usedPercent);
            if (!best || left < best.left)
                best = {
                    left,
                    window: w
                };
        }
        return best;
    }

    key: "limits"
    fallbackSize: "medium"

    small: Item {
        implicitWidth: Math.round(Appearance.font.size.small * 16) + root.pad * 2
        implicitHeight: smallList.implicitHeight + Appearance.padding.normal * 2

        Column {
            id: smallList

            x: root.pad
            y: Appearance.padding.normal
            width: parent.width - root.pad * 2
            spacing: Appearance.padding.small

            Repeater {
                model: AgentLimits.providers

                delegate: Column {
                    id: brief

                    required property var modelData

                    readonly property var worst: root.tightest(brief.modelData.primary)

                    width: parent.width
                    spacing: Appearance.padding.hair

                    HoverHandler {
                        id: briefHover
                    }

                    Item {
                        width: parent.width
                        height: briefName.implicitHeight

                        Dot {
                            anchors.verticalCenter: parent.verticalCenter
                            owner: brief.modelData.id
                        }

                        StyledText {
                            id: briefName

                            x: Appearance.padding.normal
                            text: brief.modelData.name
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            anchors.right: parent.right
                            text: brief.worst ? `${Math.round(brief.worst.left * 100)}%` : "-"
                            color: Appearance.colour.textDim
                        }
                    }

                    Bar {
                        width: parent.width
                        owner: brief.modelData.id
                        share: brief.worst?.left ?? 0
                        pace: brief.worst ? AgentLimits.paceFraction(brief.worst.window.resetsAt, brief.worst.window.durationMins) : -1
                        durationMins: brief.worst?.window.durationMins ?? 0
                        hovered: briefHover.hovered
                    }
                }
            }
        }
    }

    medium: Item {
        implicitWidth: Math.round(Appearance.font.size.small * 22) + root.pad * 2
        implicitHeight: mediumList.implicitHeight + root.pad * 2

        Providers {
            id: mediumList

            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
            extra: false
        }
    }

    large: Item {
        implicitWidth: Math.round(Appearance.font.size.small * 26) + root.pad * 2
        implicitHeight: largeBody.implicitHeight + root.pad * 2

        Column {
            id: largeBody

            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
            spacing: Appearance.padding.large

            Providers {
                width: parent.width
                extra: true
            }

            Item {
                width: parent.width
                height: refresh.height

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: AgentLimits.loading ? "Updating" : AgentLimits.fetchedAt > 0 ? `Updated ${TimeFormat.recent(new Date(AgentLimits.fetchedAt))}` : ""
                    color: Appearance.colour.textFaint
                    font.pixelSize: Appearance.font.size.small
                }

                Item {
                    id: refresh

                    anchors.right: parent.right
                    width: Math.round(Appearance.font.iconSize * 1.6)
                    height: refresh.width

                    SquircleRect {
                        anchors.fill: parent
                        pill: "object"
                        color: Appearance.colour.fill
                        opacity: refreshHover.hovered ? 1 : 0
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "refresh"
                        size: Appearance.icon.small
                        color: AgentLimits.loading ? Appearance.colour.text : Appearance.colour.textDim
                    }

                    HoverHandler {
                        id: refreshHover
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AgentLimits.refresh()
                    }
                }
            }
        }
    }

    component Providers: Column {
        id: list

        property bool extra: false

        spacing: Appearance.padding.large

        Repeater {
            model: AgentLimits.providers

            delegate: Column {
                id: providerBlock

                required property var modelData

                width: list.width
                spacing: Appearance.padding.normal

                Item {
                    width: parent.width
                    height: providerName.implicitHeight

                    Dot {
                        anchors.verticalCenter: parent.verticalCenter
                        owner: providerBlock.modelData.id
                    }

                    StyledText {
                        id: providerName

                        x: Appearance.padding.normal
                        text: providerBlock.modelData.name
                        font.weight: Font.DemiBold
                    }
                }

                StyledText {
                    width: parent.width
                    visible: (providerBlock.modelData.primary ?? []).length === 0 && (providerBlock.modelData.error ?? "") !== ""
                    text: providerBlock.modelData.error ?? ""
                    color: Appearance.colour.textDim
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }

                Repeater {
                    model: (providerBlock.modelData.primary ?? []).concat(list.extra ? providerBlock.modelData.extra ?? [] : [])

                    delegate: Line {
                        required property var modelData

                        width: providerBlock.width
                        owner: providerBlock.modelData.id
                        window: modelData
                    }
                }
            }
        }
    }

    component Line: Column {
        id: line

        property string owner: ""
        property var window: ({})

        readonly property real share: AgentLimits.remainingFraction(line.window.usedPercent)

        spacing: Appearance.padding.hair

        HoverHandler {
            id: lineHover
        }

        Item {
            width: parent.width
            height: lineValue.implicitHeight

            StyledText {
                anchors.baseline: lineValue.baseline
                width: lineValue.x - Appearance.padding.normal
                text: line.window.label ?? ""
                color: Appearance.colour.textDim
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }

            StyledText {
                id: lineValue

                anchors.right: lineReset.left
                anchors.rightMargin: Appearance.padding.normal
                text: `${Math.round(line.share * 100)}%`
                font.weight: Font.DemiBold
            }

            StyledText {
                id: lineReset

                anchors.right: parent.right
                anchors.baseline: lineValue.baseline
                width: Math.round(Appearance.font.size.small * 3.6)
                horizontalAlignment: Text.AlignRight
                text: AgentLimits.formatReset(line.window.resetsAt)
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }

        Bar {
            width: parent.width
            owner: line.owner
            share: line.share
            pace: AgentLimits.paceFraction(line.window.resetsAt, line.window.durationMins)
            durationMins: line.window.durationMins ?? 0
            hovered: lineHover.hovered
        }
    }

    component Dot: SquircleRect {
        property string owner: ""

        width: Math.round(Appearance.padding.small * 0.75)
        height: width
        pill: "object"
        color: AgentLimits.colorFor(owner)
    }

    component Bar: Item {
        id: bar

        property string owner: ""
        property real share: 0
        property real pace: -1
        property int durationMins: 0
        property bool hovered: false

        height: 4

        Follow {
            id: level

            target: Math.max(0, Math.min(1, bar.share))
            speed: Appearance.animation.trackSpeed
            epsilon: 0.002
            startsAtTarget: true
        }

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: Appearance.colour.fill
        }

        SquircleRect {
            width: level.value > 0 ? Math.max(bar.height, bar.width * level.value) : 0
            height: bar.height
            pill: "object"
            color: Qt.alpha(AgentLimits.colorFor(bar.owner), 0.85)
        }

        Rectangle {
            visible: bar.pace >= 0 && bar.pace <= 1
            x: Math.max(0, Math.min(bar.width - width, Math.round(bar.width * bar.pace) - 1))
            y: -2
            width: 2
            height: bar.height + 4
            color: Appearance.colour.text
        }

        FloatingTooltip {
            text: root.paceWords(AgentLimits.paceNote(bar.share, bar.pace, bar.durationMins))
            shown: bar.hovered
        }
    }
}
