import QtQuick
import qs.config
import qs.components

// The bottom edge, as a way in.
//
// A phone has a gesture bar there and everyone already knows what it is for, so
// the shell does the same thing with the band it already has: put the cursor on
// the bottom of the screen and it swells a little, click it and the launcher
// comes up, or push up from it and it comes up WITH you.
//
// The push is the whole point of it. It is not a switch that happens to be
// operated by a drag: the panel's top edge tracks the pointer the entire way, so
// you can see how much of it you have pulled out and decide halfway through that
// you did not want it. Reverse while still holding and it goes back down. Which
// way it goes on release is decided by MOMENTUM rather than by position, because
// position asks "did you drag far enough" and momentum asks "which way were you
// going", and only the second one is a question about intent.
//
// AND TWO FINGERS PUSH IT TOO, which is the user's own example of the rule the
// whole shell now lives by: put the pointer where you would normally swipe up
// from, scroll up with two fingers, and the launcher comes up with them. A
// touchpad has no screen edge to put a finger on and no third hand to hold a
// button down while it swipes, so a way in that only answers a held press is a
// way in that does not exist on the machine this shell is used on most.
//
// The scroll gets the SAME gesture rather than a second opinion about what a
// swipe is: the same slack, the same fraction handed out the whole way, the
// same reversibility, the same commit rule at the end. That is bought by
// splitting the gesture out of the press handlers into three functions and
// pointing both inputs at them, which is exactly what components/Pull.qml did
// when it adopted components/ScrollGesture.qml. This edge predates Pull and
// hand-rolls Pull's gesture, so it adopts the primitive directly, for the same
// reason it already reads Pull's tokens: the alternative is a second copy of a
// commit rule that took a long time to get right, drifting quietly away from
// the original, and this file has had to be brought back into step once
// already.
//
// The swell is deliberately small, a hair under the gap the windows already sit
// inside, so it never moves anything and never covers anything. It is the shell
// noticing you rather than the shell interrupting you.
Item {
    id: root

    // The band's own thickness, which the swell is added to rather than replaces.
    required property real border

    // How wide the thing this opens is. The edge is an affordance FOR that
    // thing, so it is exactly as wide: a full-width swell promises that the
    // whole bottom of the screen does something, and it does not.
    required property real span

    // Whether the edge is worth offering at all. Pointless while the thing it
    // opens is already open.
    property bool armed: true

    // A hair under the gap. Big enough to see, small enough that the band never
    // reaches the windows sitting inside that gap.
    readonly property real swellBy: Math.max(1, Appearance.sizes.gap - 1)

    // A full pull is the height the panel will end up at, so the top edge under
    // the pointer is the top edge it will have. Derived from the content area
    // rather than passed in: they are the same number by construction.
    readonly property real travelFull: Math.max(1, root.height - root.border * 2)

    // Far enough to be a drag rather than the wobble in a click. The feel
    // token, the same one Pull reads: this edge predates Pull and hand-rolls
    // the same gesture, so when the shell's recognition distance moved from a
    // padding tier to a feel token, leaving this at twenty-four would have made
    // the bottom edge the one place a short flick still did nothing.
    readonly property real slack: Appearance.sizes.pullSlack

    // How far either side of straight up still counts as a push up this edge,
    // kept as a cosine so the test on every move is a dot product rather than a
    // call into trigonometry. Pull's EDGE tolerance and not its corner one: an
    // edge offers a hundred and eighty degrees of "away from it" to divide up
    // where a corner offers ninety, and this is one of Pull's edges in
    // everything except the year it was written.
    //
    // Read by the SCROLL PATH ALONE, which is deliberate rather than half
    // finished work: see the wheel handler for the whole of that argument.
    readonly property real cosLimit: Math.cos(Appearance.sizes.pullAngleEdge * Math.PI / 180)

    // How tall the thing you have to HIT is, which is not how tall the thing you
    // can SEE is.
    //
    // The swell was doing both jobs and could not: at rest the target was the
    // band alone, ten pixels, and the swell that would have made it bigger only
    // happened once the cursor was already inside those ten pixels. So the first
    // approach that stopped a little short hit nothing, changed nothing, and
    // left the edge exactly as hard to hit as before. Every gesture took two
    // tries, and the second one only worked because the first had parked the
    // cursor low enough to swell it.
    //
    // A target cannot be conditional on having already been hit. This one is
    // constant: at least as tall as the swell it will become, and never under
    // the minimum size anything in this shell is allowed to be.
    readonly property real grab: Math.max(root.border + root.swellBy, Appearance.sizes.minTarget)

    readonly property bool active: root.armed && (zone.containsMouse || zone.pressed)

    // Always in the mask, not only while swollen. At rest the zone is exactly
    // the band, which the chassis already covers, so this costs nothing; while
    // swollen it reaches a few pixels past the band, and without it those pixels
    // would be the only part of the swell you could not touch.
    readonly property Item maskItem: zone

    // A GESTURE HAS STARTED, before anything is known about where it goes.
    //
    // Emitted on the press rather than on the first movement, because what this
    // edge opens depends on what is already open, and that has to be decided
    // once at the start: the panel this pull is for is the panel it has to
    // track, and a launcher that closes halfway through the drag (because the
    // thing it is handing over to has opened) must not move the gesture onto a
    // different panel while a finger is still on the screen.
    //
    // A SCROLL STREAM STARTING COUNTS AS ONE, and the name is the only thing
    // about it that is now slightly wrong. Two fingers have no press, but they
    // have exactly the same need: a stream that set off while the launcher was
    // open must go on driving the panel it set off against even if the launcher
    // closes under it halfway through. The alternative is to leave the consumer
    // deciding per event, which is the bug this signal exists to prevent, made
    // worse by an input that cannot be interrupted by letting go.
    signal pressed
    // How far out the panel has been pulled, 0 to 1.
    signal dragged(real fraction)
    // Let go: true carries on up, false puts it back.
    signal finished(bool open)

    readonly property var blobs: swell.value <= 0.01 ? [] : [
        {
            x: (root.width - root.span) / 2,
            y: root.height - (root.border + swell.value),
            w: root.span,
            h: root.border + swell.value,
            radius: Appearance.sizes.windowRadius
        }
    ]

    Follow {
        id: swell

        target: root.active ? root.swellBy : 0
        speed: Appearance.anim.revealSpeed
        // A fifth of a pixel: this whole motion is nine of them, so the usual
        // half-pixel epsilon would land it visibly short of where it was going.
        epsilon: 0.2
    }

    MouseArea {
        id: zone

        // As wide as what it opens, and following the swell in height so the
        // cursor that caused it stays inside it rather than falling out of the
        // thing it just moved.
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.span
        height: root.grab

        // NOT disabled when unarmed. Disabling a MouseArea mid-gesture tears
        // down the grab it is holding, and the gesture that unarms this one is
        // the gesture that opens the launcher: the release would arrive at a
        // dead item. It rejects the press instead, which lets it fall through to
        // the panel that is now covering this edge.
        hoverEnabled: true
        preventStealing: true

        // Where the press started, whether it has become a drag, which way it
        // is going, and how far it got. The velocity is smoothed, because the
        // last single event before a finger lifts is noise as often as it is
        // direction; the progress is kept for the release's commit clause.
        //
        // The ORIGIN is the drag path's alone and everything under it is
        // shared, which is Pull's own split at Pull's own seam. A scroll has no
        // place to have started from, only motion since it did, so `from` is
        // the whole of what the second input leaves untouched.
        property real from: 0
        property bool pulling: false
        property real velocity: 0
        // The last total travelled, and when it landed. Totals rather than the
        // last raw pointer position, because that is the one shape both inputs
        // can speak: a drag subtracts its origin on the way in and a stream is
        // handed totals already. `lastEvent` is what makes the velocity below a
        // speed rather than a step.
        property real lastUp: 0
        property real lastEvent: 0
        property real progress: 0

        // THE GESTURE ITSELF, in three functions rather than inside the press
        // handlers, so the drag path and the scroll path RUN the same machinery
        // instead of merely agreeing about it. Pull's refactor, at the same
        // seam and for the same reason: a second copy of the commit rule would
        // drift from it, and this is the copy with the recoil allowance in it.

        // A new gesture. Everything the press used to zero, and nothing about
        // where it started, because that is the one thing the two inputs do not
        // share.
        function begin(): void {
            zone.pulling = false;
            zone.velocity = 0;
            zone.lastUp = 0;
            zone.lastEvent = Date.now();
            zone.progress = 0;

            // ON BOTH PATHS, because this is where the consumer decides which
            // panel the gesture is for and it has to decide once. See the
            // signal: a stream is as capable as a press of outliving the state
            // that started it, and rather more so, since there is no button to
            // let go of when the launcher closes under it.
            root.pressed();
        }

        // One step, given how far the gesture has travelled UP IN TOTAL since
        // it began. Up is POSITIVE, because up is the direction that opens this
        // and the sign is what the end reads.
        function advance(up: real): void {
            // Smoothed on every move, before the slack test, because a flick is
            // over almost as soon as it has cleared the slack: a velocity that
            // only started counting once the pull was recognised would arrive
            // at the end with two events of history where the smoothing wants a
            // handful. The pre-slack motion is real motion and belongs in the
            // average.
            //
            // PER MILLISECOND, and it did not use to be. This smoothed a raw
            // per-event step, on the honest argument that only the SIGN of it
            // was ever read and no unit can change a sign. That argument
            // stopped being true the day the end started comparing this number
            // against `pullReversal`: a magnitude in px per event is really px
            // times the device's event rate, and that rate spans nearly an
            // order of magnitude across ordinary pointing hardware, so the same
            // deliberate put-back counted as a change of mind from a touchpad
            // and as lift-off noise from a 1000Hz mouse. Two fingers make it
            // worse again, a scroll stream having a rate that is neither.
            // Dividing each step by its own elapsed time is what Pull, the
            // notification card, GlideList and the settings pager's scroll axis
            // all already do, and it is the only thing that divides the event
            // rate back out. The dt clamp is GlideList's, both ends of it: a
            // floor of one so a burst of events inside the same millisecond
            // cannot divide toward infinity, a ceiling of a hundred so the
            // first step after the slack, or after a mid-pull pause, reads as
            // slow rather than being spread over a stale timestamp.
            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - zone.lastEvent));
            zone.lastEvent = now;
            const step = up - zone.lastUp;
            zone.lastUp = up;
            zone.velocity += (step / dt - zone.velocity) * 0.4;

            if (!zone.pulling && up < root.slack)
                return;

            zone.pulling = true;
            zone.progress = Math.max(0, Math.min(up / root.travelFull, 1));
            root.dragged(zone.progress);
        }

        // The end, however the input announced it: a lifted button, or a
        // touchpad stream that stopped sending.
        //
        // A pull is answered by which way it was travelling, with the same
        // allowance Pull makes: the lift is the noisiest instant of the
        // gesture, a finger peeling off drags the point backward, so past the
        // commit fraction only a SUSTAINED backward motion (beating the
        // reversal speed) still counts as a change of mind. This edge predates
        // Pull and hand-rolls the same gesture, so it reads the same tokens for
        // the same reasons; drifting apart here would make the bottom edge the
        // one place a flick still bounced home off its own recoil.
        //
        // `pullReversal` IS READ HERE AS A SPEED, in pixels per MILLISECOND,
        // because that is the unit the velocity above was moved into and a
        // threshold has to be written in its measurand's own unit. Worth naming
        // rather than left to be inferred, because the token was tuned when
        // this smoothed a per-event step, and the two differ by the device's
        // event rate: a per-event value read as a speed is somewhere around
        // sixteen times too large, which does not shift this threshold so much
        // as delete it, since no hand reverses at three pixels a millisecond and
        // the clause is then true of every put-back ever made. Past the commit
        // point that is a pull which cannot be taken back at all. Retuning the
        // number is the integrator's, not this file's; what this file owes the
        // question is to say plainly which unit it is asking in.
        //
        // THE CLICK IS NOT IN HERE, and that absence is the one thing about
        // this split worth checking twice. A press that never became a pull is
        // a click and a click just opens it; a stream that never became a pull
        // did NOTHING, because there was no press for it to have been instead.
        // Left in here, two fingers brushing the bottom of the screen would
        // open the launcher, which is the shortest possible route to a shell
        // that opens things by itself. It lives in onReleased, where the press
        // that could have been a click is.
        function settle(): void {
            if (zone.pulling)
                root.finished(zone.velocity >= 0 || (zone.progress >= Appearance.sizes.pullCommit && zone.velocity > -Appearance.sizes.pullReversal));
            zone.pulling = false;
        }

        onPressed: mouse => {
            if (!root.armed) {
                mouse.accepted = false;
                return;
            }

            // A PRESS TAKES THE GESTURE OVER, and takes it over cleanly. Both
            // paths write one set of state, so a stream still running when a
            // hand lands is concluded by its own rule before the press touches
            // any of it: a pull two fingers had half-opened is ANSWERED rather
            // than abandoned halfway with nothing arriving to say which way it
            // went, and the stale total it was measuring from cannot be handed
            // to a state the press has since zeroed, which would jump the panel
            // the whole way in one step. Pull's line, for Pull's reason.
            scroll.finish();

            zone.from = mouse.y;
            zone.begin();
        }

        onPositionChanged: mouse => {
            if (zone.pressed)
                zone.advance(zone.from - mouse.y);
        }

        onReleased: {
            // The CLICK lives here rather than in settle(), because it is the
            // one thing on this path that the other path cannot have. See
            // settle() for the whole of that argument.
            if (!zone.pulling)
                root.finished(true);

            zone.settle();
        }

        onCanceled: {
            if (zone.pulling)
                root.finished(false);
            zone.pulling = false;
        }

        // THE SCROLL PATH: two fingers pushed up this band, answered as the
        // same swipe. See the header.
        //
        // Fed from this MouseArea's OWN wheel signal rather than from a handler
        // parked inside it, so both inputs arrive at the same item and are
        // ordered against everything else by the one rule this shell orders
        // input by, which is declaration order. This edge is declared late in
        // ShellWindow and so sits above the panels it opens; the strip it
        // claims is the band and a little of the padding under a panel, and
        // nothing that scrolls reaches into it.
        onWheel: wheel => {
            // A PRESS OWNS THE GESTURE WHILE IT LASTS. Both paths write one set
            // of state, so a scroll arriving mid-drag would be two inputs
            // steering the same pull from two origins; the press is the more
            // deliberate of them and keeps it. Refusing rather than ignoring,
            // so the scroll reaches whatever else might want it.
            //
            // A mouse wheel is refused by feed() itself and falls through
            // exactly as it did before this handler existed, which is what
            // keeps a notch meaning whatever it already meant everywhere.
            //
            // `crossed` is spelled in here rather than left to the primitive,
            // exactly as Pull spells `spent` into its own: a stream that has
            // been judged NOT to be a push up this edge is not this gesture, and
            // from that judgement on it should fall through rather than be
            // eaten.
            // The events BEFORE the judgement are consumed either way, which is
            // the drag path's behaviour too, because a gesture cannot be handed
            // on until it is known not to be yours. Handing on means handing on
            // inside the shell, and it is worth being plain that it does not
            // give the scroll back to the window underneath: this strip is in
            // the compositor mask unconditionally (ShellWindow says why), so a
            // scroll made over it was never the window's to begin with. What
            // the refusal buys is that this edge stops ACTING on it.
            wheel.accepted = !zone.pressed && scroll.feed(wheel) && !scroll.crossed;
        }

        ScrollGesture {
            id: scroll

            // The same gate the press applies, with the same meaning: it
            // refuses to START one and lets a running one finish, because what
            // unarms this edge is usually the gesture it is running.
            armed: root.armed

            // Whether this stream has already been judged not to be a push up
            // this edge. Pull's `spent` under another name and doing Pull's job
            // with it, kept out here on the primitive rather than on the zone
            // because it is the one piece of state the drag path has no use
            // for: see below for why only one of the two inputs is asked.
            property bool crossed: false

            // The adoption: a stream is a press, a total is a delta, and a
            // lapse is a release. Plus the one thing a stream has to say that a
            // press says by existing, which is where it was going.
            onBegan: {
                scroll.crossed = false;
                zone.begin();
            }

            // A STREAM HAS TO SAY WHICH WAY IT IS GOING, and a press does not,
            // which is why this test is on one path and not on both.
            //
            // Whoever presses this band has aimed at it, and the aiming IS the
            // press: there is a click here, so a press that goes nowhere in
            // particular is still a deliberate request to open the launcher.
            // Two fingers arrive over the band without having chosen it. The
            // pointer is simply wherever it was last left, this strip is in the
            // mask unconditionally, and the horizontal total used to be dropped
            // on the floor, so a scroll running mostly sideways with a dozen
            // pixels of upward drift in it reached the recognition distance and
            // summoned the launcher out of a gesture that was never aimed here.
            // The direction is the only evidence a stream carries about whether
            // it meant this edge, so it is the thing that has to be asked.
            //
            // Judged against Pull's edge tolerance so the two agree about what
            // "up this edge" means, and judged only while the pull has not yet
            // latched, because the two tests ask different questions: this one
            // is "is this pointed up at all", the latch inside advance() is
            // "has it gone far enough up", and only the second one starts the
            // surface moving. Once it HAS latched the direction is never asked
            // again, which is Pull's rule for Pull's reason: a gesture already
            // tracking must not be lost by curving away late.
            //
            // Below the slack there is no direction in the numbers, only the
            // noise a resting hand makes, so nothing is decided there and the
            // step still goes through to advance() for its velocity, which is
            // the same pre-slack motion that function deliberately averages in.
            //
            // `-dy` because the primitive reports y DOWNWARD in item
            // coordinates, exactly as a drag does, so this is the same negation
            // the press path writes out as `from - mouse.y`.
            onMoved: (dx, dy) => {
                if (scroll.crossed)
                    return;

                if (!zone.pulling) {
                    const dist = Math.hypot(dx, dy);
                    if (dist >= root.slack && -dy / dist < root.cosLimit) {
                        scroll.crossed = true;
                        return;
                    }
                }

                zone.advance(-dy);
            }
            onEnded: zone.settle()
        }
    }
}
