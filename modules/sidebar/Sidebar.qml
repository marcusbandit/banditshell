import QtQuick
import Quickshell
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
    // surface (the window knows its own size; this file cannot) and passed
    // straight down to the clock's date. Zero until wired, which is safe: the
    // Pull at the far end guards its own travel.
    property real pullSpan: 0

    // WHICH DISPLAY THIS SIDEBAR IS ON, by output name.
    //
    // There is one of these per screen and always has been, so this is not new
    // information, only newly asked for: the workspace column underneath needs
    // it to know which run of workspaces it is drawing (see
    // modules/sidebar/WorkspaceModel.qml), and every other question in here
    // happens to be one whose answer is the same on every monitor.
    //
    // ASKED OF THE SURFACE ITSELF rather than handed down like `pullSpan`
    // above, and the difference is what kind of fact it is. The diagonal is a
    // measurement, and only the window has the numbers; the screen is the
    // window's IDENTITY, and Quickshell attaches that to every item inside it
    // (modules/SettingsCorner.qml asks the same question the same way, for the
    // same reason). Nothing above has to remember to pass it, and it cannot be
    // passed wrong.
    //
    // Empty for the frame before the item is in a window, which the column
    // survives: an unknown screen draws the first band, which is what every
    // sidebar drew before there were bands.
    readonly property string screen: QsWindow.window?.screen?.name ?? ""

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

    // AND THE CLOCK PANEL'S, from the other half of the same control. Three
    // more signals rather than a key threaded through the calendar's: the
    // window names the thing that happened in each handler (that is why it
    // repeats the two-line toggle per opener instead of sharing it), so a key
    // parameter would only move the switch statement up a level.
    signal clockRequested(bool deliberate)
    signal clockPulled
    signal clockPullEnded(bool open)

    // Every key that opens a menu, in the order they are down the bar: the
    // tray, then the clock's own two panels, then the gauges. The CLI lists
    // these and opens by name, so both are drivable from a terminal exactly as
    // a tray item or a gauge is.
    //
    // The clock comes before the calendar because the TIME is drawn above the
    // DATE, and this list is the bar read top to bottom.
    readonly property var menuItems: [...tray.items, root.clockEntry, root.calendarEntry, ...status.items]
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

    // The clock panel's row, in the same shape. Its title is WHERE YOU ARE,
    // because the panel's first block is the local time and every other block
    // is measured against it: "Copenhagen" says which clock the big numerals
    // belong to, which is the one thing the numerals themselves cannot. Falls
    // back to the panel's own name for the moment before the service has asked
    // the system for its zone, since a menu arrives before its services answer
    // (MenuPanel's rule) and a blank heading is not an answer.
    readonly property var clockEntry: ({
            key: "clock",
            title: clock.localCity || "clock",
            body: clockMenu
        })

    // WHICH GROUP OWNS A KEY, answered here so nothing above the sidebar has to
    // know there is more than one. Asked in the same order the bar is read in;
    // the clock's two keys answer between the two groups because that is where
    // the clock sits, and they are straight comparisons rather than a search
    // because the clock is one control, not a list of them.
    function entryFor(key: string): var {
        return tray.entryFor(key) ?? (key === "clock" ? root.clockEntry : key === "calendar" ? root.calendarEntry : null) ?? status.entryFor(key);
    }

    function iconFor(key: string): Item {
        return tray.iconFor(key) ?? (key === "clock" ? clock.timeItem : key === "calendar" ? clock.dateItem : null) ?? status.iconFor(key);
    }

    // HOW MUCH THE FLOOR HAS RISEN by the time it is `inset` in from the side of
    // the screen, because at the ends of this bar the floor is not the screen's
    // straight edge but the curve rounding its corner off.
    //
    // A group standing `inset` from the sides and the same `inset` from the
    // bottom is NOT evenly spaced, and the arithmetic that says it is measures
    // the one direction where the shell's edge is straight. Down at the corner
    // the edge is coming in diagonally: at 10.5 in from the side the curve has
    // already climbed 6.4px, so a box with its bottom 10.5 from the display had
    // 7.8px of material at its bottom-left corner against 10.5 everywhere else,
    // and read as pinched into the corner - which is what it was.
    //
    // The curve is the superellipse the whole shell is drawn with, at the reach
    // the display's own corners are rounded at (see toScreen in blob.frag), so
    // this is that curve solved for y rather than a fitted number: at x = inset,
    // |reach - inset|^n + |reach - rise|^n = reach^n.
    function cornerRise(inset: real): real {
        const reach = Appearance.sizes.windowRadius + Appearance.sizes.gap + Appearance.sizes.band;
        const n = Math.max(2, Appearance.rounding.power);
        if (inset >= reach)
            return 0;
        return reach - Math.pow(Math.pow(reach, n) - Math.pow(reach - inset, n), 1 / n);
    }

    // WHERE A GROUP'S END GOES, given how far its drawn box sits in from the
    // bar's sides. The same air on every side of the box: the side gap, plus
    // whatever the corner has taken out from under it, less the band this whole
    // item is already held off the screen by, plus the overhang the fill has
    // past the column it is pinned to.
    function endMargin(group: Item): real {
        return group.sideGap + root.cornerRise(group.sideGap) + group.overhang - Appearance.sizes.band;
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
        // The air over the tray is the air beside it, corner included; see
        // endMargin above.
        anchors.topMargin: root.endMargin(tray)
        anchors.left: parent.left
        anchors.right: parent.right

        onRequested: key => root.requested(key)
        onReleased: root.released()
    }

    // Full width, unlike everything else in here: the workspace ruler is drawn
    // ON the screen's edge and reaches in from it, so it needs the whole band to
    // measure from rather than a centred column.
    Workspaces {
        id: workspaces

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        screen: root.screen
    }

    // WHAT THE BAR WANTS THE SHELL TO GROW, in this item's coordinates, for the
    // window to hand to the chassis. Today it is the workspace column's count
    // tags, which hang past the band's inner edge and need the body to come with
    // them; anything else in here that leaves the bar joins this list.
    //
    // Offset here rather than at either end, because this is the only file that
    // knows where the column ended up: it is centred in the bar, so its y is a
    // number nothing above or below it can work out.
    readonly property var blobs: workspaces.blobs.map(b => ({
                x: b.x + workspaces.x,
                y: b.y + workspaces.y,
                w: b.w,
                h: b.h,
                radius: b.radius,
                smooth: b.smooth
            }))

    // FULL WIDTH for the same reason the tray is, and the width is passed
    // straight through to the gauges rather than stopping here: a Column is as
    // wide as its widest child unless told otherwise, so a centred one would
    // have been the clock's width, which is neither the band nor a slot and
    // whichever it happened to be would decide how far a gauge answered.
    Column {
        anchors.bottom: parent.bottom

        // THE AIR UNDER THE GAUGES IS THE AIR BESIDE THEM, and neither number
        // is chosen: see endMargin and cornerRise above. The group is a box
        // floating in the bar, and a box with different clearances on two sides
        // reads as having slipped rather than as having been placed.
        //
        // The corner term is the whole of what is easy to get wrong here. Equal
        // MARGINS at a rounded corner are not equal AIR: the shell's edge stops
        // being the screen's straight edge somewhere in the last 52px and comes
        // in diagonally, so a box set the side gap off the display's bottom got
        // three quarters of that gap at its own bottom-left corner and looked
        // wedged into it.
        anchors.bottomMargin: root.endMargin(status)
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

    // The clock panel's body, declared beside the calendar's and for the same
    // reason: the entry that names it is this file's own.
    Component {
        id: clockMenu

        ClockMenu {}
    }
}
