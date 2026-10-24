import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property real topInset: 0
    property real bottomInset: 0

    readonly property string place: Config.values.sidebar.glance
    readonly property bool inRail: root.place === "rail" || root.place === "rail top"
    readonly property bool atHead: root.place === "rail top"
    readonly property bool clockShown: Config.values.sidebar.clock.style !== "off"
    readonly property bool oneLine: Config.values.sidebar.clock.style === "one line"
    readonly property bool batteryShown: Battery.available && Config.values.sidebar.status.battery

    readonly property color levelColour: Battery.low ? Appearance.colour.alarm : Battery.charging ? Appearance.colour.accent : Appearance.colour.text

    readonly property real topEdge: root.inRail && !root.atHead ? stack.y : wide.visible ? wide.y : root.height - root.bottomInset

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Follow {
        id: level

        target: Math.max(0, Math.min(1, Battery.percentage))
        speed: Appearance.animation.trackSpeed
        epsilon: 0.001
    }

    Column {
        id: stack

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.atHead ? root.topInset : root.height - root.bottomInset - height)
        spacing: Appearance.padding.large
        visible: root.inRail && (root.clockShown || root.batteryShown)

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            visible: root.clockShown && !root.oneLine

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: TimeFormat.hourPart(clock.date)
                font.pixelSize: Appearance.font.size.small
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                font.pixelSize: Appearance.font.size.small
            }
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: sideways.implicitHeight
            height: sideways.implicitWidth
            visible: root.clockShown && root.oneLine

            StyledText {
                id: sideways

                anchors.centerIn: parent
                text: `${TimeFormat.hourPart(clock.date)}:${Qt.formatDateTime(clock.date, "mm")}`
                font.pixelSize: Appearance.font.size.small
                rotation: -90
            }
        }

        Column {
            id: cell

            readonly property real barWidth: Math.max(4, Math.round(Appearance.sizes.railWidth * 0.36))

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.small / 2
            visible: root.batteryShown

            SquircleRect {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(2, Math.round(cell.barWidth / 2))
                height: Math.max(2, Math.round(cell.barWidth / 3))
                radius: 1
                color: gauge.color
            }

            SquircleRect {
                id: gauge

                anchors.horizontalCenter: parent.horizontalCenter
                width: cell.barWidth
                height: Appearance.font.line.normal * 4
                pill: "object"
                color: Battery.low ? Appearance.withAlpha(Appearance.colour.alarm, 0.3) : Appearance.colour.fillStronger

                SquircleRect {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(gauge.width, gauge.height * level.value)
                    pill: "object"
                    color: root.levelColour
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Battery.percent
                font.pixelSize: Appearance.font.size.small
                color: Battery.low ? Appearance.colour.alarm : Appearance.colour.textDim
            }
        }
    }

    Column {
        id: wide

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height - root.bottomInset - height)
        spacing: Appearance.padding.normal
        visible: root.place === "wide" && (root.clockShown || root.batteryShown)

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            visible: root.clockShown

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: TimeFormat.hourPart(clock.date)
                font.pixelSize: Appearance.font.size.normal
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "mm")
                font.pixelSize: Appearance.font.size.normal
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.small / 2
            height: Appearance.font.iconSize + Appearance.font.line.small

            BatteryMeter {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.batteryShown
                level: Battery.percentage
                charging: Battery.charging
                low: Battery.low
                colour: root.levelColour
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.batteryShown
                text: `${Battery.percent}%`
                font.pixelSize: Appearance.font.size.small
                color: Battery.low ? Appearance.colour.alarm : Appearance.colour.textDim
            }
        }
    }
}
