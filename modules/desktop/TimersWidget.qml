pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "countdown.js" as Countdown

WidgetCard {
    id: root

    property bool running: true

    readonly property var live: Clock.timers.filter(t => !t.finished)


    WallClock {
        id: tick

        precision: WallClock.Seconds
        enabled: root.running && root.visible && root.live.some(t => !t.paused)
    }

    Repeater {
        model: root.live

        delegate: Item {
            id: line

            required property var modelData

            readonly property double remaining: Clock.remainingOf(line.modelData, tick.date.getTime())

            width: parent.width
            height: 40

            ProgressRing {
                id: ring

                anchors.verticalCenter: parent.verticalCenter
                size: 32
                thickness: 4
                value: line.modelData.total > 0 ? line.remaining / line.modelData.total : 0
                colour: line.modelData.paused ? Appearance.colour.textFaint : Appearance.colour.accent
            }

            Column {
                x: ring.width + Appearance.padding.normal
                width: parent.width - x - remove.width - Appearance.padding.small
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: Countdown.text(line.remaining)
                    font.pixelSize: Appearance.font.size.large
                    font.weight: Font.DemiBold
                    color: line.modelData.paused ? Appearance.colour.textDim : Appearance.colour.text
                }

                StyledText {
                    width: parent.width
                    visible: text !== ""
                    text: line.modelData.paused ? "paused" : line.modelData.label
                    color: Appearance.colour.textFaint
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: remove.width + Appearance.padding.small
                cursorShape: Qt.PointingHandCursor
                onClicked: Clock.toggleTimer(line.modelData.id)
            }

            Pill {
                id: remove

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                onClicked: Clock.removeTimer(line.modelData.id)
            }
        }
    }

    Item {
        width: parent.width
        height: Math.max(quick.height, start.implicitHeight)

        Icon {
            id: clockMark

            anchors.verticalCenter: parent.verticalCenter
            name: "timer"
            color: Appearance.colour.textDim
        }

        StyledText {
            id: start

            x: clockMark.width + Appearance.padding.normal
            width: quick.x - x - Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            text: "Start"
            color: Appearance.colour.textDim
            elide: Text.ElideRight
        }

        Row {
            id: quick

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.small

            Repeater {
                model: [5, 10, 25]

                delegate: Pill {
                    required property int modelData

                    text: `${modelData} min`
                    onClicked: Clock.startTimer(modelData * 60, "")
                }
            }
        }
    }

    component Pill: Item {
        id: pill

        property string text: ""
        property string icon: ""

        signal clicked

        implicitWidth: pill.icon ? 32 : words.implicitWidth + Appearance.padding.card * 2
        implicitHeight: 32

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: Appearance.colour.fill
            stroke: Appearance.colour.separator
            strokeWidth: pill.icon ? 0 : 1
        }

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: Appearance.colour.fill
            opacity: lit.value

            Follow {
                id: lit

                target: pillHover.hovered ? 1 : 0
                speed: Appearance.animation.revealSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: true
            }
        }

        StyledText {
            id: words

            anchors.centerIn: parent
            visible: !pill.icon
            text: pill.text
            color: Appearance.colour.textDim
        }

        Icon {
            anchors.centerIn: parent
            visible: !!pill.icon
            name: pill.icon
            size: Math.round(Appearance.font.iconSize * 0.9)
            color: Appearance.colour.textFaint
        }

        HoverHandler {
            id: pillHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }
}
