import QtQuick
import Quickshell
import qs.config
import qs.components
// QUALIFIED, and it has to be. The clock service is a singleton called `Clock`
// and this file IS the type called `Clock` in its own directory's implicit
// import, so an unqualified `import qs.services` would put two things called
// Clock in one scope and leave which one an expression means up to import
// resolution order. Naming the module removes the question outright rather than
// betting on the answer.
import qs.services as Services

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
// BOTH HALVES ARE CONTROLS now, and they open different menus: the date opens
// the calendar and answers "which day", the time opens the clock panel and
// answers "what time, here and elsewhere, and what is going to happen later".
// One object with two faces, rather than two controls that happen to be stacked.
//
// Each opens by a tap or by a pull out to the right, and deliberately NOT by
// hover. Hover is a cursor-only input, and it is also the wrong temperature for
// this panel: the gauges answer a passing pointer because they are glanceable
// state, but a calendar is a thing you go and consult, and a month grid arriving
// because the cursor crossed the date on its way to a gauge would be the shell
// interrupting rather than answering (DESIGN.md 2.2). The same is true of a
// panel holding live countdowns.
//
// The clock opens nothing itself: it says what happened and the sidebar forwards
// it to whoever owns the menu layer, the same division of labour the gauges
// keep. The two summons are written out twice rather than shared through a
// helper, which is the arrangement ShellWindow already keeps for the same pair
// of gestures: each states its whole meaning where it fires.
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

    // WHERE THIS MACHINE IS, which titles the clock's menu the way `now` titles
    // the calendar's. Read here rather than in the sidebar for the reason `now`
    // is: the clock owns the facts about time in this bar, and the sidebar reads
    // them off the one instance instead of importing a second source.
    //
    // Empty until the service has asked the system for its zone, so the caller
    // needs a fallback; a heading is one line of a panel that arrives before its
    // services answer (MenuPanel's rule), not a thing to wait for.
    readonly property string localCity: Services.Clock.localCity

    // The opener the calendar panel is positioned beside, for the sidebar's
    // iconFor: the menu layer centres a panel on the icon that asked for it,
    // and for the calendar that icon is the date.
    readonly property Item dateItem: dateSlot

    // And the clock panel's, which is the time. The same contract, one line up
    // the bar.
    readonly property Item timeItem: timeSlot

    // The calendar's three openers, mirrored by the sidebar and wired by the
    // window: a tap (flagged deliberate so a second tap on a pinned calendar
    // can close it, the way a gauge's does), a recognised pull, and the pull's
    // release.
    signal calendarRequested(bool deliberate)
    signal calendarPulled
    signal calendarPullEnded(bool open)

    // The clock panel's three, in the same shape and for the same reasons. A
    // separate set rather than one signal carrying a key: the two halves of this
    // control are two different controls that happen to be adjacent, and a key
    // parameter would make the window switch on a string where it can simply
    // name the thing that happened.
    signal clockRequested(bool deliberate)
    signal clockPulled
    signal clockPullEnded(bool open)

    spacing: 0

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // THE TIME'S SLOT, built exactly as the date's below and for the same
    // reason: the hit area is not the drawing. The two numerals stay a centred
    // column of the width they always were, and the region that answers a press
    // is the whole band.
    Item {
        id: timeSlot

        width: parent.width
        height: Math.max(Appearance.sizes.minTarget, drawnTime.implicitHeight)

        // The summoning pull, INSIDE the thing it is pulled from, which is the
        // exemption the date's slot writes out in full: the rule Pull's header
        // states is that the PARENT must hold still while the gesture runs, and
        // this parent does. A summon moves the MENU, and the time is not the
        // menu; it stays exactly where it is while the panel comes out of the
        // bar, so the frame the press anchor lives in never shifts.
        Pull {
            id: clockSummon

            anchors.fill: parent

            // Out into the screen, the way the menu comes.
            dirX: 1
            dirY: 0

            // An edge's tolerance, not a corner's: this sits against the
            // screen's left edge, so there are a hundred and eighty degrees of
            // "into the screen" and no neighbouring gesture running through
            // them. The date's pull is the nearest thing, and it is a different
            // slot rather than a competing direction in this one.
            angle: Appearance.sizes.pullAngleEdge

            // A SUMMON, so it measures against the surface rather than against a
            // panel that does not exist yet (Pull's travel note), and it is
            // guarded against an unwired pullSpan the same way the date's is.
            travel: Math.max(1, root.pullSpan * Appearance.sizes.pullTravel)

            cursorShape: Qt.PointingHandCursor

            // NOT disarmed while the menu is open, for the date's reason: the
            // tap is a TOGGLE at the other end, so the press has to keep being
            // accepted while the panel is up.

            // Deliberate by definition: there is no hover route to this menu for
            // the flag to distinguish a tap from.
            onTapped: root.clockRequested(true)

            // OPENS ON RECOGNITION rather than on release, and the fraction is
            // deliberately unread: the menu has no honest partial reveal to
            // track, so the pull's whole job is to open the thing the moment the
            // gesture reads as one, and reversing before the release is decided
            // about a panel you can already see.
            onPullingChanged: if (clockSummon.pulling)
                root.clockPulled()

            onFinished: open => root.clockPullEnded(open)
        }

        // The drawn time: the same centred column at the same tier and the same
        // colour it has always had, so nothing on screen moved when it became a
        // control. Only the region that answers a press grew.
        //
        // IT ANSWERS THE PRESS BY MOVING, not by lifting its colour, and that is
        // the one place this slot cannot copy the date's. A control that does not
        // answer the press reads as dead (DESIGN.md 2.3), and the date has room
        // to answer in colour precisely because it sits on the tertiary tier with
        // somewhere brighter to go. The time is the PRIMARY label of this bar
        // (see the class comment: both halves are the thing you actually look
        // at), so there is no brighter tier above it and `pressed ? text : text`
        // would be a binding that does nothing.
        //
        // The rejected alternative was to drop the time to `textDim` at rest so
        // that it, too, had somewhere to lift from. That buys a colour animation
        // by dimming the one thing in the sidebar the sidebar is mostly looked at
        // for, which is trading the shell's resting hierarchy for a press effect.
        // A press that MOVES the thing is the shell's other way of saying the
        // same thing (components/Pill.qml: "a button is the one place someone is
        // certain they did something"), it is already in the vocabulary, and it
        // costs the resting bar nothing at all.
        Column {
            id: drawnTime

            anchors.centerIn: parent
            spacing: 0

            // Pill's own figure, copied rather than picked, so a press feels the
            // same amount everywhere in the shell.
            scale: clockSummon.pressed ? 0.96 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
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
        }
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
