import QtQuick
import qs.config

// TWO FINGERS ON A TOUCHPAD ARE A SWIPE, and this is the one place that says so.
//
// Everywhere this shell answers a drag it has to answer the same motion made
// with two fingers on a touchpad: the same direction, the same recognition, the
// same tracking the whole way, the same right to change your mind halfway
// through, and the same commit at the end. A laptop has no touchscreen edge to
// push and no third hand to hold a button down while it swipes, so a gesture
// that only exists for a press is a gesture that does not exist on the machine
// this shell is used on most.
//
// It is ONE component rather than a rule written out again per site precisely
// because the rule is about everything that comes LATER as well. Pull adopts
// this, so the settings corner, the notification tray, the notch, the launcher
// panel and the menus inherit it without a line changing at the call site; a
// site that hand-rolls its own drag adopts it in four lines and gets the same
// feel rather than a second opinion about what a swipe is.
//
// IT TAKES A TOUCHPAD AND NOTHING ELSE, and that refusal is half of what makes
// it safe to put everywhere. A wheel notch already means something in nearly
// every place a gesture lives: the right edge changes the volume with it, a
// GlideList scrolls, the settings pager scrolls the page it is over, a slider
// steps. Hijacking the wheel to mean "swipe" would break all of that at once
// and buy nothing, because a wheel has one axis and no motion in it to track.
// So an event that carries no pixelDelta is a wheel, and a wheel is handed
// straight back: `accepted` goes false and it falls through to whoever wanted
// it. The two devices are told apart the way VolumeRail already tells them
// apart, by the pixels a touchpad reports alongside the angle and a wheel does
// not.
//
// HOW IT GETS THE EVENT: a function the consumer calls, NOT a WheelHandler of
// its own, and that is the one structural decision in the file.
//
// A handler declared in here would insert itself into the delivery order by
// GEOMETRY: wheel events go to the topmost item under the pointer and stop at
// the first thing that accepts, so an instance of this parked next to a
// GlideList, inside the settings pager, or over the volume rail would silently
// win or lose the event depending on where it happened to sit in the tree. All
// three of those sites already own the wheel (GlideList and SettingsFace with a
// WheelHandler, VolumeRail and Slider with a MouseArea's own onWheel), and only
// they can say whether a given scroll is a swipe or is scrolling. This shell
// has already paid for input decided by stacking rather than stated outright,
// once for a hover the volume rail lost to its own readout; the fix there was
// to make the order say what was meant, and the same lesson applies before the
// fact here. A function makes the consumer write the priority down.
//
// It costs nothing in reach, because a WheelHandler's `wheel` signal and a
// MouseArea's `onWheel` deliver the SAME object (QQuickWheelEvent, checked in
// Qt's own headers), so `feed` serves either source and a consumer keeps
// whichever one it already has.
//
// WHICH WAY THE FINGERS WENT, which is not what the event says.
//
// Qt's delta points the way the CONTENT is meant to move, in ordinary screen
// coordinates: a positive y is content downward, a positive x is content
// rightward. Natural scrolling is precisely the statement that the content
// follows the fingers, so with it ON the delta already IS the finger motion,
// and with it OFF the content travels against the hand and the delta is the
// finger motion negated. That is why one line covers both axes:
//
//     finger = pixelDelta * (natural ? 1 : -1)
//
// ESTABLISHED, NOT REMEMBERED. Getting this backwards would run every gesture
// in the shell the wrong way round, and it is the kind of sign that is
// remembered wrong by half the people who write it down, so it was read off
// three independent sources on this machine rather than recalled:
//
//   - libinput's own header (/usr/include/libinput.h, the natural-scroll
//     configuration docs) states the two modes physically: traditionally "when
//     the fingers move down, the scroll bar moves down, a line of text on the
//     screen moves towards the upper end of the screen", and under natural
//     scrolling "when the fingers move down, a line of text on the screen moves
//     down". So the inversion happens in the input stack, BEFORE Qt sees
//     anything, which is exactly why it has to be undone from the setting and
//     cannot be read off the numbers.
//   - Qt's own installed QML pins the x axis, which nothing in this repo had
//     yet used: /usr/lib/qt6/qml/org/kde/plasma/components/Slider.qml computes
//     `(angleDelta.y || -angleDelta.x) * (inverted ? -1 : 1)` under the comment
//     "We want a positive delta to increase the slider for up/right scrolling
//     ... The x-axis is also inverted (scrolling right produce negative
//     values)". A scroll to the right arriving negative is the same statement
//     as a positive x meaning content moving right, which is the y axis's rule
//     unchanged rather than a special case: scroll-up and scroll-left are
//     opposite screen signs, so the two axes only LOOK inverted relative to
//     each other while the sentence is phrased in scroll directions.
//   - this shell's own shipped behaviour, twice over. GlideList moves the list
//     by `contentY -= pixelDelta.y` and the content follows the fingers on this
//     machine's natural-scrolling touchpad, which fixes the y sign under
//     natural scrolling; VolumeRail's nudge() undoes the setting with the same
//     `* (natural ? -1 : 1)` and up is louder, which fixes it under both
//     settings and for both devices.
//
// The natural-scroll test itself is VolumeRail's, in shape and for its reason:
// Qt sets `inverted` when the stack has already flipped the axis, which is the
// direct answer when it is there and simply absent on some, so the compositor
// is asked what a touchpad is set to as well, and either one saying yes is
// enough. The device kind is not in question by the time the test runs, so this
// asks about the touchpad alone where the rail has to choose between two.
//
// THE END OF A GESTURE HAS TO BE INFERRED, and that is the genuinely hard part.
//
// A press has a release; a scroll stream has nothing of the kind. Fingers that
// lift send no farewell, and fingers that merely stop moving send nothing
// either, so the only evidence either way is silence. So this does what
// GlideList already does with its coast: a timer restarted by every event, and
// when it lapses the gesture is over.
//
// IT CANNOT TELL THE TWO SILENCES APART, and that has to be said outright,
// because the arrangement reads as though it can. This file used to claim that
// fingers which stopped moving before they left had spent their velocity down to
// nothing, so a pause ended a slow gesture and a lift ended a fast one. That is
// true of a hand which decelerates while it is still sending, and false of the
// case it was written for: libinput sends NOTHING AT ALL for fingers resting
// still on the pad, so neither the speed below nor the smoothed velocity a
// consumer keeps decays through silence. Both stand at whatever the last moving
// sample made them. A hand that pushes a panel halfway up and then rests to
// reconsider is therefore answered, one lapse later, with the momentum it had
// BEFORE it stopped, and the remainder of that one physical motion arrives as a
// second gesture with its own `began`, which a consumer that latches something
// there (the bottom edge decides which panel it is driving on `began`) latches a
// second time against whatever the first half has just opened.
//
// Nothing in here can fix that, which is why it is written down rather than
// worked around. The only evidence in the stream is silence, and no interval
// separates a pause from a lift: a longer one delays every commit, including the
// ones that followed a real lift, and a shorter one ends gestures mid-swipe. It
// is the one place the shell's promise of "the same reversibility" is not kept,
// a held press staying alive indefinitely where a held stream does not. The
// crisp answer is the scroll PHASE, below.
//
// The interval is `anim.fast`, GlideList's own, under a floor that keeps it a
// gesture timer rather than a setting (see `lapseFloor`), and deliberately NOT
// `sizes.coastMs`. That token reads like the obvious candidate and is measuring
// something else: it is milliseconds OF THE VELOCITY a flick ended at, a
// distance multiplier, and its documented zero value means "stop dead the
// instant you let go". As a lapse interval zero would mean "every single event
// is its own complete gesture", which is the whole mechanism destroyed by a
// setting that was only ever about how far a list coasts. The question this
// timer asks, "has the stream stopped", is the question GlideList's coast timer
// already asks, so it reads the answer GlideList reads.
//
// A consumer can also end one on the spot with finish(), which is what a site
// with a second input does when that input takes the gesture over; see there.
//
// Qt does deliver a scroll PHASE, and it is reachable from here rather than
// merely existing in C++: QQuickWheelEvent exports `phase` as a property
// (Qt's own installed headers, qquickevents_p_p.h), so `wheel.phase === Qt.
// ScrollEnd` is one line away. It would answer BOTH of the above at once,
// ending a gesture at the lift instead of a beat after it, and leaving a pause
// running because a pause sends no end. It is not used, and the reason is not
// that it is missing but that its BEHAVIOUR cannot be verified from here: a
// stack that brackets every frame rather than every gesture would fragment a
// swipe into one-event gestures too short to clear any recognition distance,
// which is the feature silently not working rather than working differently,
// while a timeout cannot fail that way and can only feel slightly late. When
// someone can drive a real touchpad against a real Hyprland and watch the
// phases arrive, this is the first thing worth revisiting, and the pause above
// is what it buys.
//
// WHAT IT REPORTS is the TOTAL since the gesture began rather than each step,
// because that is the shape a drag hands out: a consumer already computes
// "where the pointer is now, less where it started" and does its projection,
// its slack test and its progress against that number. Reporting steps would
// make every consumer keep its own running sum, which is the same accumulation
// written once per site and rounded slightly differently at each.
//
// AND IT REPORTS A SPEED, which is the one number a consumer genuinely cannot
// work out for itself as well as this can. Position is the same question on
// both inputs and the total answers it; SPEED is the single thing that provably
// differs between a press-drag and a scroll stream, because the two arrive at
// different rates, and a rate is exactly what a per-event difference cannot see.
// A site that differences the totals it is handed here gets pixels per EVENT,
// which is pixels times whatever rate the device happened to send at, and that
// is why `vx`/`vy` exist and are in pixels per millisecond: only dividing by the
// clock takes the sending rate back out. See there for the unit trap that comes
// with it.
Item {
    id: root

    // Whether a NEW gesture may begin, with one already in flight left alone to
    // finish. The same rule Pull's press applies when it is unarmed, and it
    // matters for the same reason: what unarms one of these is usually the
    // gesture it is running, so a hard gate would strand a stream halfway with
    // its `ended` never fired and whatever it is driving left mid-travel.
    property bool armed: true

    // The stream has started. Consumers that keep their own gesture state reset
    // it here, which is the scroll path's equivalent of a press.
    signal began
    // How far the fingers have travelled in total since `began`, in physical
    // pixels of this item's own coordinates: x rightward, y downward, exactly
    // as a drag reports them.
    //
    // NOT emitted for the first event of a stream. Its travel is not lost, it
    // arrives inside the second one's total, and the reason that one report is
    // held back is that a consumer timing its own steps would otherwise measure
    // the first of them against the same millisecond `began` handed it: see
    // feed() for the whole of that argument.
    signal moved(real dx, real dy)
    // The fingers stopped sending. See the header: this is a lapse, not a
    // report, and it is the only end there is.
    signal ended

    // A gesture is in progress. Written here and nowhere else; it is a plain
    // property rather than a read of the timer's own `running` because a
    // non-repeating Timer still reads as running while its `triggered` handler
    // is on the stack, so a consumer asking this question from inside `ended`
    // would be told the gesture it is ending is still going.
    property bool active: false

    // The running total, kept as well as signalled so a consumer can read it
    // back at the end without having stored the last `moved` itself. NOT
    // cleared when the gesture ends, so `ended` can still see how far it went;
    // the next `began` is what zeroes them.
    property real dx: 0
    property real dy: 0

    // HOW FAST THE FINGERS ARE GOING, in pixels per MILLISECOND, smoothed, and
    // kept past the end for the same reason the totals are: `ended` is a lapse,
    // and the question a lapse is asked is "which way was it going and how
    // quickly", which cannot be answered by state the lapse has just cleared.
    //
    // PER MILLISECOND, and that is the whole point of computing it in here.
    // A magnitude in pixels per EVENT is really pixels times the device's event
    // rate, and this stream's rate is not the press path's rate: Qt compresses
    // pointer moves to roughly one a frame, while a touchpad sends its own
    // stream at whatever the hardware and the compositor between them decide.
    // So the same physical swipe measured per event is a different number
    // depending only on which input made it, which is this whole rule's thesis
    // broken at the last step: the two inputs would track identically and then
    // commit at different speeds. Dividing each step by its own elapsed time is
    // what Pull, the notification card, GlideList and the settings pager's
    // scroll axis already do, for exactly this reason.
    //
    // A VELOCITY VECTOR rather than a speed along some direction, because the
    // direction is the consumer's and this primitive does not know it. A site
    // with a direction takes the dot product with its own unit vector and gets
    // precisely the number it would have computed itself, because projection
    // and this smoothing are both linear and commute; a site that only wants a
    // sign reads the axis it cares about.
    //
    // THE UNIT TRAP, said here because this is where the next adopter will
    // read it: `Appearance.sizes.flickVelocity` is documented in pixels per
    // EVENT and is read at face value by the calendar's pager and the settings
    // pager's paging axis, while the notification card and Pull's `pullReversal`
    // are already per millisecond. Those sites disagree with each other and did
    // so before any of this existed; nothing here silently converts between
    // them. Threshold this against a per-millisecond token, and if the only
    // token that fits is a per-event one, say out loud at the call site that it
    // is being reinterpreted.
    property real vx: 0
    property real vy: 0

    // When the last event landed, so its own dt can be measured: a velocity in
    // real time needs real time.
    property real lastEvent: 0

    // Hand it a wheel event; it answers whether it took it.
    //
    // It also SETS `accepted` to that answer, which is redundant for a consumer
    // that assigns the return value and is the point for one that does not: the
    // one-line adoption `onWheel: wheel => scroll.feed(wheel)` is then correct
    // by itself, mouse wheels falling through and touchpad scrolls consumed. A
    // rule meant to be adopted by everything added later has to be right in its
    // shortest spelling, because that is the spelling it will be adopted in.
    // Consumers wanting anything else assign after the call and win.
    function feed(wheel: var): bool {
        // A mouse wheel reports an angle and no pixels; a touchpad reports
        // both. See the header for why the wheel is left alone.
        const touchpad = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;

        // Unarmed refuses to START one, never to continue one.
        if (!touchpad || (!root.active && !root.armed)) {
            wheel.accepted = false;
            return false;
        }

        const natural = wheel.inverted || Compositor.naturalScrollTouchpad;

        // Read once, because the distance and the speed below must be measured
        // against the same instant or the second contradicts the first.
        const now = Date.now();
        const fresh = !root.active;

        if (fresh) {
            root.dx = 0;
            root.dy = 0;
            root.vx = 0;
            root.vy = 0;
            root.active = true;
            root.began();
        }

        // The one line the header spends a page on.
        const sign = natural ? 1 : -1;
        const stepX = wheel.pixelDelta.x * sign;
        const stepY = wheel.pixelDelta.y * sign;
        root.dx += stepX;
        root.dy += stepY;

        // A SPEED NEEDS TWO EVENTS TO EXIST, so the first event of a stream
        // carries distance and no speed at all. The only interval available to
        // divide that first step by is the gap since the last event of the
        // PREVIOUS stream, or since the epoch when there has not been one, and
        // neither is a measurement of this gesture: run through the ceiling
        // below it would report some arbitrary fraction of the first step's
        // travel as the speed the hand set off at, a number that looks measured
        // and is not. Zero until there is an interval to measure is the honest
        // answer, and it costs one event of a stream that has to be several
        // events long before anything downstream recognises it as a gesture at
        // all.
        //
        // The dt clamp is GlideList's and Pull's, both ends of it: a floor of
        // one so a burst landing inside the same millisecond cannot divide
        // toward infinity, a ceiling of a hundred so the first step after a
        // mid-stream pause reads as slow rather than being spread over a stale
        // timestamp. The smoothing constant is the shell's own, the one Pull,
        // the bottom edge, the notification card and both pagers smooth their
        // velocities with; a stream that smoothed differently from the drag it
        // is meant to be indistinguishable from would part company from it at
        // precisely the moment both are asked how fast they were going.
        if (!fresh) {
            const dt = Math.max(1, Math.min(100, now - root.lastEvent));
            root.vx += (stepX / dt - root.vx) * 0.4;
            root.vy += (stepY / dt - root.vy) * 0.4;
        }
        root.lastEvent = now;

        // Before the signal rather than after it, so a consumer that ends the
        // stream from inside its own `moved` handler (by calling finish(),
        // which is a thing a consumer is allowed to do) leaves no timer behind
        // to fire `ended` a second time into a gesture nobody is holding.
        coast.restart();

        wheel.accepted = true;

        // THE FIRST EVENT OF A STREAM CARRIES ITS DISTANCE AND REPORTS NOTHING,
        // for the reason the speed above skips it and with rather more at stake,
        // because on this one the consumers are the ones holding the stopwatch.
        //
        // `began` and the first `moved` used to arrive inside this one call, and
        // a consumer reads the clock in both of them: its begin() records
        // Date.now(), and its advance() divides the step it is handed by the
        // time since that record. Inside a single JS tick those two readings are
        // the SAME millisecond, so the dt clamp every site copied from GlideList
        // returned its floor, and the first step was divided by one millisecond
        // instead of by the eight to sixteen it really took. That is a first
        // velocity sample most of an order of magnitude too fast, arriving at
        // the one moment the smoothing has no history to dilute it with, and it
        // is read downstream as intent: the notification card's speed commit
        // cleared `flickVelocity` on a ten pixel sideways twitch and deleted the
        // notification, and the settings pager multiplied it by `coastMs` and
        // threw a page several screens. The drag path never had it, because
        // there begin() runs on the press and the first onPositionChanged is a
        // real interval later, so it was structural to this path alone.
        //
        // WHAT IT COSTS is one event of tracking, the eight to sixteen
        // milliseconds before the second one lands, and NOT the travel: the
        // first step is already in the totals, so the next `moved` hands it over
        // together with the second, recognition still happens at the distance it
        // always did, and nothing downstream ends up short of where the fingers
        // actually are. The consumer's own first sample is then two events of
        // travel over one event of time, twice the truth rather than sixteen
        // times it, and since its smoothing starts at zero and takes 0.4 of each
        // sample that lands at eight tenths of the real speed: an under-read
        // that catches up within two more events, in place of an over-read that
        // commits.
        //
        // A stream of exactly ONE event now reports nothing at all, which is the
        // honest answer to one. It is a few pixels, shorter than any recognition
        // distance in the shell, so nothing would have latched on it anyway, and
        // `ended` still arrives afterwards to close the gesture out.
        //
        // The alternatives were both worse. Starting the totals at the second
        // event instead, so every event still reports, leaves every later total
        // short by the first step's travel and the surface sits permanently a
        // few pixels behind the fingers it is following. Widening `moved` to
        // carry the elapsed time makes this function's shape the problem of six
        // call sites, and the drag path, which shares those very functions, has
        // no such number to pass them. The consumer that wants the speed rather
        // than the shape reads `vx`/`vy` above and needs no first-event rule at
        // all; this one is for the sites that difference the totals themselves,
        // and it has to be right for them, because a rule meant to be adopted by
        // everything added later gets adopted in its shortest spelling.
        if (!fresh)
            root.moved(root.dx, root.dy);
        return true;
    }

    // End a running stream NOW, as though the coast had just lapsed, and do
    // nothing at all when none is running.
    //
    // It exists for the consumer whose gesture gets taken over by another input
    // mid-stream, which in practice means a press landing while two fingers are
    // still going. The alternative is worse in both directions: dropping the
    // stream silently leaves whatever it had already driven halfway to
    // somewhere with no ending ever delivered, and leaving it running lets a
    // stale total arrive after the other input has reset the state and jump the
    // gesture a hundred pixels in one step. Ending it by its own rule answers
    // what the fingers did, and hands the state over clean.
    //
    // The timer routes through here too, so there is exactly one way for a
    // gesture to end and one place that says what ending means.
    function finish(): void {
        if (!root.active)
            return;

        coast.stop();
        root.active = false;
        root.ended();
    }

    // THE SHORTEST SILENCE THAT CAN STILL MEAN "GONE", and a hard floor rather
    // than a feel token, which is the distinction the line below turns on.
    //
    // `anim.fast` is a duration a human is meant to perceive, and every duration
    // in this shell is a tier off `anim.base`, which a person is invited to set:
    // `banditshell set anim.base 0` is accepted as written, because Config.set
    // validates that a key exists and never what it is worth. Zero there means
    // an animation that is simply instant, which is a legitimate thing to ask a
    // shell for, and it means something entirely different here. A Timer with an
    // interval of zero fires on the next pass of the event loop, which is before
    // the next scroll event can possibly arrive, so every single event would
    // become its own complete began/moved/ended gesture, each one a few pixels
    // long and none of them ever reaching `pullSlack`. Every touchpad gesture in
    // the shell would stop working at once, with no error anywhere and nothing
    // in the logs, from a setting about how fast panels slide.
    //
    // This file's header already argues that exact scenario when it rejects
    // `sizes.coastMs` as the interval, and then reads a token with the same
    // reachable zero, so the argument is finished here instead. Fifty
    // milliseconds is three frames at sixty hertz: longer than any gap inside
    // one continuous stream and shorter than a human pause, so the floor can
    // only ever be reached by a configuration that has already given up on the
    // question. Clamping in Config was the other option and is the integrator's
    // to make; a component that silently stops working when a number it does not
    // own goes to zero should not be waiting on that.
    readonly property int lapseFloor: 50

    // The fingers stopped sending: they lifted, or they stopped moving and are
    // still resting there, and this cannot tell those apart. GlideList's timer
    // and GlideList's interval, under the floor above; see the header both for
    // why a lapse is the only end available and for what the second silence
    // costs the gesture it ends.
    Timer {
        id: coast

        interval: Math.max(root.lapseFloor, Appearance.anim.fast)

        onTriggered: root.finish()
    }
}
