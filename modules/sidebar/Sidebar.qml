import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services as Services

import qs.modules.menu.content

Item {
    id: root

    property alias status: status
    property alias tray: tray

    property bool menusShown: false

    property real pullSpan: 0

    property string modeIcon: ""

    readonly property string slotIcon: root.modeIcon || (Services.Notifications.quieted ? "do_not_disturb_on" : "")

    property real fullWidth: width
    property real expansion: 1
    property string openKey: ""

    readonly property bool rail: Appearance.sizes.sidebarRail
    readonly property real revealed: root.rail ? Math.max(0, Math.min(1, (root.expansion - 0.3) / 0.5)) : 1
    readonly property real railRestWidth: root.fullWidth - Appearance.sizes.sidebarWidth + Appearance.sizes.railWidth

    property bool dwelt: false
    readonly property bool holding: root.menusShown && root.menuKeys.indexOf(root.openKey) >= 0
    readonly property bool railWanted: root.rail && (root.dwelt || root.holding)

    clip: root.rail && root.expansion < 1

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
            title: Services.TimeFormat.dateText(clock.now, "headline"),
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
        return tray.iconFor(key) ?? (key === "update" ? (update.visible ? update : clock.timeItem) : key === "clock" ? clock.timeItem : key === "calendar" ? clock.dateItem : null) ?? status.iconFor(key);
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

    readonly property var blobs: root.expansion < 0.98 ? [] : workspaces.blobs.map(b => ({
                x: b.x + workspaces.x,
                y: b.y + workspaces.y,
                w: b.w,
                h: b.h,
                radius: b.radius,
                smooth: b.smooth
            }))

    Item {
        id: body

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.fullWidth
        opacity: root.revealed
        visible: root.revealed > 0.01

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

            Item {
                id: mode

                anchors.left: parent.left
                anchors.right: parent.right
                height: Appearance.sizes.statusSlot
                visible: root.slotIcon !== ""

                Icon {
                    anchors.centerIn: parent
                    name: root.slotIcon || "radio_button_unchecked"
                    fill: 1
                    color: Appearance.colour.accent
                }
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
    }

    Loader {
        id: resting

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.railRestWidth
        opacity: 1 - root.revealed
        visible: opacity > 0.01
        active: root.rail

        sourceComponent: restingContent
    }

    Component {
        id: restingContent

        Item {
            RailPips {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                screen: root.screen
            }

            RailAnomalies {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.endMargin(root.status)

                modeIcon: root.modeIcon
            }
        }
    }

    HoverHandler {
        id: pointer
    }

    Timer {
        interval: Appearance.animation.dwell
        running: root.rail && pointer.hovered && !root.dwelt
        onTriggered: root.dwelt = true
    }

    Timer {
        interval: Appearance.animation.grace
        running: !pointer.hovered && root.dwelt
        onTriggered: root.dwelt = false
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
