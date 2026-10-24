import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property real band: 0
    property real railRight: 0
    property real railOpen: 0
    property bool sidebarShown: false
    property bool rail: false
    property bool islandOut: false
    property bool yielded: false

    readonly property string place: Config.values.sidebar.glance
    readonly property bool clockShown: Config.values.sidebar.clock.style !== "off"
    readonly property bool batteryShown: Battery.available && Config.values.sidebar.status.battery

    readonly property color levelColour: Battery.low ? Appearance.colour.alarm : Battery.charging ? Appearance.colour.accent : Appearance.colour.text

    readonly property bool restful: !root.yielded && (!root.sidebarShown || root.rail)

    readonly property bool topWanted: root.restful && !root.islandOut && root.clockShown && root.place === "top"
    readonly property bool tabsWanted: root.restful && root.sidebarShown && root.rail && root.place === "tabs"

    readonly property real hang: Appearance.font.line.normal + Appearance.padding.small
    readonly property real tabHeight: Appearance.font.line.normal + Appearance.padding.small
    readonly property real tabGap: Appearance.padding.small

    readonly property real tabsBottom: root.height - root.band - Appearance.sizes.sidebarFlare - Appearance.padding.large
    readonly property real batteryTabY: root.tabsBottom - root.tabHeight
    readonly property real timeTabY: root.batteryTabY - root.tabGap - root.tabHeight

    readonly property var blobs: [...root.topBlobs, ...root.tabBlobs]

    readonly property var topBlobs: top.value <= 0.01 ? [] : [
        {
            x: Math.round((root.width - pill.width) / 2),
            y: 0,
            w: pill.width,
            h: root.band + root.hang * top.value,
            radius: Math.min(root.hang / 2, (root.band + root.hang * top.value) / 2),
            smooth: Appearance.sizes.melt
        }
    ]

    readonly property var tabBlobs: tabs.value <= 0.01 ? [] : [
        ...(root.clockShown ? [root.tab(root.timeTabY, timeTab.implicitWidth)] : []),
        ...(root.batteryShown ? [root.tab(root.batteryTabY, batteryTab.implicitWidth)] : [])
    ]

    function tab(y: real, content: real): var {
        const full = root.band + content + Appearance.padding.normal * 2;
        return {
            x: 0,
            y: y,
            w: Math.max(root.railRight, root.railRight + (full - root.railRight) * tabs.value),
            h: root.tabHeight,
            radius: root.tabHeight / 2,
            smooth: Appearance.sizes.melt
        };
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    readonly property string time: `${TimeFormat.hourPart(clock.date)}:${Qt.formatDateTime(clock.date, "mm")}`

    Follow {
        id: top

        target: root.topWanted ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
    }

    Follow {
        id: tabs

        target: root.tabsWanted ? 1 - root.railOpen : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.005
    }

    component Reading: Row {
        spacing: Appearance.padding.small

        BatteryMeter {
            anchors.verticalCenter: parent.verticalCenter
            level: Battery.percentage
            charging: Battery.charging
            low: Battery.low
            colour: root.levelColour
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${Battery.percent}%`
            font.pixelSize: Appearance.font.size.small
            color: Battery.low ? Appearance.colour.alarm : Appearance.colour.textDim
        }
    }

    Item {
        id: pill

        readonly property bool withBattery: root.batteryShown

        x: Math.round((root.width - width) / 2)
        y: root.band + root.hang * (top.value - 1)
        width: Math.round(pillRow.implicitWidth + Appearance.padding.large * 2)
        height: root.hang
        opacity: top.value
        visible: top.value > 0.01

        Row {
            id: pillRow

            anchors.centerIn: parent
            spacing: Appearance.padding.large

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: root.time
                font.pixelSize: Appearance.font.size.normal
            }

            Reading {
                anchors.verticalCenter: parent.verticalCenter
                visible: pill.withBattery
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: tabs.value
        visible: tabs.value > 0.01

        StyledText {
            id: timeTab

            x: Math.round(root.band + Appearance.padding.normal)
            y: Math.round(root.timeTabY + (root.tabHeight - height) / 2)
            visible: root.clockShown
            text: root.time
            font.pixelSize: Appearance.font.size.normal
        }

        Reading {
            id: batteryTab

            x: timeTab.x
            y: Math.round(root.batteryTabY + (root.tabHeight - height) / 2)
            visible: root.batteryShown
        }
    }
}
