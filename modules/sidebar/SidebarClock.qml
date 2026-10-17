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

    readonly property string timeStyle: Config.values.sidebar.clock.style
    readonly property string dateStyle: Config.values.sidebar.clock.date

    readonly property bool timeShown: root.timeStyle !== "off"
    readonly property bool dateShown: root.dateStyle !== "off"

    signal calendarRequested(bool deliberate)
    signal calendarPulled
    signal calendarPullEnded(bool open)

    signal clockRequested(bool deliberate)
    signal clockPulled
    signal clockPullEnded(bool open)

    spacing: 0

    visible: root.timeShown || root.dateShown

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Item {
        id: timeSlot

        width: parent.width
        height: !root.timeShown ? 0 : Math.max(Appearance.sizes.minTarget, root.timeStyle === "one line" ? sideways.implicitWidth : drawnTime.implicitHeight)
        visible: root.timeShown

        Pull {
            id: clockSummon

            anchors.fill: parent

            dirX: 1
            dirY: 0

            angle: Config.values.control.pullAngleEdge

            travel: Math.max(1, root.pullSpan * Config.values.control.pullTravel)

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
            visible: root.timeStyle !== "one line"

            scale: timeScale.value

            StyledText {
                id: hourText

                anchors.horizontalCenter: parent.horizontalCenter
                text: Services.TimeFormat.hourPart(clock.date)
                font.pixelSize: root.timeStyle === "small" ? Appearance.font.size.small : Appearance.font.size.normal
            }

            StyledText {
                id: minuteText

                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                font.pixelSize: root.timeStyle === "small" ? Appearance.font.size.small : Appearance.font.size.normal
            }
        }

        StyledText {
            id: sideways

            anchors.centerIn: parent
            visible: root.timeStyle === "one line"

            text: `${hourText.text}:${minuteText.text}`
            font.pixelSize: Appearance.font.size.small
            rotation: -90

            scale: timeScale.value
        }

        Follow {
            id: timeScale

            target: clockSummon.pressed ? Appearance.press.plate : 1
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }
    }

    Item {
        width: 1
        height: Appearance.padding.normal
        visible: root.timeShown && root.dateShown
    }

    Item {
        id: dateSlot

        width: parent.width
        height: root.dateShown ? Math.max(Appearance.sizes.minTarget, drawn.implicitHeight) : 0
        visible: root.dateShown

        Pull {
            id: summon

            anchors.fill: parent

            dirX: 1
            dirY: 0

            angle: Config.values.control.pullAngleEdge

            travel: Math.max(1, root.pullSpan * Config.values.control.pullTravel)

            cursorShape: Qt.PointingHandCursor

            onTapped: root.calendarRequested(true)

            onPullingChanged: if (summon.pulling)
                root.calendarPulled()

            onFinished: open => root.calendarPullEnded(open)
        }

        FollowColour {
            id: dateTone

            target: summon.pressed ? Appearance.colour.text : Appearance.colour.textFaint
            speed: Appearance.animation.revealSpeed
        }

        Column {
            id: drawn

            anchors.centerIn: parent
            spacing: 0

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "d")
                font.pixelSize: Appearance.font.size.small
                color: dateTone.value
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.dateStyle !== "day"
                text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
                font.pixelSize: Appearance.font.size.small
                color: dateTone.value
            }
        }
    }
}
