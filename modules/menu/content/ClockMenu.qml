pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Time, all of it: here, elsewhere, how long until something, and what happens
// then.
//
// ONE SCROLLED COLUMN, NOT A TAB BAR. Every other clock ships four tabs (iOS,
// the Mac Clock, GNOME's view switcher), and a tab bar is four permanent
// controls of which three exist to say "not this one". That is furniture, in a
// panel that is on screen for four seconds at a time, and DESIGN.md 2.1 spends
// its whole argument refusing furniture. The Mac Clock can afford the chrome
// because it owns a window; a 400px menu cannot. SoundMenu already proved the
// alternative in this codebase: output and input are one menu because they are
// one question, and "where, how long, and when" are three questions about time
// that the same shapes answer three times rather than three shapes to learn.
// The scroll is free: MenuPanel gives every body a viewport that only becomes
// interactive once the content overflows.
//
// A HORIZONTAL PAGER was the tempting alternative, the calendar's month strip
// reused for three panes, and it is wrong twice over. The menu layer's push-back
// is a LEFTWARD drag on the panel, so a leftward swipe inside the body would be
// competing with "put this menu away" for the same motion, and which one won
// would depend on which pixel the press landed on. And a strip asserts a
// SEQUENCE: a month has a next month, and "alarm" is not the next thing after
// "timer", so the gesture would be teaching a relationship that does not exist.
//
// WHERE THE LINE BETWEEN NUMBERS AND SHAPES FALLS, which is the one decision the
// rest of the file follows from. NUMERALS carry every absolute quantity: what
// time it is here, what time it is there, how much of a countdown is left, when
// an alarm goes off. This is the one panel in the shell where numerals ARE the
// information, and the reading literature backs the split (Korvorst, Roelofs &
// Levelt 2007; Meeuwissen, Roelofs & Levelt 2004): a digital display is read
// faster and with fewer errors for an ABSOLUTE reading, while turning a clock
// face into a stated time is conceptual work with a measurable cost. SHAPES
// carry everything relational: where in its own day a zone currently sits, how
// far through a countdown you are, how far a zone is from here. So there are no
// little analogue faces in the zone list, which is the obvious decoration and
// which would ask you to convert a picture into a number in order to answer the
// only question a world clock row is ever asked.
//
// THE ONE IDEA WORTH THE BUILD is the day bar. Every zone row carries, along its
// floor, a hairline 24-hour track with the day band lit and one pip at that
// zone's current hour. Every row shares the same axis, so the horizontal
// distance between two pips IS the offset between two places, drawn to scale,
// and a single faint guide dropped down the column at the local hour turns N
// bars into one instrument. No legend, no tooltip, no second number, and it is
// built from the vocabulary CalendarMenu's usage marks already established:
// plain Rectangles one Appearance.font.stem thick in the quiet tiers. The lit
// band is a flat 06:00-18:00 rather than real sunrise and sunset, which is what
// Apple's own analogue faces do; GNOME spends two more numerals per row on solar
// times, and nobody opened a clock to read them.
//
// THE ONE THING NOT COPIED FROM ANYBODY: Stop and Snooze do not get equal
// targets. Apple's own heat-map testing found equal-sized buttons produced up to
// thirty percent more oversleeping, iOS 26 shipped them equal anyway and got
// exactly the complaints that predicted, and GNOME distinguishes them by colour
// alone at 200px each. Here Snooze is a full-width pill and Stop is a small one
// on the opposite side with a gap between them: the recoverable action gets the
// easy target and the irreversible one has to be aimed at. That is the reverse
// of the usual visual hierarchy and it is right, because the cost of a mis-hit
// is asymmetric.
//
// NO CLOCK LOGIC LIVES HERE. services/Clock.qml owns the data, the ticking, the
// zone offsets (Qt 6.11's QML engine has no Intl object at all, so offsets come
// from a process) and the firing; this file reads and draws. The one exception
// is the LOCAL time, which is read off this menu's own SystemClock rather than
// through the service's offset arithmetic: Qt already knows the local zone, and
// going through `localOffset` would draw UTC for the fraction of a second before
// the first offset refresh lands.
Column {
    id: root

    spacing: Appearance.padding.normal

    // ------------------------------------------------------------------
    // TOKENS.

    // A CONFIGURED NUMBER THAT MAY NOT EXIST YET, and this shell has shipped the
    // bug that comes of assuming otherwise three times: a key absent from
    // Config.defaults does not exist, set() refuses it and merge() drops it, so
    // a token read but never declared comes back `undefined` and poisons
    // whatever arithmetic touches it. The volume readout once drew with no body
    // at all because undefined times a height is NaN reaching a blob rectangle.
    //
    // This menu is landing before its config block does (see this unit's
    // contract, which lists exactly what config/Config.qml and
    // config/Appearance.qml still need), so every token below is read through
    // here and falls back to the value the research spec argues for. It is
    // services/Clock.qml's own `token()` idiom, for the same reason and with the
    // same intent: the moment the keys are declared this stops falling back and
    // the fallbacks become dead weight the integrator can delete.
    // AN EMPTY LIST IS ALSO "NOT CONFIGURED", and that is not a convenience: it
    // is what makes a configurable LIST possible at all here. Config.merge()
    // treats a non-empty default array as a fixed-length tuple and silently
    // discards a user value of a different length, so the only way to let
    // someone have five preset pills instead of four is for the default in
    // Config to be `[]` and the real list to live in the reader. The service's
    // `cloud` template makes exactly this bargain for exactly this reason.
    function token(name: string, fallback: var): var {
        const value = Appearance.sizes[name];
        if (value === undefined)
            return fallback;
        return Array.isArray(value) && value.length === 0 ? fallback : value;
    }

    // Minutes per preset pill. A LIST rather than a tuple: the row below places
    // N pills by arithmetic, so the count is free to change
    // (~/.claude/rules/math-over-hardcoding.md), and Config.merge() only
    // preserves a user array of a different length when the DEFAULT is empty.
    // That is the note in this unit's contract about `timerPresets`.
    readonly property var timerPresets: root.token("timerPresets", [1, 5, 10, 25])

    // The lit hours of a day bar. Genuinely a 2-tuple, so a fixed length is
    // correct for this one.
    readonly property var dayBand: root.token("dayBand", [6, 18])

    // How many rows the add-a-place filter shows, exactly as networkListMax caps
    // the network list.
    readonly property int zoneListMax: root.token("zoneListMax", 8)

    // What the minute and second scrubs magnetise to. Apple's HIG explicitly
    // sanctions a coarser minute granularity ("as long as it divides evenly into
    // 60", with quarter hours as the example); this gives the coarseness as a
    // FEEL rather than as a restriction, because the magnet lets go when you keep
    // pulling.
    readonly property int scrubDetent: root.token("scrubDetent", 5)

    // ------------------------------------------------------------------
    // UNITS, which are not tokens.
    //
    // Twenty-four hours in a day and sixty thousand milliseconds in a minute are
    // not design decisions and have no business in Appearance: they are the
    // conversions the arithmetic below runs on, named here so the expressions
    // read as sentences rather than as bare literals. The same distinction
    // CalendarMenu draws when it writes "twelve to the year" inline.
    readonly property int hoursInDay: 24
    readonly property int oneMinute: 60000

    // The pixel font's own device pixel, which is what a mark drawn beside type
    // made of stems that thick has to weigh. CalendarMenu's `mark`, verbatim and
    // for its reason: a hairline from some finer instrument reads as a different
    // material sitting on the same surface.
    readonly property int mark: Appearance.font.stem

    // How tall a scrub field is, and therefore how tall the colons between them
    // are. Derived rather than measured off a child, because a Row cannot anchor
    // a child to its own height without a loop: StyledText fixes its line box at
    // 4/3 of the pixel size (see the component), so one line of the large tier is
    // exactly this, floored at a row's height so the target is never smaller than
    // anything else in the panel.
    readonly property real scrubHeight: Math.max(Appearance.sizes.rowHeight, Math.round(Appearance.font.size.large * 4 / 3))

    // ------------------------------------------------------------------
    // WHAT TIME IT IS.

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
        // Only while the menu is actually on screen, for TopNotch's and
        // CalendarMenu's reason: a clock bound to labels nobody can see still
        // wakes the render thread. Seconds precision is never wanted here; the
        // running timers read the service's own beat, and no zone row shows
        // seconds.
        enabled: root.visible
    }

    readonly property double now: clock.date.getTime()

    // Where the local day has got to, in fractional hours. Off Qt's own local
    // components rather than through Clock.zoneTime(Clock.localOffset, ...),
    // which would draw UTC until the service's first offset process returns.
    readonly property real localHour: clock.date.getHours() + clock.date.getMinutes() / 60

    // The instant a countdown is measured against. The service's beat only
    // advances while something is actually counting, so it reads zero on a
    // machine with no timers, and `deadline - 0` is a remaining time of fifty-six
    // years. The menu's own minute clock is the honest stand-in until the beat
    // starts.
    readonly property double beat: Clock.tick > 0 ? Clock.tick : root.now

    // ------------------------------------------------------------------
    // WHAT THE PANEL IS CURRENTLY DOING. All of it dies with the body, which is
    // torn down every time the menu closes, so none of it is state anyone has to
    // clean up.

    // The add-a-place affordance, unrolled.
    property bool picking: false

    // Live text from the filter, which is what narrows the list. Read off the
    // field rather than pushed into here, because the field is the thing that
    // has it and a copy would be one more thing to keep in step.
    readonly property string query: filter.value

    // Which alarm's editor is open, by id. One at a time: two open editors is
    // two sets of scrub fields on one 352px column.
    property string editing: ""

    // The timer setter's three fields. They are NOT the service's business: an
    // unstarted duration is a thing being composed, and pushing every scrub of it
    // through a singleton would persist a number nobody has asked for yet.
    property int setHours: 0
    property int setMinutes: 0
    property int setSeconds: 0

    readonly property int composedSeconds: root.setHours * 3600 + root.setMinutes * 60 + root.setSeconds

    // Alarms in the order the day runs, which is the order anyone reads a list of
    // times in. Derived here rather than stored, for the reason the zone sort is
    // derived in the service: an order somebody has to maintain is a preference
    // that can go stale, and this one cannot.
    readonly property var alarmRows: Clock.alarms.slice().sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute))

    // Everything the machine knows about, less what is already on screen, less
    // this machine's own zone (which is block 1 rather than a row), narrowed by
    // the filter and capped. Clock.addZone refuses all three of those anyway;
    // drawing them would be offering a row that answers nothing.
    readonly property var matches: {
        if (!root.picking)
            return [];
        const q = root.query.toLowerCase();
        return Clock.allZones.filter(z => z !== Clock.localZone && !Clock.places.includes(z) && z.toLowerCase().includes(q)).slice(0, root.zoneListMax);
    }

    // ------------------------------------------------------------------
    // FORMATTING.

    // A countdown, as few fields as it needs. "H:MM:SS" while an hour or more
    // remains and "M:SS" under it, so the field width does not jump every hour,
    // and CEILING rather than floor: a timer started at exactly one minute must
    // read 1:00 for its first second rather than 0:59.
    function clockText(ms: double): string {
        const total = Math.max(0, Math.ceil(ms / 1000));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        return h > 0 ? `${h}:${Clock.pad2(m)}:${Clock.pad2(s)}` : `${m}:${Clock.pad2(s)}`;
    }

    // What a zone row says under its city: how far it is from here, and the day
    // word ONLY when the day there is not the day here. iOS prints "Today" on
    // most rows most of the time, which is a label that is true by default and
    // therefore furniture; CalendarMenu already argues this at its Today pill,
    // which is drawn only while it has something to do.
    function zoneDetail(delta: int, dayDelta: int): string {
        const offset = Clock.offsetLabel(delta);
        if (dayDelta === 0)
            return offset;
        return `${offset} · ${dayDelta > 0 ? "tomorrow" : "yesterday"}`;
    }

    // What an alarm row says under its time. Four different sentences because
    // there are four different things worth saying, and none of them is "armed":
    // the Toggle at the other end of the row already says that.
    function alarmDetail(alarm: var): string {
        if (alarm.missed)
            return "missed";
        if (alarm.days.length > 0)
            return alarm.days.map(d => Qt.locale().dayName(d + 1, Locale.ShortFormat)).join(" ");
        if (!alarm.armed)
            return "once";
        const next = Clock.nextFor(alarm, root.now);
        return next > 0 ? `in ${Clock.spanLabel(next - root.now)}` : "once";
    }

    function addPlace(id: string): void {
        Clock.addZone(id);
        root.picking = false;
    }

    // ------------------------------------------------------------------
    // THE PIECES.

    // A section's name. One place rather than five copies of the same three
    // lines, so the tier and the tone cannot drift apart down the panel.
    component Eyebrow: StyledText {
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    // A DAY, DRAWN. The instrument this panel is built around.
    //
    // A track for the whole 24 hours, the daylight band lit along it, and one pip
    // where that place currently is. Used by the local block and by every zone
    // row at the SAME weight on purpose: the bars are one instrument read across
    // rows, and drawing the zones' copies quieter than the local one would break
    // exactly the comparison that makes the column worth having.
    //
    // Every position is arithmetic on the hour and the width; nothing is
    // enumerated (~/.claude/rules/math-over-hardcoding.md). The pip's travel is
    // the width LESS its own width, so it never hangs off either end, which is
    // also why the guide below is offset by half a pip to line up with it.
    //
    // A zone whose pip sits LEFT of the guide while its offset is positive has
    // wrapped past midnight. That is honest rather than a bug: it genuinely is a
    // different day there, and the day word in the row says which.
    component DayBar: Item {
        id: bar

        required property real hourOfDay

        implicitHeight: root.mark * 3
        height: implicitHeight

        // The whole day, at the quietest tier there is: it is the ruler, not a
        // reading.
        Rectangle {
            y: (bar.height - height) / 2
            width: bar.width
            height: root.mark
            color: Appearance.colour.textGhost
        }

        // Daylight. A flat band rather than solar times (see the file header).
        Rectangle {
            x: root.dayBand[0] / root.hoursInDay * bar.width
            y: (bar.height - height) / 2
            width: (root.dayBand[1] - root.dayBand[0]) / root.hoursInDay * bar.width
            height: root.mark
            color: Appearance.colour.fillStrong
        }

        // Where that place is now. Taller than the track and twice as wide, which
        // is the whole of how it reads as a mark ON a ruler rather than as part
        // of it.
        Rectangle {
            x: bar.hourOfDay / root.hoursInDay * (bar.width - width)
            width: root.mark * 2
            height: bar.height
            color: Appearance.colour.text
        }
    }

    // A ROW YOU CAN THROW AWAY: a plate that answers the pointer, a slot for
    // whatever the row is about, a close disc for a cursor, and a rightward drag
    // for a finger.
    //
    // Built here rather than from MenuRow because MenuRow has no floor for a day
    // bar and no dismissal at all; SoundMenu's Level and Channel set the
    // precedent for a menu declaring its own row shapes. One component for all
    // three lists, because a zone, a timer and an alarm are thrown away the same
    // way and three copies of this arbitration would be three chances to get it
    // subtly different.
    //
    // RIGHTWARD ONLY. The notification card throws either way; here a leftward
    // drag is the menu layer's push-back, so a row that answered it would be
    // competing with "put this menu away" for one motion. A leftward drag
    // therefore never latches and the row does nothing, which is the honest
    // outcome: the press is already the row's, so it cannot fall through to the
    // push, and pretending to start a dismissal it will not finish would be
    // worse.
    //
    // NO preventStealing, deliberately, and it is the exact inverse of Slider's
    // constant. A press on a row is genuinely ambiguous between "throw this away"
    // and "scroll the menu", which is the notification card's case verbatim, so
    // the grab stays takeable until an axis wins: a vertical drag started on a
    // row is stolen by MenuPanel's viewport and scrolls the panel, and this card
    // hears `canceled` instead of `released` and stays where it was.
    component Card: Item {
        id: card

        property real rowHeight: Appearance.sizes.rowHeight
        // Whether a tap on the body means anything. A zone is information, the
        // way a calendar day is, so its rows leave this false and do not even
        // offer the hand cursor.
        property bool tappable: false

        default property alias content: slot.data

        // THE STRIP EVERY ROW KEEPS CLEAR on the right, whether or not the disc
        // is currently drawn. Reserving it costs 30px of 352 and buys the one
        // thing worth more than that: nothing moves. The alternatives were a
        // margin that opened on hover, which slides the row's own answer sideways
        // at the moment you are reading it, and a disc drawn over the time with
        // the time faded out, which hides the reading exactly while you decide
        // whether to delete the row.
        readonly property real discSize: Appearance.sizes.minTarget
        readonly property real discSpace: card.discSize + Appearance.padding.small

        signal tapped
        signal dismissed

        // How far the row has been pulled, after resistance, and the raw pointer
        // travel behind it. Two numbers because the commit test is about what the
        // HAND did and the drawing is about where the row IS, and resistance is
        // exactly the difference between them.
        property real dragX: 0
        property real pulled: 0

        readonly property real throwDistance: Math.max(1, card.width) * Appearance.sizes.dragDismissFraction

        // Fades as it leaves, reaching nothing exactly as it clears the panel.
        // Derived from where the resisted travel puts the commit point rather
        // than from a fraction picked by eye, so it lands right at any width.
        readonly property real fade: {
            const held = card.throwDistance * Appearance.sizes.dragResistance;
            const past = Math.max(0, card.dragX - held);
            return Math.max(0, 1 - past / Math.max(1, card.width - held));
        }

        // Resistance before the commit point, 1:1 after it. The notification
        // card's curve and its tokens: the row gives back only half of the first
        // fifth of the throw, so it feels like it is holding on, and past the
        // commit point the slope changes and it tracks the pointer exactly.
        function resist(delta: real): real {
            const commit = card.throwDistance;
            const k = Appearance.sizes.dragResistance;
            return delta < commit ? delta * k : commit * k + (delta - commit);
        }

        implicitWidth: parent ? parent.width : 0
        implicitHeight: card.rowHeight
        height: implicitHeight

        Follow {
            id: settle

            speed: Appearance.anim.revealSpeed
            onValueChanged: if (!drag.throwing)
                card.dragX = value
        }

        // DECLARED FIRST, so it sits UNDER everything the row draws and any
        // control inside the row wins its own press. MenuRow records what the
        // other order costs: a catch-all on top ate the Bluetooth forget button
        // and every notification action.
        //
        // A SIBLING of the moving part rather than inside it, which is the press
        // anchor invariant Pull's header and CalendarMenu's pager both state: the
        // frame a press is measured in must hold still, and `shifted` below is
        // exactly what this gesture moves. Measured from inside it, the row would
        // read its own displacement back as pointer travel.
        MouseArea {
            id: drag

            property real fromX: 0
            property real fromY: 0
            property real startedAt: 0
            // Latched once per gesture, like every gesture in the shell: one that
            // set off vertically was never a throw and must not become one by
            // curving round.
            property bool throwing: false
            // The finger went far enough up or down to have meant it, so the
            // release is not a tap. Needed even though the viewport usually
            // steals such a gesture, because a menu SHORT enough not to scroll
            // never steals anything, and without this every abandoned scroll on a
            // short panel would land as a tap.
            property bool wandered: false
            // The stream's half of the same arbitration. A press hands itself
            // over by simply not latching, because the Flickable takes the grab;
            // a stream cannot be stolen, so the handing over has to be written
            // down, and it LATCHES so the rest of the stream stays the list's.
            property bool scrolling: false

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: card.tappable ? Qt.PointingHandCursor : Qt.ArrowCursor

            function begin(): void {
                drag.startedAt = card.dragX;
                drag.throwing = false;
                drag.wandered = false;
                drag.scrolling = false;
                // Stop whatever the last abandoned throw is still walking home,
                // rather than letting two writers fight over dragX.
                settle.value = card.dragX;
                settle.target = card.dragX;
            }

            // WHOSE GESTURE IS THIS: the row's, or the list's. Horizontal has to
            // do two things to win: travel past the threshold, so the wobble
            // inside a click is not a throw, and dominate the vertical, so a
            // flick that is mostly up the screen is a scroll rather than a
            // dismissal that drifted sideways. A threshold alone is not
            // arbitration, because the first pixels of a scroll cross it too.
            function advance(dx: real, dy: real): void {
                if (!drag.throwing) {
                    if (Math.abs(dy) >= Appearance.sizes.dragThreshold)
                        drag.wandered = true;
                    // Rightward or nothing: a negative dx fails this outright
                    // rather than being compared as a magnitude.
                    if (Math.abs(dy) > dx)
                        return;
                    if (dx < Appearance.sizes.dragThreshold)
                        return;
                    drag.throwing = true;
                }

                card.pulled = dx;
                card.dragX = card.resist(Math.max(0, drag.startedAt + dx));
            }

            function stream(dx: real, dy: real): void {
                if (!drag.throwing) {
                    if (drag.scrolling)
                        return;
                    if (Math.abs(dy) > dx && Math.abs(dy) >= Appearance.sizes.dragThreshold) {
                        drag.scrolling = true;
                        return;
                    }
                }
                drag.advance(dx, dy);
            }

            // COMMITTED ON DISTANCE ALONE, and the flick commit the notification
            // card has is deliberately not copied. A speed test needs a smoothing
            // weight for the per-event velocity, and that weight is a feel
            // constant with no token behind it; the spec for this panel asks for
            // resistance, a commit fraction and a glide home, all three of which
            // are tokens that already exist. If a flick is wanted later it should
            // arrive with `flickVelocity` and a named smoothing weight, not with
            // a number written here.
            function conclude(): void {
                if (!drag.throwing)
                    return;

                if (card.pulled >= card.throwDistance) {
                    card.dismissed();
                    return;
                }

                settle.value = card.dragX;
                settle.target = 0;
                card.pulled = 0;
                drag.throwing = false;
            }

            onPressed: mouse => {
                // A press takes the gesture over, and takes it over cleanly: a
                // stream still running is concluded by its own rule first, so the
                // total it was measuring from cannot be handed to state the press
                // has since zeroed. Pull and CalendarMenu's pager both say this
                // at the same place.
                scroll.finish();
                drag.fromX = drag.x + mouse.x;
                drag.fromY = drag.y + mouse.y;
                drag.begin();
            }

            onPositionChanged: mouse => {
                if (drag.pressed)
                    drag.advance(drag.x + mouse.x - drag.fromX, drag.y + mouse.y - drag.fromY);
            }

            onReleased: {
                // The TAP lives here rather than in conclude(), because it is the
                // one thing the scroll path cannot have: a stream has no press to
                // have been a tap instead, so a stream that never became a throw
                // did nothing at all.
                if (!drag.throwing) {
                    if (!drag.wandered && card.tappable)
                        card.tapped();
                    return;
                }
                drag.conclude();
            }

            // The grab was TAKEN, which is the arbitration above succeeding
            // rather than anything going wrong. It must leave the row exactly as
            // it found it, so the offset is walked home rather than assumed to be
            // zero: a cancel also arrives when the window loses a grab under a
            // throw already in flight.
            onCanceled: {
                settle.value = card.dragX;
                settle.target = 0;
                card.pulled = 0;
                drag.throwing = false;
                drag.wandered = false;
                drag.scrolling = false;
            }

            // TWO FINGERS ACROSS A ROW THROW IT AWAY, exactly as dragging does.
            //
            // The delicate part is geometry: this row sits INSIDE MenuPanel's
            // Flickable, so it is offered every scroll before the list the scroll
            // is nearly always meant for. A row that simply took what it was
            // offered would be a menu that could only be scrolled by the gaps
            // between rows. So the event is given BACK on the same test the
            // arbitration uses, and the undecided events go to the list rather
            // than being held back: QML cannot re-dispatch what it consumed, so
            // anything held back is lost, and losing the first events of every
            // scroll is losing them everywhere, since rows are what this panel is
            // made of.
            onWheel: wheel => {
                if (drag.pressed) {
                    wheel.accepted = false;
                    return;
                }

                // A mouse wheel is not a swipe. feed() refuses it and clears
                // `accepted` itself, so a notch falls straight through to the
                // viewport and scrolls the menu.
                if (!scroll.feed(wheel))
                    return;

                wheel.accepted = drag.throwing;
            }

            ScrollGesture {
                id: scroll

                // A press owns the gesture while it lasts, so no stream may
                // START under one. One already running is not refused, for the
                // primitive's reason, and cannot be: the press has finished it.
                armed: !drag.pressed

                onBegan: drag.begin()
                onMoved: (dx, dy) => drag.stream(dx, dy)
                onEnded: drag.conclude()
            }
        }

        // Everything the row draws, and the only part that moves.
        Item {
            id: shifted

            x: card.dragX
            width: card.width
            height: card.height
            opacity: card.fade

            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill
                // containsMouse covers both inputs: a hover for a cursor, and
                // the synthesised hover a touch press carries, so the plate
                // answers a press too (DESIGN.md 2.3).
                opacity: drag.containsMouse || drag.pressed ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Item {
                id: slot

                anchors.fill: parent
            }

            // THE CURSOR'S ROUTE TO THE SAME ANSWER. A drag is the primary
            // gesture (DESIGN.md 15) and this is the alternate one, which is why
            // it only appears once something is pointing at the row: on a surface
            // with no cursor it never draws at all and the swipe is the whole
            // interface.
            Item {
                id: disc

                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.small
                anchors.verticalCenter: parent.verticalCenter

                width: card.discSize
                height: width
                opacity: drag.containsMouse || discPress.containsMouse ? 1 : 0
                // Not merely transparent: an invisible target that still answers
                // is a hole in the row that eats presses aimed past it.
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                G2Rect {
                    anchors.fill: parent
                    radius: height / 2
                    color: discPress.containsMouse ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
                }

                Icon {
                    anchors.centerIn: parent

                    name: "close"
                    // Sized off the TYPE tier rather than off Appearance's icon
                    // size, which is that tier times 1.1 and leaves two pixels of
                    // disc around the glyph.
                    size: Appearance.font.size.small
                    color: Appearance.colour.textDim
                }

                MouseArea {
                    id: discPress

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.dismissed()
                }
            }
        }
    }

    // A NUMBER YOU SCRUB. The answer to "pick a duration with no keyboard".
    //
    // It does not own its value, exactly as Slider and Toggle do not own theirs:
    // `value` is bound to whatever it sets and `moved` asks for a change.
    //
    // THE PITCH IS DERIVED, never a number picked by hand: one minimum target of
    // travel per detent step, so a five-unit detent gives 4.8px per unit and a
    // full sweep of 0 to 59 is 288px of hand. The magnet catches within a drag
    // threshold of every multiple of the detent and lets go outside it, which is
    // Slider's construction: it catches at the five-minute marks and you can
    // still pull through to 47.
    //
    // DRAG UP INCREASES, matching the volume rail and the wheel. It wraps at both
    // ends, like GNOME's spin buttons, so 59 and 00 are one step apart in either
    // direction rather than a wall you have to drag back from.
    //
    // A wheel is ONE UNIT per notch and never a detent step, because the wheel is
    // the precision input and the drag is the coarse one, and it is claimed
    // unconditionally over this control: a wheel over a control means that
    // control, whatever the wheel does nearby (Slider states this verbatim).
    //
    // A dial you drag a handle around (Material's picker) was the alternative and
    // is wrong here on four counts: it is a circle in a shell with no circles, it
    // wants about 200px square of a 352px column, it makes 24-hour entry awkward
    // enough that Material needs a second ring for it, and there is no meaningful
    // way to operate it with a two-finger scroll. The per-field scrub is the same
    // continuous gesture under a finger, a touchpad stream and a wheel alike, and
    // it is what the Apple Watch already does on the smallest surface anyone
    // ships a timer on.
    component ScrubField: Item {
        id: field

        property int value: 0
        property int from: 0
        property int to: 59
        property int detent: 1
        property bool wrap: true
        // Whether a zero reads as "nothing here yet". True for a duration being
        // composed, where "00:25:00" has to say twenty-five minutes at a glance;
        // false for a time of day, where midnight is a real answer and drawing it
        // faint would call it empty.
        property bool zeroIsEmpty: true

        signal moved(int v)

        readonly property real pitch: Appearance.sizes.minTarget / Math.max(1, field.detent)
        readonly property int span: field.to - field.from + 1

        implicitWidth: Math.max(Appearance.sizes.minTarget, digits.implicitWidth + Appearance.padding.small * 2)
        implicitHeight: root.scrubHeight
        width: implicitWidth
        height: implicitHeight

        // Into range: wrapped both ways for a field that wraps, clamped for one
        // that does not. The double modulo is how a negative walks back round.
        function fold(v: int): int {
            if (!field.wrap)
                return Math.max(field.from, Math.min(field.to, v));
            return field.from + ((v - field.from) % field.span + field.span) % field.span;
        }

        // The magnet, in PIXELS of hand rather than in units, for Slider's
        // reason: what makes a detent feel right is how far you have to move to
        // escape it, and that is a distance, not a fraction of a range.
        function magnet(raw: real): int {
            const step = Math.max(1, field.detent);
            const nearest = Math.round(raw / step) * step;
            return Math.abs(raw - nearest) * field.pitch <= Appearance.sizes.dragThreshold ? nearest : Math.round(raw);
        }

        function ask(raw: real): void {
            field.moved(field.fold(field.magnet(raw)));
        }

        // The wheel's route: exact, unmagnetised, one unit at a time.
        function nudge(units: int): void {
            if (units !== 0)
                field.moved(field.fold(field.value + units));
        }

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill
            opacity: pointer.containsMouse || pointer.pressed || scroll.active ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        StyledText {
            id: digits

            anchors.centerIn: parent

            text: Clock.pad2(field.value)
            font.pixelSize: Appearance.font.size.large
            color: field.zeroIsEmpty && field.value === 0 ? Appearance.colour.textFaint : Appearance.colour.text
        }

        MouseArea {
            id: pointer

            property real fromY: 0
            property int startValue: 0

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            // THE GRAB IS THIS FIELD'S FROM THE PRESS, and nothing may take it
            // back. Slider's constant and its argument: a press on a control is
            // never ambiguous, the control is the target rather than the surface
            // under it, so there is nothing to arbitrate and the menu's viewport
            // must not be able to take the grab mid-adjustment. This is the exact
            // inverse of the Card above, where a press genuinely IS ambiguous.
            preventStealing: true

            onPressed: mouse => {
                scroll.finish();
                pointer.fromY = mouse.y;
                pointer.startValue = field.value;
            }

            onPositionChanged: mouse => {
                if (pointer.pressed)
                    field.ask(pointer.startValue - (mouse.y - pointer.fromY) / field.pitch);
            }

            onWheel: wheel => {
                // A wheel first, because it is the one this control wants most:
                // feed() hands a wheel straight back, so it is judged here and
                // claimed outright.
                if (!scroll.feed(wheel)) {
                    const notches = wheel.angleDelta.y / 120;
                    field.nudge(Math.round(notches) || (notches > 0 ? 1 : notches < 0 ? -1 : 0));
                    wheel.accepted = true;
                    return;
                }

                // A touchpad stream is claimed only while it is vertical, so a
                // horizontal stream over the field still reaches whatever wanted
                // it. CalendarMenu's declining pattern, on the other axis.
                wheel.accepted = Math.abs(scroll.dy) >= Math.abs(scroll.dx);
            }

            ScrollGesture {
                id: scroll

                armed: !pointer.pressed

                onBegan: pointer.startValue = field.value
                onMoved: (dx, dy) => {
                    if (Math.abs(dy) >= Math.abs(dx))
                        field.ask(pointer.startValue - dy / field.pitch);
                }
            }
        }
    }

    // A PILL THAT IS ON OR OFF: a repeat day, an alarm's mode.
    //
    // Not components/Pill.qml, and the reason is one property. Pill draws its
    // label in the primary tier full stop, so an OFF pill would read as on;
    // this needs the label to drop to `textFaint` when the pill is off, which is
    // half of how a row of seven days says which ones are set without a tick, a
    // border or a second colour. Adding `labelColour` to Pill is the better fix
    // and is in this unit's contract; this file does not own that component.
    component StatePill: Item {
        id: pill

        property string label: ""
        property bool on: false

        signal clicked

        implicitWidth: Math.max(Appearance.sizes.minTarget, text.implicitWidth + Appearance.padding.normal * 2)
        implicitHeight: Math.max(Appearance.sizes.minTarget, text.implicitHeight + Appearance.padding.small * 2)
        width: implicitWidth
        height: implicitHeight

        // Pressing it moves it, exactly as Pill does: a button is the one place
        // someone is certain they did something.
        scale: press.pressed ? 0.96 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        G2Rect {
            anchors.fill: parent
            radius: height / 2
            color: pill.on ? Appearance.colour.fillStronger : press.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        StyledText {
            id: text

            anchors.fill: parent

            text: pill.label
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            color: pill.on ? Appearance.colour.text : Appearance.colour.textFaint

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        MouseArea {
            id: press

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    // TYPING, where typing is genuinely irreplaceable: 598 zone names to filter,
    // and a command an alarm is to run. Everything else on this panel is scrubbed
    // or tapped, because there is no keyboard on this surface by default.
    //
    // A layer surface is handed no key events at all until its window asks the
    // compositor for them, and the field is the only thing that knows one is
    // wanted, so it registers with Prompts and the window listens. Same discipline
    // as PasswordField, including the claim being given back on hide AND on
    // destruction: a menu closing destroys its rows outright without them ever
    // passing through invisible.
    component Field: Item {
        id: entry

        property string placeholder: ""
        // Whether the field asks for the keyboard the moment it appears. True for
        // one that appeared BECAUSE somebody asked to type (the zone filter);
        // false for one that is merely part of an editor, where taking the
        // keyboard unasked would silently make every other key in the shell stop
        // working for as long as the editor is open.
        property bool autoFocus: true
        // What the field starts out holding. Applied on arrival and whenever it
        // changes underneath, but never while it has focus, which would fight the
        // hand that is typing.
        property string seed: ""

        readonly property string value: input.text

        // Enter, and the end of an edit however it ended (Enter, Tab, or the
        // focus going elsewhere). Two signals because the two consumers want
        // different moments: a filter acts on Enter, and a payload is written
        // through when the editing stops rather than once per keystroke, which
        // would be one whole-document disk write per character.
        signal accepted(string text)
        signal committed(string text)
        signal cancelled

        implicitHeight: input.implicitHeight + Appearance.padding.small * 2
        height: implicitHeight

        function claim(): void {
            if (entry.visible && entry.autoFocus) {
                // Back to the seed on every appearance, which for the filter is
                // empty: reopening a picker still narrowed by the last thing
                // typed into it is a list that looks broken, and the query is
                // not a preference anybody meant to keep.
                input.text = entry.seed;
                Prompts.request(entry);
                input.forceActiveFocus();
            } else if (!entry.visible) {
                Prompts.release(entry);
            }
        }

        // Asking for the keyboard and having it are a round trip apart, so focus
        // is taken again once the surface actually becomes active. PasswordField's
        // note, and its bug: taken before that lands, it is focus in a surface
        // with no keys to give.
        readonly property bool surfaceActive: entry.Window.active
        onSurfaceActiveChanged: if (entry.surfaceActive && entry.visible && entry.autoFocus)
            input.forceActiveFocus()

        // Both: onVisibleChanged does not fire for an item CREATED already
        // visible, which is exactly how this one arrives when a row rebuilds.
        onVisibleChanged: entry.claim()
        Component.onCompleted: {
            input.text = entry.seed;
            entry.claim();
        }
        Component.onDestruction: Prompts.release(entry)

        onSeedChanged: if (!input.activeFocus)
            input.text = entry.seed

        G2Rect {
            anchors.fill: parent
            anchors.topMargin: Appearance.padding.small
            anchors.bottomMargin: Appearance.padding.small
            radius: Appearance.rounding.small
            color: Appearance.colour.fillStrong
        }

        TextInput {
            id: input

            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal

            verticalAlignment: TextInput.AlignVCenter
            clip: true

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            renderType: Text.NativeRendering
            color: Appearance.colour.text
            selectionColor: Appearance.colour.accent
            selectedTextColor: Appearance.colour.accentText

            onAccepted: entry.accepted(input.text)
            onEditingFinished: entry.committed(input.text)

            Keys.onEscapePressed: entry.cancelled()

            // A field that took the keyboard on demand gives it back the moment
            // the caret leaves, so an editor left open does not go on holding
            // every key in the shell.
            onActiveFocusChanged: {
                if (input.activeFocus)
                    Prompts.request(entry);
                else if (!entry.autoFocus)
                    Prompts.release(entry);
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter

                visible: !input.text && !input.activeFocus
                text: entry.placeholder
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }

        // A field that has to be aimed at before it takes the keyboard still has
        // to be aimable. The TextInput's own area only covers the text, so this
        // is what makes the whole plate answer.
        MouseArea {
            anchors.fill: parent
            enabled: !entry.autoFocus
            cursorShape: Qt.IBeamCursor
            onClicked: {
                Prompts.request(entry);
                input.forceActiveFocus();
            }
        }
    }

    // ------------------------------------------------------------------
    // BLOCK 0: RINGING. Present only while something is demanding an answer.
    //
    // An alarm is the ONE thing in this shell permitted to interrupt, and it does
    // not violate "nothing at a glance": it is a request the user made earlier,
    // arriving when they asked for it.

    G2Rect {
        id: ringing

        readonly property var alarm: Clock.ringing
        // What it was set for, which is not when it rang: a machine asleep past
        // a deadline fires on resume, and a snoozed alarm arrives nine minutes
        // after the time on its face.
        readonly property double due: Clock.ringingSince - Clock.ringingLate

        visible: !!ringing.alarm
        width: parent.width
        height: visible ? answers.y + answers.height + Appearance.padding.normal : 0
        radius: Appearance.rounding.normal
        // The accent as a FILL rather than as ink, which is the one job
        // Appearance sanctions for accentFill: the accent is never used to paint
        // a shape, and this block is the shell shouting rather than labelling.
        color: Appearance.colour.accentFill

        StyledText {
            id: ringTime

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.top: parent.top
            anchors.topMargin: Appearance.padding.normal

            text: ringing.visible ? Qt.formatDateTime(new Date(ringing.due), "HH:mm") : ""
            font.pixelSize: Appearance.font.size.large
            color: Appearance.colour.accent
        }

        StyledText {
            id: ringLabel

            anchors.left: ringTime.left
            anchors.top: ringTime.bottom
            anchors.right: ringLate.left
            anchors.rightMargin: Appearance.padding.normal

            visible: !!text
            text: ringing.alarm?.label ?? ""
            color: Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }

        // HOW LATE IT ALREADY WAS. A user-session shell cannot wake a suspended
        // machine (systemd's WakeSystem needs privileges and only exists in the
        // system manager), so an alarm can arrive long after its time, and the
        // panel has to say so rather than leave it to be worked out from a clock
        // that disagrees with the number next to it. A minute of slack, which is
        // the granularity the alarm was set in.
        StyledText {
            id: ringLate

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.baseline: ringLabel.baseline

            visible: Clock.ringingLate >= root.oneMinute
            text: visible ? `late by ${Clock.spanLabel(Clock.ringingLate)}` : ""
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }

        // THE TWO ANSWERS, AND THEY ARE NOT THE SAME SIZE. See the file header:
        // this asymmetry is the whole point of the block and must not be tidied
        // up. Snooze takes everything Stop does not.
        Item {
            id: answers

            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.normal
            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.normal
            anchors.top: ringLabel.visible || ringLate.visible ? ringLabel.bottom : ringTime.bottom
            anchors.topMargin: Appearance.padding.normal

            height: stop.height

            Pill {
                anchors.left: parent.left

                width: parent.width - stop.width - Appearance.padding.large
                text: "Snooze"
                onClicked: Clock.snooze()
            }

            Pill {
                id: stop

                anchors.right: parent.right

                text: "Stop"
                onClicked: Clock.stop()
            }
        }
    }

    // ------------------------------------------------------------------
    // BLOCK 1: HERE. No eyebrow: the panel's own heading is this city's name.

    Item {
        id: here

        width: parent.width
        height: hereTime.implicitHeight + Appearance.padding.small + hereBar.height

        StyledText {
            id: hereTime

            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: Appearance.font.size.large
        }

        // The ambient copy of what the calendar shows in full (DESIGN.md 2.4:
        // the same information drawn differently depending on whether it is the
        // focus). The date is not what this panel is about, so it takes the
        // quietest tier and the baseline of the thing that is.
        StyledText {
            anchors.right: parent.right
            anchors.baseline: hereTime.baseline

            text: Qt.formatDateTime(clock.date, "ddd d MMM")
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }

        DayBar {
            id: hereBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            hourOfDay: root.localHour
        }
    }

    // ------------------------------------------------------------------
    // BLOCK 2: ELSEWHERE.

    Eyebrow {
        visible: Clock.zones.length > 0
        text: "ELSEWHERE"
    }

    Item {
        id: elsewhere

        visible: Clock.zones.length > 0
        width: parent.width
        height: zoneRows.implicitHeight

        // THE NOW GUIDE: one line down the column at the local hour, so the
        // horizontal distance from it to any pip is that zone's offset, drawn to
        // scale. One per panel rather than one per row, which is what makes the
        // stack of bars a single instrument instead of N unrelated readings.
        //
        // Its x is the pip's own formula plus half a pip, because a pip is
        // mark * 2 wide and travels across the width less its own width: the
        // guide is a mark wide and has to land on the pip's CENTRE, not on its
        // left edge. Derived rather than nudged, so it stays aligned at any width
        // and at any stem.
        Rectangle {
            x: root.localHour / root.hoursInDay * (elsewhere.width - root.mark * 2) + root.mark / 2
            width: root.mark
            height: elsewhere.height
            color: Appearance.colour.textGhost
        }

        Column {
            id: zoneRows

            width: parent.width
            spacing: 0

            Repeater {
                model: Clock.zones

                delegate: Card {
                    id: zoneCard

                    required property var modelData

                    // Driven off this menu's own minute clock rather than off the
                    // service's snapshot, which is the cheaper of the two routes
                    // the service offers: nothing has to tick on the panel's
                    // behalf, and the arithmetic is a shift of an epoch
                    // millisecond read back in UTC.
                    readonly property var at: Clock.zoneTime(zoneCard.modelData.offsetMinutes, root.now)

                    width: zoneRows.width
                    rowHeight: Math.max(Appearance.sizes.rowHeight, names.implicitHeight + Appearance.padding.small * 2 + zoneBar.height + Appearance.padding.small)

                    // A TAP DOES NOTHING, on purpose. A zone is information,
                    // exactly as a calendar day is, and a dead press on it costs
                    // nothing; inventing a use for it (edit? reorder? make it
                    // local?) would be a control looking for a job.
                    onDismissed: Clock.removeZone(zoneCard.modelData.id)

                    Column {
                        id: names

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: timeThere.left
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.top: parent.top
                        anchors.topMargin: Appearance.padding.small

                        spacing: 0

                        StyledText {
                            width: parent.width
                            text: zoneCard.modelData.city
                            color: Appearance.colour.textDim
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: root.zoneDetail(zoneCard.modelData.deltaMinutes, zoneCard.at.dayDelta)
                            color: Appearance.colour.textFaint
                            font.pixelSize: Appearance.font.size.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        id: timeThere

                        anchors.right: parent.right
                        anchors.rightMargin: zoneCard.discSpace
                        anchors.top: parent.top
                        anchors.topMargin: Appearance.padding.small

                        text: zoneCard.at.text
                        font.pixelSize: Appearance.font.size.normal
                    }

                    DayBar {
                        id: zoneBar

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Appearance.padding.small

                        hourOfDay: zoneCard.at.hourOfDay
                    }
                }
            }
        }
    }

    // ADDING ONE. The pill IS the empty state: while no zone is configured at all
    // it still reads "Add a place", so there is no sentence explaining that a
    // list nobody has added to is empty.
    Pill {
        width: parent.width
        text: root.picking ? "Never mind" : "Add a place"
        onClicked: {
            root.picking = !root.picking;
            if (root.picking)
                Clock.loadZoneList();
        }
    }

    Item {
        id: picker

        visible: root.picking
        width: parent.width
        height: visible ? filter.height + zoneList.implicitHeight : 0

        Field {
            id: filter

            width: parent.width

            placeholder: "filter cities"
            onAccepted: if (root.matches.length > 0)
                root.addPlace(root.matches[0])
            // Escape cancels the FIELD; a second Escape then closes the menu,
            // which is the arrangement Menus.qml already documents for
            // PasswordField.
            onCancelled: root.picking = false
        }

        Column {
            id: zoneList

            anchors.top: filter.bottom
            width: parent.width

            Repeater {
                model: root.matches

                delegate: MenuRow {
                    required property var modelData

                    width: zoneList.width
                    label: Clock.cityOf(modelData)
                    // The region, which is what tells three Georgetowns apart.
                    detail: modelData.slice(0, Math.max(0, modelData.lastIndexOf("/"))).replace(/_/g, " ")
                    onActivated: root.addPlace(modelData)
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // BLOCK 3: TIMER.

    Separator {
        width: parent.width
    }

    Eyebrow {
        text: "TIMER"
    }

    Repeater {
        model: Clock.timers

        delegate: Card {
            id: timerCard

            required property var modelData

            readonly property double remainingMs: Clock.remainingOf(timerCard.modelData, root.beat)
            readonly property real fraction: timerCard.modelData.total > 0 ? Math.max(0, Math.min(1, timerCard.remainingMs / timerCard.modelData.total)) : 0

            width: root.width
            rowHeight: Math.max(Appearance.sizes.rowHeight, remaining.implicitHeight + Appearance.padding.small * 2 + track.height + Appearance.padding.small)
            tappable: true

            // Pause and resume are the same press, which is GNOME's two verbs
            // spent as one control: a running timer needs exactly Pause and
            // Reset, and Reset is the throw.
            onTapped: Clock.toggleTimer(timerCard.modelData.id)
            onDismissed: Clock.removeTimer(timerCard.modelData.id)

            StyledText {
                id: remaining

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.top: parent.top
                anchors.topMargin: Appearance.padding.small

                text: root.clockText(timerCard.remainingMs)
                font.pixelSize: Appearance.font.size.large
                // FINISHED IS THE ONLY STATE HERE WORTH THE ACCENT. Running is
                // expected, and expected is not worth a colour; paused drops to
                // the faint tier and the bar holds, which is unmistakable and
                // costs no extra control. A colour change on the last minute was
                // rejected outright: the numerals already count, and an accent
                // arriving at sixty seconds is a second alarm going off before
                // the first one.
                color: timerCard.modelData.finished ? Appearance.colour.accent : timerCard.modelData.paused ? Appearance.colour.textFaint : Appearance.colour.text
            }

            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: timerCard.discSpace
                anchors.baseline: remaining.baseline

                text: `of ${root.clockText(timerCard.modelData.total)}`
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }

            // IT DRAINS. A countdown that fills is a progress bar for the wrong
            // quantity: the thing you are watching is what is LEFT.
            //
            // Linear rather than a ring, which is what everybody else ships and
            // what will be asked for first. The duration here is known and the
            // question is how much remains, which is the case the literature
            // gives to linear indicators; the shell has no ring anywhere, so one
            // would be a new primitive learned once for one control; the G2 rule
            // does not even reach an arc, so it would be the one shape not going
            // through G2Rect; and a 352px bar carries more resolution than any
            // ring that fits in a menu row.
            G2Rect {
                id: track

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.padding.small

                height: Appearance.sizes.sliderHeight
                radius: height / 2
                color: Appearance.colour.fill

                G2Rect {
                    width: drain.value
                    height: parent.height
                    radius: height / 2
                    color: Appearance.colour.text
                    opacity: 0.55
                }
            }

            // The bar is smoothed so a once-a-second target reads as continuous;
            // the NUMERALS are never smoothed and cut per second, because a
            // number easing toward its own value is a number you cannot read.
            Follow {
                id: drain

                target: timerCard.fraction * track.width
                speed: Appearance.anim.trackSpeed
            }
        }
    }

    // THE SETTER. Three fields and a colon between each, which is GNOME's H:M:S
    // rather than Apple's hours-and-minutes: a kitchen timer wants ninety
    // seconds, and the third field costs 72px of a 352px line. The 23-hour cap
    // stays, because a countdown longer than a day is an alarm and this panel has
    // one of those.
    Item {
        id: setter

        width: parent.width
        height: fields.height

        Row {
            id: fields

            anchors.left: parent.left

            spacing: Appearance.padding.small

            ScrubField {
                value: root.setHours
                to: 23
                detent: 1
                onMoved: v => root.setHours = v
            }

            StyledText {
                height: root.scrubHeight
                verticalAlignment: Text.AlignVCenter
                text: ":"
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.textFaint
            }

            ScrubField {
                value: root.setMinutes
                detent: root.scrubDetent
                onMoved: v => root.setMinutes = v
            }

            StyledText {
                height: root.scrubHeight
                verticalAlignment: Text.AlignVCenter
                text: ":"
                font.pixelSize: Appearance.font.size.large
                color: Appearance.colour.textFaint
            }

            ScrubField {
                value: root.setSeconds
                detent: root.scrubDetent
                onMoved: v => root.setSeconds = v
            }
        }

        // Drawn only while there is a duration to start. A control with nothing
        // to do is not drawn, which is the same rule the calendar's Today pill
        // keeps.
        Pill {
            anchors.right: parent.right
            anchors.verticalCenter: fields.verticalCenter

            visible: root.composedSeconds > 0
            text: "Start"
            onClicked: Clock.startTimer(root.composedSeconds, "")
        }
    }

    // THE QUICK START. Tapping a preset starts a timer of that length
    // immediately; it does NOT load the fields. That is GNOME's quick-start and
    // the Apple Watch's preset semantics, and it is the two-second path this
    // panel exists for.
    //
    // Placed by arithmetic across the width for whatever count the config holds:
    // N equal pills, the first flush left and the last flush right, so the row
    // stays right when the list changes (~/.claude/rules/math-over-hardcoding.md).
    Item {
        id: presets

        width: parent.width
        height: childrenRect.height

        Repeater {
            model: root.timerPresets

            delegate: Pill {
                required property int index
                required property var modelData

                readonly property int count: root.timerPresets.length

                x: count > 1 ? index * (presets.width - width) / (count - 1) : (presets.width - width) / 2
                width: (presets.width - Appearance.padding.small * (count - 1)) / count

                text: `${modelData}m`
                onClicked: Clock.startTimer(modelData * 60, "")
            }
        }
    }

    // ------------------------------------------------------------------
    // BLOCK 4: ALARM.

    Separator {
        width: parent.width
    }

    Eyebrow {
        text: "ALARM"
    }

    Repeater {
        model: root.alarmRows

        delegate: Card {
            id: alarmCard

            required property var modelData

            readonly property bool open: root.editing === alarmCard.modelData.id

            width: root.width
            rowHeight: head.height + (alarmCard.open ? editor.implicitHeight + Appearance.padding.normal : 0)
            tappable: true

            // The editor unrolls IN PLACE, under the row it belongs to, and a
            // second tap puts it away. A separate editing panel would be a second
            // place the same alarm exists.
            onTapped: root.editing = alarmCard.open ? "" : alarmCard.modelData.id
            onDismissed: Clock.removeAlarm(alarmCard.modelData.id)

            Item {
                id: head

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                height: Math.max(Appearance.sizes.rowHeight, times.implicitHeight + Appearance.padding.small * 2)

                Column {
                    id: times

                    anchors.left: parent.left
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.right: armed.left
                    anchors.rightMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 0

                    StyledText {
                        width: parent.width
                        text: `${Clock.pad2(alarmCard.modelData.hour)}:${Clock.pad2(alarmCard.modelData.minute)}`
                        font.pixelSize: Appearance.font.size.normal
                    }

                    StyledText {
                        width: parent.width
                        text: root.alarmDetail(alarmCard.modelData)
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }
                }

                // The Toggle keeps its accent on-state: it is the shell's switch
                // and this panel does not get to redefine it. Nothing else in the
                // block takes the accent.
                Toggle {
                    id: armed

                    anchors.right: parent.right
                    anchors.rightMargin: alarmCard.discSpace
                    anchors.verticalCenter: parent.verticalCenter

                    checked: alarmCard.modelData.armed
                    onToggled: Clock.setAlarmArmed(alarmCard.modelData.id, !alarmCard.modelData.armed)
                }
            }

            // THE EDITOR. No Done button: every change writes straight through to
            // the service, the row above updates as you scrub, and it collapses
            // when you tap the row again or when the menu closes. A modal Done on
            // a live panel is a second state to get out of sync.
            Column {
                id: editor

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal
                anchors.top: head.bottom
                anchors.topMargin: Appearance.padding.normal

                visible: alarmCard.open
                spacing: Appearance.padding.small

                Row {
                    spacing: Appearance.padding.small

                    ScrubField {
                        value: alarmCard.modelData.hour
                        to: 23
                        detent: 1
                        // Midnight is a real time, not an empty field.
                        zeroIsEmpty: false
                        onMoved: v => Clock.setAlarm(alarmCard.modelData.id, {
                                hour: v
                            })
                    }

                    StyledText {
                        height: root.scrubHeight
                        verticalAlignment: Text.AlignVCenter
                        text: ":"
                        font.pixelSize: Appearance.font.size.large
                        color: Appearance.colour.textFaint
                    }

                    ScrubField {
                        value: alarmCard.modelData.minute
                        detent: root.scrubDetent
                        zeroIsEmpty: false
                        onMoved: v => Clock.setAlarm(alarmCard.modelData.id, {
                                minute: v
                            })
                    }
                }

                // SEVEN DAYS, placed by the same arithmetic the presets use and
                // labelled from the locale rather than from a seven-entry table:
                // dayName(i + 1, Narrow) is Monday-first, which is exactly the
                // service's own day numbering, so the index that labels a pill IS
                // the index that arms it. CalendarMenu's initials row, verbatim.
                //
                // Selecting none means one-shot, which is why there is no
                // "repeat" switch: the days already say it.
                Item {
                    id: days

                    width: parent.width
                    height: childrenRect.height

                    Repeater {
                        model: 7

                        delegate: StatePill {
                            required property int index

                            x: index * (days.width - width) / 6
                            width: (days.width - Appearance.padding.small * 6) / 7

                            label: Qt.locale().dayName(index + 1, Locale.NarrowFormat).toUpperCase()
                            on: alarmCard.modelData.days.includes(index)
                            onClicked: {
                                const was = alarmCard.modelData.days;
                                Clock.setAlarm(alarmCard.modelData.id, {
                                    days: was.includes(index) ? was.filter(d => d !== index) : [...was, index]
                                });
                            }
                        }
                    }
                }

                // WHAT IT DOES WHEN IT GOES OFF, which is the part of an alarm
                // this shell has that nobody else's does: the service can run a
                // command or put a question to a cloud agent and bring the answer
                // back as a notification. Without these three pills the feature is
                // reachable only by editing clock.json by hand.
                //
                // A COMMAND MODE IS ARBITRARY CODE EXECUTION BY DESIGN, trusted
                // exactly as far as a cron line is, and clock.json is as exposed
                // as a crontab. That is the service's bargain, stated in its
                // header; this row is only the way to say so.
                Item {
                    id: modes

                    width: parent.width
                    height: childrenRect.height

                    Repeater {
                        model: [
                            {
                                key: "none",
                                label: "Nothing"
                            },
                            {
                                key: "command",
                                label: "Command"
                            },
                            {
                                key: "cloud",
                                label: "Cloud"
                            }
                        ]

                        delegate: StatePill {
                            required property int index
                            required property var modelData

                            x: index * (modes.width - width) / 2
                            width: (modes.width - Appearance.padding.small * 2) / 3

                            label: modelData.label
                            on: alarmCard.modelData.mode === modelData.key
                            onClicked: Clock.setAlarm(alarmCard.modelData.id, {
                                    mode: modelData.key
                                })
                        }
                    }
                }

                Field {
                    width: parent.width

                    visible: alarmCard.modelData.mode !== "none"
                    // It does NOT take the keyboard on sight. An editor opening is
                    // not somebody asking to type, and a menu that grabbed every
                    // key because a row was expanded would make the rest of the
                    // shell go deaf for as long as it stayed open.
                    autoFocus: false
                    seed: alarmCard.modelData.payload
                    placeholder: alarmCard.modelData.mode === "cloud" ? "what to ask" : "what to run"
                    onCommitted: text => Clock.setAlarm(alarmCard.modelData.id, {
                            payload: text
                        })
                }
            }
        }
    }

    // A new alarm at the next whole hour, armed, one-shot, with its editor
    // already open: a new alarm that starts at 00:00 is a new alarm you have to
    // fix before it is worth anything.
    Pill {
        width: parent.width
        text: "Add an alarm"
        onClicked: {
            const id = Clock.addAlarm();
            if (id)
                root.editing = id;
        }
    }
}
