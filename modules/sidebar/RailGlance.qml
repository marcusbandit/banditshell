import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property real topInset: 0
    property real bottomInset: 0
    property real tabsReach: 0

    readonly property string place: Config.values.sidebar.glance
    readonly property bool inRail: root.place === "rail" || root.place === "rail top"
    readonly property bool atHead: root.place === "rail top"
    readonly property bool clockShown: Config.values.sidebar.clock.style !== "off"
    readonly property bool oneLine: Config.values.sidebar.clock.style === "one line"

    readonly property BatteryGlance battery: BatteryGlance {}

    readonly property bool footInUse: (stack.visible && !root.atHead) || wide.visible || root.tabsReach > 0
    readonly property real topEdge: stack.visible && !root.atHead ? stack.y : wide.visible ? wide.y : root.height - root.tabsReach

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Follow {
        id: level

        target: Math.max(0, Math.min(1, root.battery.level))
        speed: Appearance.animation.trackSpeed
        epsilon: 0.001
    }

    Column {
        id: stack

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.atHead ? root.topInset : root.height - root.bottomInset - height)
        spacing: Appearance.padding.large
        visible: root.inRail && (root.clockShown || root.battery.shown)

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
                text: TimeFormat.minutePart(clock.date)
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
                text: TimeFormat.time(clock.date, false)
                font.pixelSize: Appearance.font.size.small
                rotation: -90
            }
        }

        Column {
            id: cell

            readonly property real barWidth: Math.max(4, Math.round(Appearance.sizes.railWidth * 0.36))

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.padding.small / 2
            visible: root.battery.shown

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
                color: root.battery.low ? Appearance.withAlpha(Appearance.colour.alarm, 0.3) : Appearance.colour.fillStronger

                SquircleRect {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: Math.max(gauge.width, gauge.height * level.value)
                    pill: "object"
                    color: root.battery.colour
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.battery.percent
                font.pixelSize: Appearance.font.size.small
                color: root.battery.labelColour
            }
        }
    }

    Column {
        id: wide

        x: Math.round((root.width - width) / 2)
        y: Math.round(root.height - root.bottomInset - height)
        spacing: Appearance.padding.normal
        visible: root.place === "wide" && (root.clockShown || root.battery.shown)

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
                text: TimeFormat.minutePart(clock.date)
                font.pixelSize: Appearance.font.size.normal
            }
        }

        BatteryReading {
            anchors.horizontalCenter: parent.horizontalCenter
            stacked: true
        }
    }
}
