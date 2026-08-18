pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

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
// screen and which way the hand was still going.
//
// WHICH WAY IS FORWARD IS A SETTING, defaulting to a swipe RIGHTWARD landing
// on the NEXT month, which is the reading this shell was asked for by name and
// the opposite of what a strip of paper under the fingers would do. Config's
// `calendar.rightGoesForward` argues both sides at length and this file does
// not repeat the argument; what it owes the setting is that the inversion be
// total, so the whole mapping from the hand to the strip turns on ONE
// multiplier applied at ONE line (see `gestureSign` and advance()) and every
// number after it is already in the strip's own frame. That is what makes it
// impossible for the month previewed under the fingers to be a different month
// from the one the release commits to.
//
// AND TWO FINGERS ON A TOUCHPAD ARE THAT SAME DRAG, through
// components/ScrollGesture.qml: a laptop has no edge to push and no third hand
// to hold a button down while it swipes, so a month gesture that only existed
// for a press would not exist at all on the machine this shell is used on most.
// The two inputs are not two implementations of one feel here, they are one:
// the press and the stream both run begin/advance/settle below, and the only
// line either of them owns alone is where its own motion is measured from.
//
// Chevrons would also have been
// two more permanent controls, which is the furniture this shell does not keep
// (DESIGN.md 2.1); the one button that remains is the title, because "take me
// back to today" from eight months away is a real errand with no gesture. The
// title never SAID it was that button, though, so a small pill opposite it
// says so out loud, and only while the shown month is not today's: a control
// with nothing left to do is furniture, so at home it is not drawn at all.
//
// THE GRID IS ALSO A QUIET LOG, and it is drawn as a MOSAIC. services/Usage.qml
// keeps a record of when this machine was awake, and each day wears it as its
// own tile, sitting BEHIND the numeral and filled one step lighter the longer
// the machine was up. No numbers, no tooltips, no legend, on purpose: the user
// asked for "the feeling of it", and a figure would turn a texture you absorb
// into a statistic you audit. How MANY times the machine was woken is
// deliberately not drawn at all, though the service still records it: at a
// month's scale the count mostly repeats what the duration already said, and
// the one place it could be stated honestly is a day detail that does not exist
// yet. Today's tile is the accent one, so today alone does not state its level.
//
// THE MARKS THIS REPLACED were a dot per waking and a thin bar for how long,
// laid along each cell's floor, and they failed in three separate ways of which
// only one was taste. They were a second FIGURE inside a fifty-pixel cell,
// competing with the numeral they were supposed to stay behind, where DESIGN.md
// 2.4 asks for something ambient. A row of dots has to be COUNTED to be read,
// and a mark that must be resolved has already left the periphery it was for.
// And they could not be drawn cleanly at all: `cell` is width/7, about 50.28px,
// so a two-pixel mark inside it lands on a different fraction of a pixel in
// every one of the seven columns and renders as two half-covered columns, a
// grey smear rather than a mark. A tile is immune to all three. It is a ground,
// not a figure; it carries its magnitude as one continuous area with nothing in
// it to count; and a large, soft-edged, low-alpha shape does not care about
// half a pixel, which is why today's plate has always been drawn at exactly
// these fractional coordinates and has always read perfectly well.
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
    // moves its accent tile without being reopened. Minute precision: a calendar
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

    // Whether the shown month IS today's month, which is the gate on the way
    // home: the pill in the heading only exists while this is false, because
    // a button that does nothing has no business being drawn.
    //
    // NOT NAMED `onToday`, AND THE NAME IS THE WHOLE OF THE BUG IT FIXES.
    //
    // There is a `today` property a few lines up, so QML already owns the
    // identifier `onToday`: that is the handler slot for a signal named
    // `today`. Declaring a property by that name is accepted, and then the
    // binding written against it is parsed as a HANDLER DECLARATION rather
    // than as a property binding, so the property keeps its default and is
    // never evaluated again. Measured live before the rename: the property
    // read false while the identical expression evaluated in place read true,
    // with `shownYear` 2026 against `todayYear` 2026 and `shownMonth` 7
    // against `todayMonth` 7. Nothing about the comparison was wrong; the
    // binding was simply not there.
    //
    // What it looked like: the "Today" pill drawn while the calendar was
    // already showing today's month, which is precisely the button whose
    // entire argument is that it hides when it has nothing to do.
    //
    // The rejected fix was to keep the name and push the value from a
    // function instead of binding it. That works and it hides the trap: the
    // next `onSomething` property added to a file that also has a `something`
    // fails the same silent way. A name QML does not already mean is the fix.
    readonly property bool showingToday: root.shownYear === root.today.getFullYear() && root.shownMonth === root.today.getMonth()

    // Today has just been asked for again: home() announces its arrival and the
    // pane holding today re-lights the accent (see the tile), so the eye is
    // taken to the day the whole errand was about rather than left to find it
    // in a grid that merely changed.
    signal relit

    // THE LADDER THE MOSAIC CLIMBS: this shell's own fill vocabulary, read in
    // order. A lightly used day wears a container, an ordinary day a hover, a
    // long one a selection, so the rungs are three materials the menus already
    // ship side by side rather than three alphas invented here for a calendar.
    // A private list of numbers was the alternative and it loses badly: it
    // would be a second opacity vocabulary sitting next to material.fill and
    // free to drift out of step with it, and if a rung is ever wrong the honest
    // fix is that the shell's fills are wrong, where every other surface reads
    // them. Being bindings on Appearance, a theme change re-tints the mosaic.
    //
    // Legibility of a numeral over the top rung needs no new argument:
    // fillStronger is what a selected menu row wears, and the shell already
    // puts a text-tier label on that fill.
    //
    // THE NUMBER OF RUNGS IS THIS ARRAY'S LENGTH and is written as a digit
    // nowhere: the level below divides by it, so a fourth rung is one more
    // entry (~/.claude/rules/math-over-hardcoding.md). Three rather than the
    // four GitHub's contribution graph uses, and that is measured rather than
    // taste: a white veil on a TRANSLUCENT panel over an arbitrary blurred
    // wallpaper has far less contrast to spend than a swatch on an opaque page,
    // and Config's own fill note already records a 1.18:1 step here as barely
    // reading. Four rungs across the same range put two neighbours at about
    // that ratio. Three is also the whole sentence this grid has to say: a bit,
    // a day, a long day.
    //
    // AND THE TOP TWO RUNGS ARE ALREADY THE CLOSE PAIR, measured off a capture
    // of this grid rather than argued: over the panel at RGB 27/40/40 the
    // rungs land at 42/55/55, 57/70/69 and 65/78/77, which is 1.23:1 from
    // nothing to the first, 1.26:1 to the second and only 1.13:1 to the third.
    // The first two steps are clear at a glance and the last is separable when
    // two tiles touch and no better than that, because material.fill's own
    // third stop is 0.035 above its second where the second is 0.075 above the
    // first: the ladder this reads is not evenly spaced. NOT FIXED HERE. A list
    // of alphas private to the calendar would be a second opacity vocabulary
    // free to drift out of step with the fills every other surface wears, so if
    // a rung is wrong the fill is wrong, and it gets fixed where a selected
    // menu row will feel it too.
    readonly property var usageTones: [Appearance.colour.fill, Appearance.colour.fillStrong, Appearance.colour.fillStronger]

    // How far the strip of months is displaced, in pixels, positive when the
    // strip has been pushed RIGHT, which is what brings the PREVIOUS month
    // into view: pane -1 is laid out a full pane to the left, so a positive
    // slide is exactly what walks it onto the screen.
    //
    // A fact about the strip's geometry and deliberately NOT about the hand,
    // which is what it used to be ("dragged toward the previous month") and
    // could no longer be once which way the hand has to move became a setting.
    // Everything that reads this value reads the geometry: the panes' x, the
    // hit test in `poke`, and the release's choice of month. None of them ask
    // what `gestureSign` says, and none of them can be wrong when it changes.
    //
    // Written by the finger while the gesture runs and by `settle` afterwards,
    // never by both at once; the same arrangement as the notification tray's
    // pushBack.
    property real slide: 0

    // WHICH WAY THE MONTHS RUN UNDER THE HAND, as the one number the setting
    // becomes: the multiplier that turns the gesture's own horizontal travel
    // into the strip's.
    //
    // +1 IS FORWARD, and that was established by swiping rather than by
    // reasoning: the polarity here was written the other way round, from an
    // argument about which way the strip has to move to bring pane +1 on
    // screen, and shipped a setting whose name said the opposite of what it
    // did. Turning `rightGoesForward` ON sent a rightward swipe to the PREVIOUS
    // month. There is a second negation somewhere between the hand and this
    // line for that to be true, and the honest thing was to calibrate against
    // the hand rather than to keep the derivation and a name that lies about
    // it: this is the multiplier the gesture actually needs, measured.
    //
    // Config's `calendar.rightGoesForward` is where the taste is argued, and
    // the taste is real: the other value is the paper reading, the strip going
    // where the hand puts it, which is what nearly every carousel ships.
    //
    // A binding rather than a value read at creation, so flipping the setting
    // takes effect on the calendar already open rather than on the next one.
    readonly property int gestureSign: Appearance.sizes.calendarRightGoesForward ? 1 : -1

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
    //
    // `delta` IS ABSOLUTE and `gestureSign` never reaches here: +1 is one month
    // later and -1 one month earlier, whatever direction a hand would have had
    // to move to ask for it. That matters because most of the callers have no
    // direction to speak of. `home()` and `poke()` both compute a number of
    // months from two dates and pass it, and a "Today" pill that went the wrong
    // way because of a swipe preference would be nonsense. Only the release
    // below turns a direction into a delta, and it does so by reading the
    // strip's geometry rather than the hand's.
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
            // After the page, not before: the pane that holds today is only
            // decided once the month has turned, and the signal's listener
            // asks it which one it is.
            root.relit();
            return;
        }
        root.shownYear = root.today.getFullYear();
        root.shownMonth = root.today.getMonth();
        root.slide = 0;
        settle.value = 0;
        root.relit();
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
            // the press too (DESIGN.md 2.3). The pill's hover is subtracted
            // because Qt 6 delivers hover to every area under the cursor, not
            // just the topmost: without the gate, aiming at the pill would
            // also light the whole heading, two controls answering one
            // pointer as if they were the same control.
            opacity: homeTap.pressed || (homeTap.containsMouse && !todayPill.hovered) ? 1 : 0

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

        // THE WAY BACK, said out loud. The title has always been the way home,
        // but nothing about a month's name advertises that, and the user who
        // has paged eight months out and lost today should not need to have
        // read this file to get back. So while the shown month is not today's
        // a quiet pill sits opposite the title and names the errand; the
        // moment the calendar is home it vanishes, because a button whose job
        // is done has no business being drawn (visible, not enabled: a
        // disabled ghost would be furniture with a memory). Declared after
        // homeTap so its press lands here and not on the heading, though both
        // roads lead to home() anyway.
        Pill {
            id: todayPill

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            visible: !root.showingToday
            text: "Today"

            onClicked: root.home()
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
            // above, and the ONE thing the two inputs do not share: a press
            // has a place and has to remember it, a stream has motion and
            // nothing to remember (components/ScrollGesture.qml's own split).
            // Only the press handlers and the tap read it, which is why the
            // three gesture functions below take totals and never a position:
            // a scroll reports how far the fingers went and never where they
            // are, so anything asking WHERE would have no answer on that path.
            property real fromX: 0
            property real fromY: 0
            property real startSlide: 0
            // Where along the gesture's horizontal total the page began,
            // captured at the moment it latches so the threshold pixels are
            // spent on deciding rather than on a jump. Kept as a TOTAL rather
            // than as a re-read of the pointer, because a total is the one
            // coordinate both inputs can state: a scroll never reports a
            // position, only how far the fingers have gone.
            //
            // In the STRIP's frame, like everything else advance() keeps: it is
            // written from `travel` and subtracted from `travel`, so the
            // direction setting cancels out of it entirely rather than having
            // to be remembered here.
            property real originTravel: 0
            // Latched ONCE per gesture, like every gesture in the shell: one
            // that set off vertically was never a page and must not become one
            // by curving round, and one that latched stays latched however it
            // wanders.
            property bool paging: false
            property bool spent: false
            // Smoothed with the same constant as Pull and the bottom edge,
            // because the last event before a release is noise as often as it
            // is direction. In pixels PER EVENT, not per millisecond, because
            // `flickVelocity` is written in that unit and is read here at face
            // value (the notification card and the workspace scrub read it the
            // same way); Pull's own velocity is per-ms because `pullReversal`
            // is, and the two tokens must not be crossed.
            //
            // THE STRIP'S SPEED, not the hand's, because advance() converts
            // before it differences. A positive velocity means the strip is
            // travelling right whichever way the hand had to move to send it
            // there, which is the only reason the release may compare it
            // against `slide` at all: two numbers share a sign only while they
            // are measured in the same frame.
            property real velocity: 0
            // The strip's total at the previous step, so a step can be
            // differenced back out of it. A total in, a step out, which is
            // what lets the press hand over the same numbers the stream does.
            property real lastTravel: 0

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
            // The menu's own viewport DOES flick now (MenuPanel wraps every
            // body in one, and a menu past the clamp scrolls in it), so this is
            // no longer insurance against a hypothetical: it is what stops a
            // month swipe from being taken away mid-gesture by the scroll
            // behind it. The price is that a vertical DRAG on the grid still
            // does nothing rather than scrolling a long calendar, because a
            // MouseArea that keeps its grab cannot hand one back. The scroll
            // path has no such price and does not pay it: see the wheel handler,
            // where a vertical stream is never claimed in the first place.
            preventStealing: true
            // The gesture advertises itself (DESIGN.md 2.3): nothing drawn on
            // the grid says it slides, so the cursor does, the same way the
            // notification card's does.
            cursorShape: pager.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            // THE GESTURE ITSELF, in three functions both inputs call, which
            // is the whole of how a touchpad stream and a press are kept from
            // becoming two opinions about what a month swipe is. The split
            // falls exactly where the inputs differ, which is only the origin;
            // everything after the subtraction is common. Pull's own
            // arrangement, for Pull's own reason.

            // A new gesture. Everything the press used to zero, and nothing
            // about where it started.
            function begin(): void {
                pager.startSlide = root.slide;
                pager.originTravel = 0;
                pager.lastTravel = 0;
                pager.paging = false;
                pager.spent = false;
                pager.velocity = 0;
            }

            // One step, given how far the gesture has travelled IN TOTAL since
            // it began, in this area's own pixels. Totals rather than steps
            // because the threshold test and the slide are both questions
            // about the whole journey, and because a path reporting steps
            // would have to keep its own running sum, which is this
            // subtraction written a second time somewhere it can go stale.
            //
            // AND THE ONE LINE THE DIRECTION SETTING IS, at the top, where the
            // hand's total becomes the STRIP's. Every line after it works in
            // the strip's frame: the smoothed velocity, the origin the page
            // re-anchors on, the slide itself, and therefore the release, which
            // reads nothing else. The alternative was a sign flipped at the
            // release instead, and it is worth naming because it is the obvious
            // one-character version of this change and it is wrong: the panes
            // follow the slide, so the month that had slid in under the fingers
            // would have been precisely the month the release then refused, and
            // the calendar would have spent the whole gesture previewing a lie.
            // Converted here there is only one number, so the preview and the
            // commit cannot be two opinions.
            //
            // The two axis tests below read MAGNITUDES, so they ask the same
            // question in either frame and the setting cannot move where a
            // gesture latches, only which way it then goes.
            function advance(dx: real, dy: real): void {
                if (pager.spent)
                    return;

                const travel = dx * root.gestureSign;
                const step = travel - pager.lastTravel;
                pager.lastTravel = travel;
                pager.velocity += (step - pager.velocity) * 0.4;

                if (!pager.paging) {
                    // Still inside the wobble of a tap: nothing is decided.
                    if (Math.abs(travel) < Appearance.sizes.dragThreshold && Math.abs(dy) < Appearance.sizes.dragThreshold)
                        return;

                    // WHICH AXIS WON, judged once, the moment the gesture
                    // becomes a gesture at all. Vertical wins and it is spent:
                    // it is not a page, and it is no longer a tap either, so
                    // the release owes it nothing.
                    //
                    // On the PRESS path that is the end of it: this area holds
                    // the grab and a MouseArea cannot give one back, so a
                    // vertical drag on the grid does nothing at all, exactly
                    // as it always has. On the SCROLL path being spent is also
                    // what hands the REST of the stream on to the menu's own
                    // viewport, which is a scroll this grid did not use to have
                    // under it; see the wheel handler for how that is done.
                    if (Math.abs(dy) > Math.abs(travel)) {
                        pager.spent = true;
                        return;
                    }

                    pager.paging = true;
                    // Re-anchored, so the page starts from where the hand is
                    // NOW rather than jumping the threshold's worth it spent
                    // proving itself. The slide is re-read too, because
                    // `settle` may have moved it since the gesture began.
                    pager.originTravel = travel;
                    pager.startSlide = root.slide;
                    return;
                }

                // Content follows the gesture, clamped to one pane: the strip
                // holds one neighbour each side, so travel past that would
                // drag blank canvas on screen. FOLLOWS, not merely reacts to,
                // in either direction the setting picks: under the paper
                // reading the strip goes where the hand goes, and under the
                // default it goes the other way at exactly the same rate, so
                // the month you are asking for is the month arriving under your
                // fingers and it arrives one pixel per pixel.
                root.slide = Math.max(-months.width, Math.min(months.width, pager.startSlide + (travel - pager.originTravel)));
            }

            // The end, however the input announced it: a lifted button, or a
            // touchpad stream that stopped sending. What follows is the same
            // question either way, which is the point of the split.
            //
            // NAMED FOR PULL'S, and it therefore SHADOWS the `settle` Follow at
            // the bottom of this file for every expression written inside this
            // area: an object's own members beat a component-scoped id. Nothing
            // in here wants that Follow (the strip is walked home through
            // root.glide(), which is evaluated in root's scope where the id
            // still means the Follow), and the name is worth keeping because it
            // is the word every other gesture in the shell uses for this exact
            // moment. Anyone adding a line here that wants the smoother has to
            // reach it through root.
            function settle(): void {
                if (pager.paging) {
                    // WHICH MONTH WINS: the one that is mostly on screen, or
                    // the one the STRIP was still travelling toward fast
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
                    //
                    // ALL THREE TERMS ARE THE STRIP'S and none of them has
                    // heard of `gestureSign`, which is what keeps this
                    // paragraph true under either setting. `slide` is where the
                    // strip stands and `velocity` is where it is going, both in
                    // the same frame, so their product still asks "is it going
                    // further the way it already leans"; and a positive slide
                    // still means pane -1 is the one on screen, so it still
                    // commits to the previous month. The hand is nowhere in
                    // here on purpose: it was converted away one function
                    // above, which is why what you saw arriving is what you get.
                    const half = Math.abs(root.slide) > months.width / 2;
                    const onward = root.slide * pager.velocity > 0 && Math.abs(pager.velocity) >= Appearance.sizes.flickVelocity;
                    if (half || onward)
                        root.page(root.slide > 0 ? -1 : 1);
                    root.glide();
                }
                pager.paging = false;
                pager.spent = false;
            }

            // THE DRAG PATH: a press, its origin, and the release.

            onPressed: mouse => {
                // A PRESS TAKES THE GESTURE OVER, and takes it over cleanly.
                // Both paths write one set of state, so a stream still running
                // when a hand lands is concluded by its own rule first: a page
                // two fingers had half-turned is ANSWERED rather than
                // abandoned mid-strip, and the stale total it was measuring
                // from cannot be handed to state the press has since zeroed.
                // Pull says the same thing at the same place.
                scroll.finish();

                pager.fromX = pager.x + mouse.x;
                pager.fromY = pager.y + mouse.y;
                pager.begin();
            }

            onPositionChanged: mouse => {
                if (pager.pressed)
                    pager.advance(pager.x + mouse.x - pager.fromX, pager.y + mouse.y - pager.fromY);
            }

            onReleased: {
                // The TAP lives here rather than in settle(), because it is the
                // one thing on this path the other path cannot have: a scroll
                // has no press to have been a tap instead, so a stream that
                // never became a page did nothing at all.
                if (!pager.paging && !pager.spent)
                    root.poke(pager.fromX, pager.fromY);

                pager.settle();
            }

            onCanceled: {
                // Not settle(): a cancel is not a release. The grab was taken
                // away rather than let go, so there is no intent in it to read
                // a momentum out of, and it always goes back.
                if (pager.paging)
                    root.glide();
                pager.paging = false;
                pager.spent = false;
            }

            // THE SCROLL PATH: two fingers, answered as the same swipe, and
            // answered on ONE AXIS ONLY.
            //
            // This calendar is a BODY inside MenuPanel's viewport, and a menu
            // taller than the panel's clamp scrolls inside it. That viewport is
            // an ANCESTOR of this area, and today a scroll over the grid
            // reaches it purely by falling through: the pager had no wheel
            // handling at all, so the event walked up the chain to the
            // Flickable. Taking every scroll here would take that away, and a
            // long month would become a document that could no longer be read.
            //
            // QML cannot hand an event on once it has been accepted, so the
            // split is made by DECLINING rather than by re-dispatching. The
            // gesture is fed every event, because a stream cannot be judged
            // without being measured, and `accepted` then answers yes only
            // while the horizontal total is the bigger one. A scroll that is
            // vertical from its first event is therefore never claimed at all
            // and lands on the viewport exactly as it does now, which is
            // better than the drag path manages: a press is a grab and is
            // consumed either way. One that sets off sideways and then turns
            // spends its opening events here, which IS the drag path's own
            // property and the price of judging an axis at all.
            //
            // The comparison is the same one advance() latches on, ties
            // included: there an exact tie fails `Math.abs(dy) >
            // Math.abs(travel)` and becomes a page, so `>=` here claims it, and
            // the axis this file acts on can never disagree with the axis it
            // claims. `travel` is this same `scroll.dx` with the direction
            // setting folded in, which is a sign and never a size, so the two
            // magnitudes are the same number and the tie stays a tie.
            //
            // Past the latch the claim stops asking. `paging` claims
            // unconditionally, because a swipe that set off sideways and then
            // curved down is still the page it set out as and an `accepted`
            // that went on re-judging would start scrolling the menu underneath
            // a page still following the fingers. `spent` is the mirror and
            // never claims again, which is what hands the rest of a vertical
            // stream to the viewport.
            onWheel: wheel => {
                if (!scroll.feed(wheel))
                    return;

                wheel.accepted = pager.paging || (!pager.spent && Math.abs(scroll.dx) >= Math.abs(scroll.dy));
            }

            ScrollGesture {
                id: scroll

                // A press owns the gesture while it lasts, so no stream may
                // START under one. A stream already running is not refused,
                // for the primitive's reason, and cannot be: the press above
                // has already finished it.
                armed: !pager.pressed

                // The whole adoption, three lines: a stream is a press, a total
                // is a delta, and a lapse is a release.
                onBegan: pager.begin()
                onMoved: (dx, dy) => pager.advance(dx, dy)
                onEnded: pager.settle()
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
                    // accent: today belongs to its month, not to every rectangle
                    // that mentions the number.
                    readonly property int todayIndex: pane.first.getFullYear() === root.today.getFullYear() && pane.first.getMonth() === root.today.getMonth() ? pane.lead + root.today.getDate() - 1 : -1

                    // How lit today's tile is, 1 at rest; the re-light below
                    // walks it up from nothing when home() lands.
                    property real glow: 1

                    x: pane.modelData * months.width + root.slide
                    width: months.width
                    height: months.height

                    // THE RE-LIGHT. Getting home is only half of home()'s
                    // errand; the other half is showing WHICH day the trip
                    // was for, so on arrival today's tile fades up from
                    // nothing instead of merely being there when the month
                    // lands. A fade rather than a swell or a flash: nothing
                    // else on this grid moves for attention, and a tile that
                    // jumped in scale would be the loudest thing the calendar
                    // ever did for its quietest fact. One-shot, so it is an
                    // animation and not a Follow: nothing is being tracked,
                    // there is no target that can move mid-flight, which is
                    // the same line the heading plate's hover fade takes. It
                    // drives the pane's own `glow` and the tile WEARS that,
                    // rather than gripping the tile's opacity from outside: an
                    // animation writes its target imperatively, which is the
                    // binding-destroying grab DESIGN.md 15 records against
                    // DragHandler, so the imperative writes are kept on a
                    // number that exists to be written. Every pane carries
                    // the listener but only the one that actually holds today
                    // answers; by the time the signal arrives home() has
                    // already turned the month, so the test reads the settled
                    // answer.
                    Connections {
                        target: root

                        function onRelit(): void {
                            if (pane.todayIndex >= 0)
                                relight.restart();
                        }
                    }

                    NumberAnimation {
                        id: relight

                        target: pane
                        property: "glow"
                        from: 0
                        to: 1
                        duration: Appearance.anim.slow
                    }

                    Repeater {
                        model: root.columns * root.rows

                        // Bare positioned texts, not an Item per cell: the cells
                        // take no input of their own (the pager owns every press,
                        // see `poke`), so a wrapper each would be forty-two items
                        // per pane carrying nothing. The day's tile below lives
                        // as a CHILD of each text rather than earning that
                        // wrapper back: a Text is an Item, the day it draws is
                        // already computed here, and a second repeater walking
                        // the same forty-two dates to place the same tiles would
                        // be the grid saying everything twice. Plain centring
                        // rather than StyledText's ink offsets, deliberately:
                        // the offsets are per-string, so "8" and "31" would land
                        // on slightly different baselines and the rows would
                        // shimmer; a grid wants its lines level more than each
                        // glyph optically centred.
                        delegate: StyledText {
                            id: cellText

                            required property int index

                            readonly property date day: new Date(pane.first.getFullYear(), pane.first.getMonth(), 1 - pane.lead + cellText.index)
                            readonly property bool inMonth: cellText.day.getMonth() === pane.first.getMonth()
                            readonly property bool onAccent: cellText.index === pane.todayIndex

                            // WHAT THIS DAY REMEMBERS of the machine being
                            // used. A plain binding, and it stays live anyway:
                            // forDay reads the service's revision counter as
                            // it runs, so the binding re-evaluates on every
                            // beat of the log without this file wiring a
                            // Connections into a hundred and twenty-six cells
                            // (Usage.revision records the arrangement). Only
                            // the pane's OWN days ask at all: the dim lead-in
                            // belongs to next door and tells its story there,
                            // and marking the same date in two panes at once
                            // would double the ink for a day the grid is only
                            // mentioning.
                            readonly property var usage: cellText.inMonth ? Usage.forDay(cellText.day) : null

                            // How much of a full day the machine was awake, 0
                            // to 1 against the configured cap. Capped rather
                            // than scaled for the config's reason: a scale that
                            // kept stretching would put every ordinary day on
                            // the bottom rung.
                            readonly property real awake: cellText.usage ? Math.min(1, cellText.usage.minutes / (Appearance.sizes.usageCapHours * 60)) : 0

                            // WHICH RUNG THIS DAY STANDS ON, 0 for a day with
                            // nothing to say. Even quantiles OF THE CAP, taken
                            // from the ladder's own length rather than from a
                            // list of thresholds, so the rung count lives in
                            // exactly one place (~/.claude/rules/math-over-
                            // hardcoding.md). Quantised before it is drawn and
                            // never as a continuous shade, which is the same
                            // decision GitHub's graph publishes as its contract:
                            // the picture is of a BUCKET, not of a number, and a
                            // ramp with no steps in it would invite reading a
                            // value back out of a colour.
                            //
                            // Ceil rather than round or floor, so any nonzero
                            // day reaches rung one: the same intent the deleted
                            // bar had when it floored itself at a single grain
                            // so a short real session was a visible tick rather
                            // than a rounding to nothing.
                            readonly property int level: cellText.awake > 0 ? Math.min(root.usageTones.length, Math.ceil(cellText.awake * root.usageTones.length)) : 0

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
                            color: cellText.onAccent ? Appearance.colour.accentText : cellText.inMonth ? Appearance.colour.text : Appearance.colour.textFaint

                            // THE DAY'S TILE: the indicator, and on today also
                            // the plate. It is a GROUND, drawn behind the
                            // numeral rather than beside it, which is the whole
                            // difference from the marks it replaced: the day
                            // number keeps the cell's voice and the log becomes
                            // the material it is written on.
                            //
                            // TODAY'S TILE AND EVERY OTHER TILE ARE ONE OBJECT,
                            // which is why the pane no longer draws a plate of
                            // its own: same size, same corner, same place, and
                            // today's differs only in wearing the accent. The
                            // grid reads as a mosaic with exactly one coloured
                            // tile in it, which states "today" more firmly than
                            // a plate alone in an empty grid ever did, and it
                            // deletes the entire class of bug where a mark has
                            // to know which ground it is standing on, because
                            // nothing is drawn on the accent at all now.
                            //
                            // SO TODAY NEVER SHOWS ITS OWN LEVEL. A decision,
                            // not an omission, and it is not to be worked
                            // around with an inset, an outline or a darker
                            // accent. It could not be read if it were drawn:
                            // one accent tile on screen has no second accent
                            // tile to be compared against, so a modulated
                            // accent carries no information and only doubt
                            // about whether the accent itself has changed. It
                            // must not be drawn: modulating the accent by data
                            // is precisely what Appearance's rule forbids, the
                            // accent means today and must not also mean seven
                            // hours. And it is not worth drawing: today's
                            // figure is the one still being written, changing
                            // every minute you look at it, and it is the one
                            // day you were there for.
                            //
                            // The plate's own comment argued that instantiating
                            // forty-two G2Rects per pane to light one would be
                            // the wrong trade. That was right, and it did not
                            // survive the data arriving: every instance now
                            // carries a day's information, and the item count
                            // actually FALLS, because up to four dot Rectangles
                            // plus a bar in every one of the forty-two cells is
                            // more items than one tile per USED day. `active`
                            // rather than `visible` is what keeps that true: a
                            // day with nothing to say instantiates no Shape at
                            // all, and a day outside the month never asks the
                            // log, so the dim lead-in stays exactly as quiet as
                            // it has always been.
                            //
                            // The geometry is the deleted plate's, expression
                            // for expression, fractional coordinates included:
                            // a mosaic does not survive one tile being a
                            // rounding different from its neighbours, and a
                            // large soft shape is the one thing that does not
                            // care about half a pixel. z: -1 puts it behind
                            // this Text's own glyphs (Qt paints negative-z
                            // children, then the item's content, then the
                            // rest), which is what lets one tile live inside
                            // the delegate instead of a second Repeater walking
                            // the same forty-two dates to say it again.
                            Loader {
                                id: tile

                                z: -1
                                active: cellText.onAccent || cellText.level > 0
                                x: (root.cell - tile.width) / 2
                                y: (root.cell - tile.height) / 2
                                width: root.cell - Appearance.padding.small
                                height: tile.width

                                sourceComponent: G2Rect {
                                    radius: Appearance.rounding.normal
                                    color: cellText.onAccent ? Appearance.colour.accent : root.usageTones[cellText.level - 1]
                                    // Today's tile is the one that fades up
                                    // when home() lands; every other tile is a
                                    // plain binding that never animates,
                                    // because a level changes once a minute at
                                    // most and a grid that dissolved every time
                                    // the log ticked would be moving for no
                                    // reason anyone could name.
                                    opacity: cellText.onAccent ? pane.glow : 1
                                }
                            }
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
