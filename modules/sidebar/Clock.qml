import QtQuick
import Quickshell
import qs.config
import qs.components

// Vertical clock for the sidebar: hours over minutes, date underneath.
//
// A narrow column can't hold "HH:MM:SS", so the time stacks. Both halves are the
// primary label so the two lines read as one block rather than as a value and a
// caption; the date drops to the tertiary tier and gets air above it.
//
// The date stacks for the same reason the time does, which it did not have to
// before. At the old 9px tier "2 AUG" fitted this 52px bar on one line; the
// small tier is 18px now, which puts those five characters at 60px and hangs
// them off both edges. Day over month is 36px at its widest and fits.
//
// THE DATE IS ALSO A CONTROL now: it opens the calendar menu, by a tap or by a
// pull out to the right, and deliberately NOT by hover. Hover is a cursor-only
// input, and it is also the wrong temperature for this panel: the gauges answer
// a passing pointer because they are glanceable state, but a calendar is a
// thing you go and consult, and a month grid arriving because the cursor
// crossed the date on its way to a gauge would be the shell interrupting rather
// than answering (DESIGN.md 2.2). The clock opens nothing itself: it says what
// happened and the sidebar forwards it to whoever owns the menu layer, the same
// division of labour the gauges keep.
Column {
    id: root

    property alias precision: clock.precision

    // What a full summoning pull measures against, handed down from the window
    // because a summon measures against the SURFACE (Pull's travel note: the
    // menu does not exist yet, so the screen is the only honest scale) and
    // nothing this deep in the sidebar can see the screen. Defaults to zero so
    // an unwired caller still runs: the travel below guards it, and Pull
    // floors its divisor at one pixel besides.
    property real pullSpan: 0

    // The sidebar titles the calendar's menu with the full date, and this is
    // where its date comes from: the clock already owns the one SystemClock in
    // the bar, and a second clock just to caption a menu would be a second
    // thing ticking.
    readonly property date now: clock.date

    // The opener the calendar panel is positioned beside, for the sidebar's
    // iconFor: the menu layer centres a panel on the icon that asked for it,
    // and for the calendar that icon is the date.
    readonly property Item dateItem: dateSlot

    // The calendar's three openers, mirrored by the sidebar and wired by the
    // window: a tap (flagged deliberate so a second tap on a pinned calendar
    // can close it, the way a gauge's does), a recognised pull, and the pull's
    // release.
    signal calendarRequested(bool deliberate)
    signal calendarPulled
    signal calendarPullEnded(bool open)

    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "HH")
        font.pixelSize: Appearance.font.size.normal
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDateTime(clock.date, "mm")
        font.pixelSize: Appearance.font.size.normal
    }

    Item {
        width: 1
        height: Appearance.padding.normal
    }

    // THE DATE'S SLOT: drawn exactly where it always was, answering over the
    // whole band. StatusIcon's lesson, applied the same way: the hit area is
    // not the drawing. The sidebar hands the clock the band's full width now,
    // this slot takes all of it and floors its height at the shell's minimum
    // target, and the drawn text stays a centred column inside, so nothing on
    // screen moves; only the region that answers grew.
    Item {
        id: dateSlot

        width: parent.width
        height: Math.max(Appearance.sizes.minTarget, drawn.implicitHeight)

        // The summoning pull, INSIDE the thing it is pulled from, which Pull's
        // header spends forty lines warning about, so the exemption is worth
        // stating: the rule is that the PARENT must hold still while the
        // gesture runs, and this parent does. A summon moves the MENU, and
        // the date is not the menu: it stays put while the panel comes out of
        // the bar, so the frame the press anchor lives in never shifts. The
        // menu layer's own push declares its Pull as a sibling precisely
        // because the panel it pushes is what its gesture moves; nothing of
        // the kind is true here, so the Pull may live where the date does.
        Pull {
            id: summon

            anchors.fill: parent

            // Out into the screen, the way the menu comes: the calendar hangs
            // off the bar's right flank, so summoning it is pulling it out of
            // the bar, rightward.
            dirX: 1
            dirY: 0

            // An edge's tolerance, not a corner's: the date sits against the
            // screen's left edge, so there are a hundred and eighty degrees
            // of "into the screen" and no neighbouring gesture running
            // through them here.
            angle: Appearance.sizes.pullAngleEdge

            // A SUMMON, so it measures against the surface rather than
            // against a panel that does not exist yet (Pull's travel note).
            // Guarded against an unwired pullSpan: a zero travel would make
            // every wobble read as a full pull, and Pull's own floor of one
            // pixel is a last resort rather than a contract.
            travel: Math.max(1, root.pullSpan * Appearance.sizes.pullTravel)

            // The control advertises itself the way every tappable thing in
            // the bar does.
            cursorShape: Qt.PointingHandCursor

            // NOT disarmed while the calendar is open, on purpose: the tap is
            // a TOGGLE at the other end (a deliberate tap on the date while
            // its menu is pinned closes it, mirroring the gauges), so the
            // press must keep being accepted while the menu is up. An unarmed
            // Pull would drop the very press that puts the panel away.

            // The tap. Deliberate by definition: there is no hover route to
            // the calendar for the flag to distinguish it from.
            onTapped: root.calendarRequested(true)

            // THE PULL OPENS ON RECOGNITION, not on release, and the fraction
            // is deliberately unread: like the notification tray's summon,
            // the menu has no honest partial reveal to track (it is not a
            // surface sliding out from under the date; it grows off the bar
            // on its own reveal), so the pull's whole job is to open the
            // thing the moment the gesture is recognised, and reversing
            // before release is the feedback: what you are deciding about is
            // a calendar you can already see. `pulling` flips true exactly
            // once per recognised pull, which is what makes this an event
            // rather than a stream of fractions pretending to be one.
            onPullingChanged: if (summon.pulling)
                root.calendarPulled()

            // Let go: momentum decides, which is Pull's own rule, and false
            // means the reversal was meant, so the menu goes back where it
            // came from.
            onFinished: open => root.calendarPullEnded(open)
        }

        // The drawn date, unchanged: a centred column, day over month, on the
        // quiet tier. The colour is the one thing that moves: it lifts to the
        // primary tier while the press is down, because a control that does
        // not answer the press reads as dead (DESIGN.md 2.3), and colour is
        // the only dimension this text has spare; size and position are both
        // spoken for by the bar's layout.
        Column {
            id: drawn

            anchors.centerIn: parent
            spacing: 0

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "d")
                font.pixelSize: Appearance.font.size.small
                color: summon.pressed ? Appearance.colour.text : Appearance.colour.textFaint

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "MMM").toUpperCase()
                font.pixelSize: Appearance.font.size.small
                color: summon.pressed ? Appearance.colour.text : Appearance.colour.textFaint

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }
        }
    }
}
