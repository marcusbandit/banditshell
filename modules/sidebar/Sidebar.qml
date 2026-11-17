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

    property bool menuOpen: false

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
    property string openKey: ""

    readonly property bool rail: Appearance.sizes.sidebarRail
    readonly property real revealed: root.rail ? Math.max(0, Math.min(1, (root.expansion - 0.3) / 0.5)) : 1
    readonly property real railRestWidth: root.fullWidth - Appearance.sizes.sidebarWidth + Appearance.sizes.railWidth

    property bool dwelt: false
    property bool touched: false
    readonly property bool touchOpen: root.rail && root.touched
    property bool pressedAtRest: false
    readonly property bool holding: root.menusShown && root.menuKeys.indexOf(root.openKey) >= 0
    readonly property bool railWanted: root.rail && (root.dwelt || root.holding || root.touched)

    onRailChanged: if (!root.rail)
        root.touched = false

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

    signal markPressed(var opens)
    signal menuAsked(real x, real y, var actions)

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

    readonly property var blobs: root.expansion < 0.98 || !workspaces.visible ? [] : workspaces.blobs.map(b => ({
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

            readonly property bool holdsRest: anomalies.pointing || pips.pressing
            readonly property int slotsReserved: 4
            readonly property var place: Placement.rail(pips.implicitHeight, rest.height, glance.headEdge + Appearance.padding.large, rest.height - anomalies.anchors.bottomMargin, (Appearance.sizes.statusSlot + Appearance.sizes.statusGap) * rest.slotsReserved, Appearance.padding.huge)

            RailPips {
                id: pips

                anchors.left: parent.left
                anchors.right: parent.right
                y: rest.place.y
                height: pips.implicitHeight

                screen: root.screen

                onHeld: root.pressedAtRest = true
            }

            RailGlance {
                id: glance

                anchors.fill: parent

                topInset: root.endMargin(root.tray) + Appearance.padding.large
                bottomInset: root.endMargin(root.status) + Appearance.padding.large
                tabsReach: root.glanceReach
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

                onMarkPressed: opens => {
                    root.pressedAtRest = true;
                    root.markPressed(opens);
                }
            }
        }
    }

    HoverHandler {
        id: pointer

        onHoveredChanged: {
            if (!pointer.hovered)
                root.pressedAtRest = false;
            else
                root.touched = false;
        }
    }

    TapHandler {
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        enabled: root.rail && !root.touched
        onTapped: root.touched = true
    }

    function menuActions(): var {
        const rail = root.rail;
        return [
            {
                icon: "side_navigation",
                label: "Sidebar settings",
                run: () => root.markPressed({
                        settings: "sidebar"
                    })
            },
            {
                icon: rail ? "left_panel_open" : "left_panel_close",
                label: rail ? "Keep the sidebar open" : "Fold the sidebar",
                run: () => {
                    root.dwelt = false;
                    root.pressedAtRest = pointer.hovered;
                    Config.set("sidebar.style", rail ? "full" : "rail");
                }
            }
        ];
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.RightButton
        onPressed: mouse => root.menuAsked(mouse.x, mouse.y, root.menuActions())
    }

    DragHandler {
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        enabled: root.rail && !root.touched
        target: null
        yAxis.enabled: false
        onTranslationChanged: if (active && translation.x > 0)
            root.touched = true
    }

    Timer {
        interval: Appearance.animation.dwell
        running: root.rail && pointer.hovered && !root.dwelt && !root.pressedAtRest && !root.menuOpen && !(resting.item?.holdsRest ?? false)
        onTriggered: root.dwelt = true
    }

    Timer {
        interval: Appearance.animation.grace
        running: !pointer.hovered && root.dwelt && !root.menuOpen
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
