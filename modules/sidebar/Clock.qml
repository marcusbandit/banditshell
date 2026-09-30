import QtQuick
import Quickshell
import qs.config
import qs.components

import qs.services as Services

Column {
    id: root

    property alias precision: clock.precision

    property real pullSpan: 0

    readonly property date now: clock.date

    readonly property string localCity: Services.Clock.localCity

    readonly property Item dateItem: dateSlot

    readonly property Item timeItem: timeSlot

    signal calendarRequested(bool deliberate)
    signal calendarPulled
    signal calendarPullEnded(bool open)

    signal clockRequested(bool deliberate)
    signal clockPulled
    signal clockPullEnded(bool open)

    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Item {
        id: timeSlot

        width: parent.width
        height: Math.max(Appearance.sizes.minTarget, drawnTime.implicitHeight)

        Pull {
            id: clockSummon

            anchors.fill: parent

            dirX: 1
            dirY: 0

            angle: Appearance.sizes.pullAngleEdge

            travel: Math.max(1, root.pullSpan * Appearance.sizes.pullTravel)

            cursorShape: Qt.PointingHandCursor

            onTapped: root.clockRequested(true)

            onPullingChanged: if (clockSummon.pulling)
                root.clockPulled()

            onFinished: open => root.clockPullEnded(open)
        }

        Column {
            id: drawnTime

            anchors.centerIn: parent
            spacing: 0

            scale: clockSummon.pressed ? 0.96 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "HH")
                font.pixelSize: Appearance.font.size.normal
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                font.pixelSize: Appearance.font.size.normal
            }
        }
    }

    Item {
        width: 1
        height: Appearance.padding.normal
    }

    Item {
        id: dateSlot

        width: parent.width
        height: Math.max(Appearance.sizes.minTarget, drawn.implicitHeight)

        Pull {
            id: summon

            anchors.fill: parent

            dirX: 1
            dirY: 0

            angle: Appearance.sizes.pullAngleEdge

            travel: Math.max(1, root.pullSpan * Appearance.sizes.pullTravel)

            cursorShape: Qt.PointingHandCursor

            onTapped: root.calendarRequested(true)

            onPullingChanged: if (summon.pulling)
                root.calendarPulled()

            onFinished: open => root.calendarPullEnded(open)
        }

        Column {
            id: drawn

            anchors.centerIn: parent
            spacing: 0

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "d")
                font.pixelSize: Appearance.font.size.small
                color: summon.pressed ? Appearance.colour.text : Appearance.colour.textFaint

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
                font.pixelSize: Appearance.font.size.small
                color: summon.pressed ? Appearance.colour.text : Appearance.colour.textFaint

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
        }
    }
}
