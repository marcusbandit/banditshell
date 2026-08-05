import QtQuick
import qs.config
import qs.modules.menu.content

// What the sidebar contains.
//
// No background of its own: the sidebar IS part of the chassis shape, drawn once
// by Chassis.qml. This is only the layout of what sits in that band.
//
// THREE QUESTIONS, in the three places a vertical band has. What is running
// (the tray, at the top), where you are (the workspaces, in the middle, because
// they are the thing the sidebar is mostly for), and how the machine is doing
// (the clock and the gauges, at the bottom).
//
// The groups get a quiet container so related controls read as one thing; the
// clock gets none, because it is the thing you actually look at.
Item {
    id: root

    // Forwarded up to the menu layer, which lives outside the sidebar because
    // the menus are not part of it. Both of these open menus, by the same keys
    // and through the same call, which is what `entryFor` below is for.
    property alias status: status
    property alias tray: tray

    // What a full summoning pull measures against, bound by whoever owns the
    // surface (the window can see the screen; this file cannot) and passed
    // straight down to the clock's date. Zero until wired, which is safe: the
    // Pull at the far end guards its own travel.
    property real pullSpan: 0

    signal requested(string key)
    signal released

    // THE CALENDAR'S OPENERS, forwarded from the clock the way the two groups'
    // requests are: the sidebar is the one thing the window talks to, so a
    // control this deep says what happened and this file repeats it upward.
    // `deliberate` mirrors the gauges' flag so the window can treat a tap on
    // the date exactly as it treats a tap on a gauge, which is what lets a
    // second tap on a pinned calendar close it.
    signal calendarRequested(bool deliberate)
    signal calendarPulled
    signal calendarPullEnded(bool open)

    // Every key that opens a menu, in the order they are down the bar: the
    // tray, then the clock's calendar, then the gauges. The CLI lists these
    // and opens by name, so the calendar is drivable from a terminal exactly
    // as a tray item or a gauge is.
    readonly property var menuItems: [...tray.items, root.calendarEntry, ...status.items]
    readonly property var menuKeys: root.menuItems.map(i => i.key)

    // The calendar's row, in the exact shape the tray and the gauges declare
    // theirs, so the menu layer and the CLI cannot tell it is not one of them.
    // The title is the full date rather than the word "calendar", because a
    // panel's first line should answer a question, and "what is today" is the
    // one a calendar is opened for (DESIGN.md 2.4: the same information, in a
    // fuller format, where there is room for it).
    readonly property var calendarEntry: ({
            key: "calendar",
            title: Qt.formatDateTime(clock.now, "dddd d MMMM"),
            body: calendarMenu
        })

    // WHICH GROUP OWNS A KEY, answered here so nothing above the sidebar has to
    // know there is more than one. Asked in the same order the bar is read in;
    // the calendar answers between the two groups because that is where the
    // clock sits, and it is a straight comparison rather than a search because
    // the clock is one control, not a list of them.
    function entryFor(key: string): var {
        return tray.entryFor(key) ?? (key === "calendar" ? root.calendarEntry : null) ?? status.entryFor(key);
    }

    function iconFor(key: string): Item {
        return tray.iconFor(key) ?? (key === "calendar" ? clock.dateItem : null) ?? status.iconFor(key);
    }

    // FULL WIDTH, like the workspaces below and for a related reason: a group in
    // here draws a 28px column but is aimed at across the whole 62px band, and a
    // target can only be as wide as the thing that was given the width. Centred,
    // each group answered over less than half the bar and left seventeen dead
    // pixels either side of every icon, on a surface that is nothing but icons.
    // The groups centre their own drawing (see TrayIcons), so nothing moves.
    TrayIcons {
        id: tray

        anchors.top: parent.top
        anchors.topMargin: Appearance.padding.normal
        anchors.left: parent.left
        anchors.right: parent.right

        onRequested: key => root.requested(key)
        onReleased: root.released()
    }

    // Full width, unlike everything else in here: the workspace ruler is drawn
    // ON the screen's edge and reaches in from it, so it needs the whole band to
    // measure from rather than a centred column.
    Workspaces {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }

    // FULL WIDTH for the same reason the tray is, and the width is passed
    // straight through to the gauges rather than stopping here: a Column is as
    // wide as its widest child unless told otherwise, so a centred one would
    // have been the clock's width, which is neither the band nor a slot and
    // whichever it happened to be would decide how far a gauge answered.
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.normal
        anchors.left: parent.left
        anchors.right: parent.right

        spacing: Appearance.padding.large

        // FULL WIDTH now, where it used to centre itself: the date became a
        // control aimed at across the whole band, and a target can only be as
        // wide as the thing that was given the width (StatusIcon's lesson,
        // again). The clock centres its own drawing, so nothing on screen
        // moves; only how much of the band answers a press did.
        Clock {
            id: clock

            anchors.left: parent.left
            anchors.right: parent.right

            pullSpan: root.pullSpan

            onCalendarRequested: deliberate => root.calendarRequested(deliberate)
            onCalendarPulled: root.calendarPulled()
            onCalendarPullEnded: open => root.calendarPullEnded(open)
        }

        StatusIcons {
            id: status

            anchors.left: parent.left
            anchors.right: parent.right

            onRequested: key => root.requested(key)
            onReleased: root.released()
        }
    }

    // The calendar's body, declared here rather than in either group because
    // the entry that names it is this file's own: the clock is one control
    // with one menu, not a group with a list. The menu layer is handed the
    // Component and never looks inside, the same contract every gauge menu
    // satisfies from StatusIcons.
    Component {
        id: calendarMenu

        CalendarMenu {}
    }
}
