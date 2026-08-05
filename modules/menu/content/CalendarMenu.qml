pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components

// A month, as a menu.
//
// The calendar is a BODY for the menu layer rather than a panel of its own, and
// that is most of the design. Menus.qml already owns everything hard about a
// panel's life: where it sits, the chassis melt, the pin, the catcher, the push
// back into the bar, Escape and the CLI. A calendar drawn anywhere else would
// have had to re-earn all of it, so the sidebar registers this under the key
// "calendar" instead, the clock's date is its opener, and this file is only
// about what a month looks like and how you move between months.
//
// NAVIGATION IS A DRAG, not a pair of chevron buttons, for the reason
// DESIGN.md 15 gives everything else in the shell: a drag is one continuous
// gesture, identical with a finger and a mouse, reversible right up until the
// release, and it shows what it is doing while it does it. The months are a
// horizontal strip, the shown month in the middle and a neighbour either side,
// the strip follows the finger, and the release decides by what is mostly on
// screen and which way the hand was still going. Chevrons would also have been
// two more permanent controls, which is the furniture this shell does not keep
// (DESIGN.md 2.1); the one button that remains is the title, because "take me
// back to today" from eight months away is a real errand with no gesture.
Column {
    id: root

    // A week across and six weeks down. Six ALWAYS, never the four or five a
    // particular month happens to span: the grid's height is the panel's
    // height, and a panel that travelled taller and shorter as you paged would
    // turn every month flick into a resize. Six is the most any month can need
    // (a 31-day month whose 1st is a Sunday), so the fixed count wastes at
    // most one dim row and buys a panel that holds still.
    readonly property int columns: 7
    readonly property int rows: 6

    // Cell geometry, derived, never listed: the columns split the panel's
    // width evenly and every position below is arithmetic on the index
    // (~/.claude/rules/math-over-hardcoding.md). The floor is the shell-wide
    // minimum hit size, which at the default menu width never binds (a seventh
    // of ~352px is ~50px); it is there so a narrowed menu degrades into cells
    // that are still hittable rather than cells that are still seven.
    readonly property real cell: Math.max(Appearance.sizes.minTarget, root.width / root.columns)

    // Today, from the system clock, so a calendar left open across midnight
    // moves its plate without being reopened. Minute precision: a calendar
    // needs the date, and a minute is the coarsest clock Quickshell offers.
    readonly property date today: clock.date

    // The month on show, as a year and a zero-based month. Seeded from the
    // wall clock at CREATION rather than bound to `today`: the menu is built
    // fresh at every open (MenuPanel's Loader unloads a closed body), so
    // creation time is opening time and the calendar always opens on the
    // current month, but a month you have paged to must not be yanked back to
    // today by the next minute tick, which is what a binding would do.
    property int shownYear: new Date().getFullYear()
    property int shownMonth: new Date().getMonth()

    // How far the strip of months is displaced, in pixels, positive when it
    // has been dragged toward the previous month. Written by the finger while
    // the drag runs and by `settle` afterwards, never by both at once; the
    // same arrangement as the notification tray's pushBack.
    property real slide: 0

    spacing: Appearance.padding.normal

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
        // Only ticking while the menu is actually on screen, for TopNotch's
        // reason: a clock bound to labels nobody can see still wakes the
        // render thread. The body is torn down when the menu closes anyway;
        // this covers the fade-out frames where it is loaded but hidden.
        enabled: root.visible
    }

    // Turn the view `delta` months and RE-CENTRE the strip under it. The panes
    // sit at (pane * width + slide), so adding delta * width to the slide at
    // the same moment every pane changes month keeps every pixel where it is:
    // the pane that was the neighbour IS the new middle, merely renamed.
    // Called from rest (a tap) it leaves the strip displaced a full pane the
    // other way, which is exactly the start of the animation a drag release
    // wants, so both routes settle through `glide`.
    function page(delta: int): void {
        const to = new Date(root.shownYear, root.shownMonth + delta, 1);
        root.shownYear = to.getFullYear();
        root.shownMonth = to.getMonth();
        root.slide += delta * months.width;
    }

    // Walk whatever displacement is left back to zero, by exponential
    // smoothing (components/Follow.qml), the shell's one way of settling
    // anything: fast while the neighbour is far, gentle as it lands.
    function glide(): void {
        settle.value = root.slide;
    }

    // Back to today's month, from the title. One month away it pages, so the
    // common case (peeked at next month, came back) gets the slide; further
    // away it CUTS, deliberately: the strip only holds the two neighbours, so
    // a slide home from eight months out would animate panes that never held
    // the months in between, a picture of a journey that did not happen. A
    // jump is at least honest about being one.
    function home(): void {
        // Months since the shown month, twelve to the year.
        const delta = (root.today.getFullYear() * 12 + root.today.getMonth()) - (root.shownYear * 12 + root.shownMonth);
        if (delta === 0)
            return;
        if (Math.abs(delta) === 1) {
            root.page(delta);
            root.glide();
            return;
        }
        root.shownYear = root.today.getFullYear();
        root.shownMonth = root.today.getMonth();
        root.slide = 0;
        settle.value = 0;
    }

    // A tap on the grid, resolved to the day it landed on by arithmetic: the
    // strip coordinate names the pane, the remainder names the column, and the
    // cell index plus the pane's own lead-in names the date. There is no
    // MouseArea in any cell, and that is a requirement rather than a saving:
    // the month drag must be startable ANYWHERE on the grid, and a grid tiled
    // with its own little press-takers would leave the drag only the seams. So
    // the pager owns every press, and a tap is its leftover, hit-tested with
    // three divisions.
    //
    // Only a day OUTSIDE the shown month answers, by navigating to its month:
    // dim is how the grid says "this one is next door", so tapping it is
    // asking to go next door, which makes the dim days a cheap, discoverable
    // second way to page. A tap on one of the shown month's own days does
    // nothing: a day is information here, not yet a control, and a dead press
    // on it costs nothing.
    function poke(x: real, y: real): void {
        // Above the grid is the initials strip, which the pager also owns
        // (see its topMargin), so a tap can arrive with a negative y. A
        // column has a name up there but no day, so the tap is spent on
        // nothing rather than clamped onto the top row, whose dim lead-in
        // days would page backward for a press that only missed the heading.
        if (y < 0)
            return;
        const strip = x - root.slide;
        const paneIx = Math.floor(strip / months.width);
        const col = Math.min(root.columns - 1, Math.floor((strip - paneIx * months.width) / root.cell));
        const row = Math.min(root.rows - 1, Math.floor(y / root.cell));
        const first = new Date(root.shownYear, root.shownMonth + paneIx, 1);
        const lead = (first.getDay() + 6) % 7;
        const day = new Date(first.getFullYear(), first.getMonth(), 1 - lead + row * root.columns + col);
        // Months from the shown month to the tapped day's, twelve to the year.
        const delta = (day.getFullYear() * 12 + day.getMonth()) - (root.shownYear * 12 + root.shownMonth);
        if (delta === 0)
            return;
        root.page(delta);
        root.glide();
    }

    // THE MONTH'S NAME, which is also the way home. Not hover-gated: it works
    // the same for a finger that has no hover to offer. Normal size and weight
    // carry it over the day numbers rather than a fourth size
    // (~/.claude/rules/type-scale.md), and the fill that answers the pointer
    // and the press is the same plate every menu row wears, so it reads as a
    // control in the one vocabulary the shell already speaks.
    Item {
        id: heading

        width: parent.width
        height: Math.max(Appearance.sizes.minTarget, monthName.implicitHeight)

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill
            // containsMouse covers both inputs: hover for a cursor, and the
            // synthesised hover a touch press carries, so the plate answers
            // the press too (DESIGN.md 2.3).
            opacity: homeTap.pressed || homeTap.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        MouseArea {
            id: homeTap

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.home()
        }

        StyledText {
            id: monthName

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            text: Qt.formatDate(new Date(root.shownYear, root.shownMonth, 1), "MMMM yyyy")
            font.pixelSize: Appearance.font.size.normal
            font.bold: true
        }
    }

    // The week's initials, Mondays first. Qt's locale numbers weekdays from
    // Monday as 1, so index plus one IS a Monday-first week and no seven-entry
    // table needs writing; the JS Dates below count from Sunday instead, which
    // is what the rotation in each pane's `lead` converts.
    Item {
        id: initials

        width: parent.width
        height: childrenRect.height

        Repeater {
            model: root.columns

            delegate: StyledText {
                required property int index

                x: index * root.cell
                width: root.cell
                horizontalAlignment: Text.AlignHCenter

                text: Qt.locale().dayName(index + 1, Locale.NarrowFormat).toUpperCase()
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
            }
        }
    }

    // The months themselves: a clipped viewport over a three-pane strip, which
    // is every month a one-page drag can reveal. The clip is load-bearing: the
    // neighbours are laid out a full pane off the viewport, and without it
    // they would draw straight across the rest of the panel. It lives one
    // wrapper IN from this Item rather than on it, because Qt's clip cuts
    // INPUT along with the paint and the pager below deliberately stands
    // taller than the grid's rectangle (see its topMargin); clipped here, its
    // reach above the grid would never hear a press at all.
    Item {
        id: months

        width: parent.width
        height: root.cell * root.rows

        // THE PAGER, first, so it sits under everything the panes draw and any
        // cell that ever grows input of its own will win its press
        // (declaration order is input order). Hand-rolled on a MouseArea like
        // every drag in this repo, because Qt's DragHandler assigns x
        // imperatively, which destroys the binding driving it (DESIGN.md 15).
        //
        // THE AREA ITSELF HOLDS STILL, which is the whole reason it is not on
        // the panes: the press-anchor invariant `area.x + mouse.x` survives
        // the AREA moving inside a still parent and not the reverse, and the
        // panes are exactly what this gesture moves. Measured on a pane it
        // would read its own effect back as pointer travel, the bug Pull's
        // header and the notification card both record. Here it is a sibling
        // of the panes wearing the viewport's rectangle, and the viewport does
        // not move while a menu is simply open. (The menu layer can slide the
        // whole PANEL while some other icon summons its menu, but that is a
        // different menu arriving, which ends this gesture anyway.)
        MouseArea {
            id: pager

            // The press anchor, in the parent's frame per the invariant
            // above, re-anchored at the moment the press becomes a page (see
            // below) so the threshold pixels are spent on deciding rather
            // than on a jump.
            property real fromX: 0
            property real fromY: 0
            property real startSlide: 0
            // Latched ONCE per press, like every gesture in the shell: a
            // press that set off vertically was never a page and must not
            // become one by curving round, and one that latched stays latched
            // however it wanders.
            property bool paging: false
            property bool spent: false
            // Smoothed with the same constant as Pull and the bottom edge,
            // because the last event before a release is noise as often as it
            // is direction.
            property real velocity: 0
            property real lastX: 0

            anchors.fill: parent
            // AND THE WEEKDAY INITIALS ABOVE, plus the Column's air on both
            // sides of them, right up to where the heading's own tap begins.
            // Those pixels used to belong to nobody: the initials are bare
            // texts, and the menu's body viewport is inert while its content
            // fits (MenuPanel's rule), so a press there fell through to the
            // push-back Pull behind the panel, and a leftward month-swipe
            // begun a finger's width above the grid latched the push at
            // pullSlack and CLOSED THE MENU where the same motion on the
            // grid paged it. The strip reads as part of the calendar, so the
            // calendar answers it. Not a separate press-swallowing area on
            // the initials row: that would keep the menu alive but answer
            // the swipe with nothing, a dead band across the middle of a
            // live gesture.
            anchors.topMargin: -(initials.height + root.spacing * 2)
            // Nothing in a menu flicks today, but the grab must survive
            // anything that ever does; the same line Pull takes.
            preventStealing: true
            // The gesture advertises itself (DESIGN.md 2.3): nothing drawn on
            // the grid says it slides, so the cursor does, the same way the
            // notification card's does.
            cursorShape: pager.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: mouse => {
                pager.fromX = pager.x + mouse.x;
                pager.fromY = pager.y + mouse.y;
                pager.lastX = pager.fromX;
                pager.startSlide = root.slide;
                pager.paging = false;
                pager.spent = false;
                pager.velocity = 0;
            }

            onPositionChanged: mouse => {
                if (!pager.pressed || pager.spent)
                    return;

                const px = pager.x + mouse.x;
                const dx = px - pager.fromX;
                const dy = pager.y + mouse.y - pager.fromY;

                const step = px - pager.lastX;
                pager.lastX = px;
                pager.velocity += (step - pager.velocity) * 0.4;

                if (!pager.paging) {
                    // Still inside the wobble of a tap: nothing is decided.
                    if (Math.abs(dx) < Appearance.sizes.dragThreshold && Math.abs(dy) < Appearance.sizes.dragThreshold)
                        return;

                    // WHICH AXIS WON, judged once, the moment the press
                    // becomes a gesture at all. Vertical wins and the press
                    // is spent: it is not a page, and it is no longer a tap
                    // either, so the release owes it nothing. There is no
                    // scroll under this grid for a vertical gesture to be
                    // handed on to; it is simply not this.
                    if (Math.abs(dy) > Math.abs(dx)) {
                        pager.spent = true;
                        return;
                    }

                    pager.paging = true;
                    // Re-anchored, so the page starts from where the finger
                    // is NOW rather than jumping the threshold's worth it
                    // spent proving itself. The slide is re-read too, because
                    // `settle` may have moved it since the press.
                    pager.fromX = px;
                    pager.startSlide = root.slide;
                    return;
                }

                // Content follows the finger, clamped to one pane: the strip
                // holds one neighbour each side, so travel past that would
                // drag blank canvas on screen.
                root.slide = Math.max(-months.width, Math.min(months.width, pager.startSlide + (px - pager.fromX)));
            }

            onReleased: {
                if (pager.paging) {
                    // WHICH MONTH WINS: the one that is mostly on screen, or
                    // the one the hand was still travelling toward fast
                    // enough to mean it; either is enough. Majority answers
                    // the slow, careful drag that stopped dead; the velocity
                    // answers the flick that meant "next" without covering
                    // half a pane, which is the launch edge's momentum rule:
                    // motion is a question about intent, position only about
                    // distance. The momentum term has to BEAT
                    // `flickVelocity`, not merely carry the onward sign,
                    // because a MouseArea only speaks while the pointer
                    // moves: the smoothed velocity never decays through a
                    // hold, so a drag that eased to a stop still reads as
                    // creeping onward, and a bare sign test paged every
                    // latched drag on release, leaving the majority rule
                    // nothing to decide. The threshold is the notification
                    // card's and the workspace scrub's `flickVelocity`
                    // rather than Pull's `pullReversal` because the question
                    // is theirs, "does this motion earn a page at all", not
                    // Pull's "was a committed gesture really taken back".
                    const half = Math.abs(root.slide) > months.width / 2;
                    const onward = root.slide * pager.velocity > 0 && Math.abs(pager.velocity) >= Appearance.sizes.flickVelocity;
                    if (half || onward)
                        root.page(root.slide > 0 ? -1 : 1);
                    root.glide();
                } else if (!pager.spent) {
                    root.poke(pager.fromX, pager.fromY);
                }
                pager.paging = false;
                pager.spent = false;
            }

            onCanceled: {
                if (pager.paging)
                    root.glide();
                pager.paging = false;
                pager.spent = false;
            }
        }

        // The panes' window: the clip lives here, one level in from
        // `months`, purely so the pager's reach above the grid stays
        // hearable (see the comments above). Paint-wise this crops
        // exactly the rectangle `months` used to crop.
        Item {
            id: viewport

            anchors.fill: parent
            clip: true

            Repeater {
                model: [-1, 0, 1]

                delegate: Item {
                    id: pane

                    required property int modelData

                    // The first of the month this pane shows. JS Date normalises
                    // month arithmetic (month twelve is January of next year), so
                    // the year rollover is nobody's branch.
                    readonly property date first: new Date(root.shownYear, root.shownMonth + pane.modelData, 1)

                    // How many cells of the previous month lead in before the
                    // 1st. Weeks start Monday; JS counts weekdays from Sunday, so
                    // this rotation is the whole conversion rather than a
                    // seven-entry table (~/.claude/rules/math-over-hardcoding.md).
                    readonly property int lead: (pane.first.getDay() + 6) % 7

                    // Where today falls in THIS pane, -1 when it does not. Asked
                    // of the pane's own month, so the dim copy of today's date
                    // that a neighbouring month's lead-in shows does not wear the
                    // plate: today belongs to its month, not to every rectangle
                    // that mentions the number.
                    readonly property int todayIndex: pane.first.getFullYear() === root.today.getFullYear() && pane.first.getMonth() === root.today.getMonth() ? pane.lead + root.today.getDate() - 1 : -1

                    x: pane.modelData * months.width + root.slide
                    width: months.width
                    height: months.height

                    // TODAY'S PLATE, and the ONLY accent in the panel: "which day
                    // is today" is the one piece of state here worth a colour
                    // (Appearance's rule for the accent). ONE per pane, placed by
                    // arithmetic off the index, rather than a plate inside every
                    // cell: a G2Rect is a vector Shape, and instantiating
                    // forty-two of them per pane to light one would be the wrong
                    // trade.
                    G2Rect {
                        id: plate

                        visible: pane.todayIndex >= 0
                        x: (pane.todayIndex % root.columns) * root.cell + (root.cell - plate.width) / 2
                        y: Math.floor(pane.todayIndex / root.columns) * root.cell + (root.cell - plate.height) / 2
                        width: root.cell - Appearance.padding.small
                        height: plate.width
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.accent
                    }

                    Repeater {
                        model: root.columns * root.rows

                        // Bare positioned texts, not an Item per cell: the cells
                        // take no input of their own (the pager owns every press,
                        // see `poke`), so a wrapper each would be forty-two items
                        // per pane carrying nothing. Plain centring rather than
                        // StyledText's ink offsets, deliberately: the offsets are
                        // per-string, so "8" and "31" would land on slightly
                        // different baselines and the rows would shimmer; a grid
                        // wants its lines level more than each glyph optically
                        // centred.
                        delegate: StyledText {
                            id: cellText

                            required property int index

                            readonly property date day: new Date(pane.first.getFullYear(), pane.first.getMonth(), 1 - pane.lead + cellText.index)
                            readonly property bool inMonth: cellText.day.getMonth() === pane.first.getMonth()

                            x: (cellText.index % root.columns) * root.cell
                            y: Math.floor(cellText.index / root.columns) * root.cell
                            width: root.cell
                            height: root.cell
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            text: `${cellText.day.getDate()}`
                            font.pixelSize: Appearance.font.size.normal
                            // Label tiers, not sizes: a neighbour's day is the
                            // same size a shade quieter, which is also what makes
                            // it read as "tappable ghost of next door". Today
                            // answers the accent underneath with the dark end of
                            // the ramp, for Appearance's reason: a translucent
                            // label tier would let the accent bleed through the
                            // very numeral it is highlighting.
                            color: cellText.index === pane.todayIndex ? Appearance.colour.accentText : cellText.inMonth ? Appearance.colour.text : Appearance.colour.textFaint
                        }
                    }
                }
            }
        }

        // Walks the strip home when the gesture ends, whichever way it ended.
        // Gated on the gesture exactly like the tray's shove: while a finger
        // is down the strip's position is the FINGER'S, and a smoother chasing
        // the same value would be a second writer. Declared inside `months`
        // rather than on the Column because a Follow is an Item, and the
        // Column is a positioner that would give it a slot of its own.
        Follow {
            id: settle

            // The reveal rate, because that is what this is: the remainder of
            // a page is the panel revealing the month it settled on.
            speed: Appearance.anim.revealSpeed
            target: 0

            onValueChanged: if (!pager.paging)
                root.slide = settle.value
        }
    }
}
