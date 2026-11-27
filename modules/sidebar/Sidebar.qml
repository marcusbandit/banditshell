import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services as Services

import qs.modules.controls
import qs.modules.menu.content
import "anomalies.js" as Anomalies
import "placement.js" as Placement

Item {
    id: root

    property alias status: status
    property alias tray: tray

    property bool menusShown: false

    property real pullSpan: 0

    property string modeIcon: ""

    property string modeName: ""

    property bool awake: false

    property real glanceReach: 0

    readonly property var slotEntry: Anomalies.modeEntry({
        modeIcon: root.modeIcon,
        modeName: root.modeName,
        quiet: Services.Notifications.quieted
    })
    readonly property string slotIcon: root.slotEntry?.icon ?? ""

    property real fullWidth: width
    property real expansion: 1

    readonly property bool rail: Appearance.sizes.sidebarRail
    readonly property real revealed: root.rail ? Math.max(0, Math.min(1, (root.expansion - 0.3) / 0.5)) : 1
    readonly property real railRestWidth: root.fullWidth - Appearance.sizes.sidebarWidth + Appearance.sizes.railWidth

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

    signal agentLimitsRequested(bool deliberate)
    signal agentLimitsReleased

    signal markPressed(var opens)
    signal menuAsked(real x, real y, var actions)

    readonly property var menuItems: [...tray.items, root.updateEntry, root.agentLimitsEntry, root.clockEntry, root.calendarEntry, ...status.items]
    readonly property var menuKeys: root.menuItems.map(i => i.key)

    readonly property var agentLimitsEntry: ({
            key: "agentLimits",
            title: "AI limits",
            body: agentLimitsMenu
        })

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
        return tray.entryFor(key) ?? (key === "update" ? root.updateEntry : key === "agentLimits" ? root.agentLimitsEntry : key === "clock" ? root.clockEntry : key === "calendar" ? root.calendarEntry : null) ?? status.entryFor(key);
    }

    function iconFor(key: string): Item {
        if (root.rail)
            return resting.item?.anchorFor(key) ?? null;
        return tray.iconFor(key) ?? (key === "update" ? (update.visible ? update : clock.timeItem) : key === "agentLimits" ? (root.rail && root.revealed < 0.5 && resting.item?.limitsItem ? resting.item.limitsItem : agentLimits) : key === "clock" ? clock.timeItem : key === "calendar" ? clock.dateItem : null) ?? status.iconFor(key);
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

    readonly property var blobs: root.expansion < 0.98 || !(spaces.item?.workspaces.visible ?? false) ? [] : spaces.item.workspaces.blobs.map(b => ({
                x: b.x + spaces.item.workspaces.x,
                y: b.y + spaces.item.workspaces.y,
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

        Loader {
            id: spaces

            anchors.fill: parent
            active: !root.rail

            sourceComponent: Item {
                readonly property alias workspaces: workspaces

                Workspaces {
                    id: workspaces

                    readonly property real ceiling: tray.y + tray.height + tray.overhang + Appearance.padding.large
                    readonly property real floor: foot.y - Appearance.padding.large
                    readonly property var place: Placement.between(workspaces.implicitHeight, body.height, workspaces.ceiling, workspaces.floor)

                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: workspaces.place.y
                    height: workspaces.implicitHeight
                    visible: workspaces.place.fits

                    screen: root.screen
                }

                RailPips {
                    id: crowded

                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: Placement.between(crowded.implicitHeight, body.height, workspaces.ceiling, workspaces.floor).y
                    height: crowded.implicitHeight
                    visible: !workspaces.place.fits

                    screen: root.screen
                }
            }
        }

        Column {
            id: foot

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

            AgentLimitsGlance {
                id: agentLimits

                anchors.left: parent.left
                anchors.right: parent.right

                onRequested: deliberate => root.agentLimitsRequested(deliberate)
                onReleased: root.agentLimitsReleased()
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
                    color: Appearance.colour.text
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: mode.visible
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.markPressed(root.slotEntry.opens)

                    HoverTip {
                        text: mode.visible ? Anomalies.tip(root.slotEntry) : ""
                        host: mode
                    }
                }
            }

            StatusIcons {
                id: status

                anchors.left: parent.left
                anchors.right: parent.right

                onRequested: key => root.requested(key)
                onReleased: root.released()
                onMarkPressed: opens => root.markPressed(opens)
                menusShown: root.menusShown
                awake: root.awake
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
            id: rest

            readonly property Item limitsItem: railLimits
            readonly property int slotsReserved: 4
            readonly property real limitsFloor: railLimits.visible ? railLimits.y + railLimits.height : glance.headEdge
            readonly property var place: Placement.rail(pips.implicitHeight, rest.height, Math.max(glance.headEdge, rest.limitsFloor) + Appearance.padding.large, rest.height - anomalies.anchors.bottomMargin, (Appearance.sizes.statusSlot + Appearance.sizes.statusGap) * rest.slotsReserved, Appearance.padding.huge)

            function anchorFor(key: string): Item {
                if (key === "clock")
                    return glance.timeItem ?? railFoot;
                if (key === "calendar")
                    return glance.dateItem ?? glance.timeItem ?? railFoot;
                if (key === "agentLimits")
                    return railLimits.visible ? railLimits : railHead;
                return anomalies.markFor(key) ?? (root.tray.iconFor(key) ? railHead : railFoot);
            }

            Item {
                id: railHead

                anchors.left: parent.left
                anchors.right: parent.right
                y: root.endMargin(root.tray)
                height: Appearance.sizes.statusSlot
            }

            Item {
                id: railFoot

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.endMargin(root.status)
                height: Appearance.sizes.statusSlot
            }

            AgentLimitsGlance {
                id: railLimits

                rail: true
                anchors.left: parent.left
                anchors.right: parent.right
                y: Math.round(glance.headEdge > 0 ? glance.headEdge + Appearance.padding.normal : root.endMargin(root.tray))

                onRequested: deliberate => root.agentLimitsRequested(deliberate)
                onReleased: root.agentLimitsReleased()
            }

            RailPips {
                id: pips

                anchors.left: parent.left
                anchors.right: parent.right
                y: rest.place.y
                height: pips.implicitHeight

                screen: root.screen
            }

            RailGlance {
                id: glance

                anchors.fill: parent

                topInset: root.endMargin(root.tray) + Appearance.padding.large
                bottomInset: root.endMargin(root.status) + Appearance.padding.large
                tabsReach: root.glanceReach

                onClockRequested: deliberate => root.clockRequested(deliberate)
                onCalendarRequested: deliberate => root.calendarRequested(deliberate)
            }

            RailAnomalies {
                id: anomalies

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: glance.footInUse ? parent.height - glance.topEdge + Appearance.padding.large : root.endMargin(root.status)

                modeIcon: root.modeIcon
                modeName: root.modeName
                awake: root.awake
                room: rest.place.room
                batteryWanted: ["top", "off"].includes(Config.values.sidebar.glance)

                enabled: root.revealed === 0

                onMarkPressed: opens => root.markPressed(opens)
            }
        }
    }

    function menuActions(): var {
        return [
            {
                icon: "side_navigation",
                label: "Sidebar settings",
                run: () => root.markPressed({
                        settings: "sidebar"
                    })
            }
        ];
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.RightButton
        onPressed: mouse => root.menuAsked(mouse.x, mouse.y, root.menuActions())
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

    Component {
        id: agentLimitsMenu

        AgentLimitsMenu {}
    }
}
