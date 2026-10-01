import QtQuick
import Quickshell
import qs.config
import qs.services as Services

import qs.modules.menu.content

Item {
    id: root

    property alias status: status
    property alias tray: tray

    property bool menusShown: false

    property real pullSpan: 0

    readonly property string screen: QsWindow.window?.screen?.name ?? ""

    signal requested(string key)
    signal released

    signal calendarRequested(bool deliberate)
    signal calendarPulled
    signal calendarPullEnded(bool open)

    signal clockRequested(bool deliberate)
    signal clockPulled
    signal clockPullEnded(bool open)

    signal updateRequested(bool deliberate)

    readonly property var menuItems: [...tray.items, root.updateEntry, root.clockEntry, root.calendarEntry, ...status.items]
    readonly property var menuKeys: root.menuItems.map(i => i.key)

    readonly property var calendarEntry: ({
            key: "calendar",
            title: Qt.formatDateTime(clock.now, "dddd d MMMM"),
            body: calendarMenu
        })

    readonly property var clockEntry: ({
            key: "clock",
            title: clock.localCity || "clock",
            body: clockMenu
        })

    readonly property var updateEntry: ({
            key: "update",
            title: "update · " + Services.Update.branch,
            heading: "",
            body: updateMenu
        })

    function entryFor(key: string): var {
        return tray.entryFor(key) ?? (key === "update" ? root.updateEntry : key === "clock" ? root.clockEntry : key === "calendar" ? root.calendarEntry : null) ?? status.entryFor(key);
    }

    function iconFor(key: string): Item {
        return tray.iconFor(key) ?? (key === "update" ? update : key === "clock" ? clock.timeItem : key === "calendar" ? clock.dateItem : null) ?? status.iconFor(key);
    }

    function cornerRise(inset: real): real {
        const reach = Appearance.sizes.windowRadius + Appearance.sizes.gap + Appearance.sizes.band;
        const n = Math.max(2, Appearance.rounding.power);
        if (inset >= reach)
            return 0;
        return reach - Math.pow(Math.pow(reach, n) - Math.pow(reach - inset, n), 1 / n);
    }

    function endMargin(group: Item): real {
        return group.sideGap + root.cornerRise(group.sideGap) + group.overhang - Appearance.sizes.band;
    }

    TrayIcons {
        id: tray

        anchors.top: parent.top

        anchors.topMargin: root.endMargin(tray)
        anchors.left: parent.left
        anchors.right: parent.right

        onRequested: key => root.requested(key)
        onReleased: root.released()
        menusShown: root.menusShown
    }

    Workspaces {
        id: workspaces

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        screen: root.screen
    }

    readonly property var blobs: workspaces.blobs.map(b => ({
                x: b.x + workspaces.x,
                y: b.y + workspaces.y,
                w: b.w,
                h: b.h,
                radius: b.radius,
                smooth: b.smooth
            }))

    Column {
        anchors.bottom: parent.bottom

        anchors.bottomMargin: root.endMargin(status)
        anchors.left: parent.left
        anchors.right: parent.right

        spacing: Appearance.padding.large

        UpdateIndicator {
            id: update

            anchors.left: parent.left
            anchors.right: parent.right

            onRequested: deliberate => root.updateRequested(deliberate)
        }

        SidebarClock {
            id: clock

            anchors.left: parent.left
            anchors.right: parent.right

            pullSpan: root.pullSpan

            onCalendarRequested: deliberate => root.calendarRequested(deliberate)
            onCalendarPulled: root.calendarPulled()
            onCalendarPullEnded: open => root.calendarPullEnded(open)

            onClockRequested: deliberate => root.clockRequested(deliberate)
            onClockPulled: root.clockPulled()
            onClockPullEnded: open => root.clockPullEnded(open)
        }

        StatusIcons {
            id: status

            anchors.left: parent.left
            anchors.right: parent.right

            onRequested: key => root.requested(key)
            onReleased: root.released()
            menusShown: root.menusShown
        }
    }

    Component {
        id: calendarMenu

        CalendarMenu {}
    }

    Component {
        id: clockMenu

        ClockMenu {}
    }

    Component {
        id: updateMenu

        UpdateMenu {}
    }
}
