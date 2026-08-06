import QtQuick
import qs.config

// A directional drag: the way in that needs no hover, and the way back out.
//
// It began as a corner, and the corner's argument is still the clearest one. A
// corner is the cheapest target a pointing device has: it is the one place you
// can throw the cursor at full speed and be certain of arriving, because two
// screen edges stop it for you (Fitts). That argument is entirely about a
// cursor, though. A touchscreen has no hover at all, so a corner that only
// answers a hovering pointer answers a finger with nothing, and the corner that
// was the easiest thing on the screen to hit becomes the only thing that cannot
// be used.
//
// This is the second way in. Put a finger or the cursor where the thing lives
// and push away from there, roughly along the direction the caller names, and
// what lives there comes out with you. It tracks the whole way, so you can see
// how much you have pulled out and decide halfway through that you did not want
// it: reverse while still holding and it goes back. Reversible right up until
// you let go is what makes it a drag rather than a switch (DESIGN.md 15).
//
// AND THE THIRD WAY IN IS TWO FINGERS, which every consumer got for nothing.
//
// A touchpad has no press to spare for a gesture like this. Two fingers moving
// is the whole of what a hand does on one, and it is the motion a laptop makes
// where a touchscreen would swipe, so a swipe that only answers a held button is
// a swipe that does not exist on the machine this shell is used on most. A
// scroll is therefore answered with exactly the machinery a drag is answered
// with, through components/ScrollGesture.qml: it turns a touchpad stream into
// the same "how far from where it began" a press-drag reports, and it refuses a
// mouse wheel outright, because a wheel already means volume on one edge and
// scrolling nearly everywhere else it could land. Everything that consumes this
// file inherited the gesture the day the primitive went in, which is the whole
// argument for putting it HERE rather than at each site: the settings corner,
// the tray, the notch, the launcher and the menus were already saying which way
// their gesture runs, and that direction is the only thing the scroll path
// needed to be told.
//
// TWO DIFFERENCES FROM THE DRAG PATH, both of them absences, and both worth
// stating because an absence reads as an oversight to whoever comes next. There
// is no press, so `tapped` can never fire from a scroll: nothing was tapped, and
// a stream that travelled nowhere is a stream that did nothing rather than a
// click that missed. And there is no origin to keep in the parent's frame,
// because there is no `mouse.x` to be relative to anything: a scroll reports
// MOTION and never a position, so the drift the anchor dance below exists to
// cancel (this item's own top-left moving under a pointer that did not move)
// cannot arise on that path at all.
//
// AND IT RUNS BOTH WAYS, which is why this is the ONE directional drag in the
// shell rather than a corner widget. Pushing a panel back into the edge it came
// out of is not a second gesture: it is this one with the direction reversed,
// the same slack, the same angle gate and the same momentum on release, pointed
// the other way. That is precisely why the direction is a vector the CALLER
// supplies rather than something the component infers from a corner it was told
// to sit in. The component cannot know whether it is summoning something or
// putting it away, and it does not have to: both are "push along this vector",
// and only the consumer knows which way that points today.
//
// Deliberately NOT a DragHandler. Every drag in this repo is hand-rolled on a
// MouseArea, because Qt's built-in drag assigns `x` imperatively, which destroys
// the binding that was driving it and then fights whatever re-establishes it
// (DESIGN.md 15). This one never touches anyone's geometry: it tracks the
// pointer and hands out a fraction, and the consumer's own bindings are left
// alone to decide what that fraction means.
//
// WHERE TO PUT IT MATTERS once the consumer is a panel rather than an empty
// corner, and there are two separate rules about it.
//
// THE FIRST IS ABOUT WHAT IS UNDERNEATH. In a corner there is nothing to
// protect, so this can sit on top. Over a panel's contents it must go behind
// them, so it still covers the whole surface and the gesture can start anywhere
// on it, but the buttons keep their own clicks and only the empty parts of the
// panel begin a push. Declaration order is input order in QML, so simply
// declaring this BEFORE the contents is enough and is what the consumers do.
//
// FOR THE PRESSES. It is deliberately not enough for the scrolls, and that
// sentence used to be written here as though it covered both. A press lands on
// exactly one item, so being declared first hides this from every child without
// any child knowing it exists; a wheel walks DOWN the stack until something
// accepts one, so being declared first hides this only from the children that
// accept wheels. A child that takes presses and not wheels, which is most plain
// controls, leaks its scrolls straight to this item, and the two inputs then
// disagree on that child in the worst available direction: the drag does nothing
// there and the scroll moves the whole panel. A scrollable child is fine, since
// scrolling is exactly what it accepts wheels for; a button, a row or a text
// field is not, and has to own the wheel it is standing on (DESIGN.md 15). The
// consumers that get this right today are the ones whose contents are a list;
// the ones that do not are named in that section rather than quietly fixed here,
// because a Pull cannot reach into somebody else's row and take an event it has
// no way to know the row wanted.
//
// THE SECOND IS ABOUT WHAT IS ABOVE, and it is the one that bites. THIS ITEM'S
// PARENT MUST NOT MOVE WHILE THE GESTURE RUNS. The anchor below is kept as
// `root.x + mouse.x`, which is the parent's frame, and that survives THIS item
// moving or resizing inside a still parent: `root.x` rises by d, `mouse.x` falls
// by d, the sum does not change. It does NOT survive the PARENT moving. A parent
// that translates by d shifts `mouse.x` by -d with nothing compensating, so the
// delta reported for a finger that never went anywhere is whatever the parent
// did last frame, and the gesture dissolves into noise.
//
// That rules out the obvious placement, which is inside the panel being pushed:
// the panel is precisely the thing the gesture moves, so it would be measuring
// itself against its own effect. Every consumer here therefore declares this as
// a SIBLING of the panel, just before it, wearing the panel's geometry:
//
//     Pull { x: panel.x; y: panel.y; width: panel.width; height: panel.height }
//
// Same rectangle, same input order, and a parent that holds still. A scaled
// parent is worse again, because it rescales the child's coordinates as well as
// shifting them; the settings card scales about its own corner as it emerges,
// which is a second reason its push lives outside it.
//
// One component covers every direction. `dirX` and `dirY` are a vector rather
// than a pair of corner signs, so the gesture is written once against a unit
// vector rather than once per corner with the signs flipped by hand and then
// again per edge with a different pair of axes
// (~/.claude/rules/math-over-hardcoding.md).
MouseArea {
    id: root

    // The direction the gesture has to travel, in this item's own coordinates,
    // and the only thing here that says what this pull is FOR. `(-1, -1)` is a
    // bottom-right corner's inward diagonal, `(0, 1)` is straight down into the
    // bottom edge, `(-1, 0)` is leftward into the sidebar, and anything in
    // between is as valid as those three. NOT required to be normalised: see
    // `ux` for why the caller is spared that.
    required property real dirX
    required property real dirY

    // HOW FAR A FULL PULL IS, in pixels, given rather than derived, and the two
    // kinds of consumer want genuinely different answers.
    //
    // A gesture that SUMMONS something measures against the surface, because
    // there is nothing on screen yet to measure against: the thing being pulled
    // out does not exist until the pull is over, so a fraction of the screen's
    // diagonal is the only honest scale, and the same physical swipe means
    // "commit" wherever in the shell it is made.
    //
    // A gesture that PUTS SOMETHING AWAY measures against the panel, because the
    // panel is right there under the finger and the whole point is that its edge
    // tracks the hand: a launcher eight hundred pixels tall that had gone the
    // moment a finger travelled two hundred and seventy would be a switch
    // dressed as a drag, closing under a hand that had not got anywhere near
    // pushing it down. So it passes its own height, and one finger-length of
    // panel is one finger-length of travel.
    //
    // Only the caller knows which of those it is, so only the caller can say.
    // `Appearance.sizes.pullTravel` is the fraction the summoning ones apply;
    // this property is the answer, not the input.
    required property real travel

    // Whether the gesture is worth offering at all. Pointless while the thing it
    // opens is already open.
    property bool armed: true

    // How far out, 0 to 1, on every move once it is a pull.
    signal pulled(real fraction)
    // Let go: true carries on, false puts it back.
    signal finished(bool open)
    // A press that never became a pull and never went the wrong way.
    signal tapped

    // Far enough to be a gesture rather than the wobble inside a click, and NOT
    // A PIXEL FURTHER. This read a padding tier, twenty-four pixels, on the
    // argument that it was the number the bottom edge already used; a layout
    // tier is the wrong unit for a feel question, and twenty-four was where
    // half the dead feel lived. A short flick ended inside the slack and did
    // nothing at all, and a long pull spent its first inch unacknowledged, the
    // hand already moving and the surface still pretending nothing had begun.
    // Recognition is what STARTS the tracking, and tracking is the entire
    // signal that the gesture is working, so recognition has to come as early
    // as telling a pull from a click's wobble allows.
    readonly property real slack: Appearance.sizes.pullSlack

    // Floored, because the progress below divides by it and a panel measured
    // while it still has no height would hand it a zero.
    readonly property real travelFull: Math.max(1, root.travel)

    // How far either side of `dir` still counts as this gesture. A property
    // rather than a fixed read, because how much room there is to spend
    // depends on where the gesture starts: a corner has ninety degrees of
    // "into the screen" to divide up and an edge has a hundred and eighty,
    // so the same tolerance is stingy in one place and greedy in the other.
    property real angle: Appearance.sizes.pullAngleCorner

    // The direction gate, kept as a cosine so the test on every move is a dot
    // product rather than a call into trigonometry.
    readonly property real cosLimit: Math.cos(root.angle * Math.PI / 180)

    // The direction, normalised. ONE expression that serves a corner's diagonal,
    // an edge's normal and everything between: the DIRECTION is data, not a
    // branch. This used to divide by Math.SQRT2, which was right only because
    // every caller happened to be a corner and every corner's diagonal is the
    // same length; the moment a caller pointed straight down that constant was
    // simply wrong. Dividing by the vector's own length costs one hypot per
    // change and buys the thing worth having: a caller writes the direction the
    // way it READS, `(0, 1)` for down and `(-1, -1)` for a corner, rather than
    // the way the arithmetic wants it, and the component does the dividing.
    //
    // The floor is there so a caller that has not filled the vector in yet, or
    // has computed `(0, 0)` from some binding mid-flight, gets a dot product of
    // zero rather than a NaN. Zero fails the gate and the gesture is simply
    // refused; NaN would fail every comparison silently and look like a dead
    // MouseArea.
    readonly property real dirLen: Math.max(0.0001, Math.hypot(root.dirX, root.dirY))
    readonly property real ux: root.dirX / root.dirLen
    readonly property real uy: root.dirY / root.dirLen

    // Where the press started, whether it has become a pull, whether it has
    // already disqualified itself, and which way it is going. The velocity is
    // smoothed, because the last single event before a finger lifts is noise as
    // often as it is direction, and it is kept in pixels per MILLISECOND, not
    // per event, because the release below compares its MAGNITUDE against
    // `pullReversal`. A magnitude in px per event is really px times the
    // device's event rate, and that rate spans nearly an order of magnitude
    // across ordinary pointing hardware, so the same deliberate put-back would
    // have counted as a change of mind from a touchpad and as lift-off noise
    // from a 1000Hz mouse, whose steps are small precisely because they are
    // frequent. Dividing each step by its own elapsed time is what GlideList and
    // the settings pager's scroll axis already do, for the same reason: only
    // time divides the event rate back out.
    //
    // THE BOTTOM EDGE IS ON THE CLOCK TOO NOW, and this paragraph used to say
    // the opposite: that LaunchEdge smoothed a per-event step and was right to,
    // because it only ever read the SIGN and no unit can change a sign. That
    // was true when it was written and stopped being true when that edge started
    // comparing its velocity against `pullReversal` as well; it divides by its
    // own dt today and says so at its own `advance`. The sentence is corrected
    // rather than deleted because the ARGUMENT in it is still the one that
    // decides the question: a sign survives any unit, a magnitude does not, so
    // the moment a number is thresholded it has to be measured against the clock.
    //
    // AND THE TOKEN IS NOW READ IN A UNIT IT WAS NOT TUNED IN, which is the
    // integrator's to settle and this file's to state plainly. `pullReversal` is
    // 3, and both readers of it are per millisecond, so the clause asks for a
    // sustained backward motion of three pixels every millisecond. Driven
    // through this component's own scroll path, a violent put-back of ninety
    // pixels per event reached a smoothed -2.6 and did not clear it, and a
    // deliberate slow one settled around -0.15, so the clause is very hard to
    // reach by hand and past the commit point is close to never taken. What
    // still closes a committed pull, and was measured doing it, is dragging it
    // back under `pullCommit`. Nothing is silently converted here: a per-event
    // number reinterpreted as a speed would be about sixteen times too large,
    // and the arithmetic to undo that belongs in the token rather than in a
    // divisor hidden at one of its two readers.
    //
    // The origin is the DRAG PATH'S ALONE and everything under it is shared. A
    // scroll has no place to have started from, only motion since it did, so
    // these two are the whole of what the second input leaves untouched.
    property real fromX: 0
    property real fromY: 0
    property bool pulling: false
    property bool spent: false
    property real velocity: 0
    property real lastProj: 0
    // When the last step landed, so its dt can be measured: a velocity in
    // real time needs real time.
    property real lastEvent: 0
    property real progress: 0

    preventStealing: true

    // THE GESTURE ITSELF, in three functions rather than inside the press
    // handlers, so the drag path and the scroll path RUN the same machinery
    // instead of merely agreeing about it. A second copy would drift, and this
    // is the copy with every hard-won correction in it: the direction judged
    // once, the velocity divided by its own dt, the commit rule's allowance for
    // lift-off recoil. Two inputs, one gesture, one place to fix it.
    //
    // The split falls exactly where the two inputs differ, which is only the
    // origin: a press has a place and has to remember it, a scroll has motion
    // and nothing to remember. Everything after the subtraction is common.

    // A new gesture. Everything the press used to zero, and nothing about where
    // it started, because that is the one thing the two inputs do not share.
    function begin(): void {
        root.pulling = false;
        root.spent = false;
        root.velocity = 0;
        root.lastProj = 0;
        root.lastEvent = Date.now();
        root.progress = 0;
    }

    // One step, given how far the gesture has travelled IN TOTAL since it
    // began. Totals rather than steps, because the slack test and the progress
    // are both questions about the whole journey, and because a path that
    // reported steps would have to keep its own running sum, which is this
    // subtraction written a second time somewhere it can go stale.
    function advance(dx: real, dy: real): void {
        if (root.spent)
            return;

        // How far along the gesture's own direction you have actually
        // travelled, which is not how far you have moved.
        const proj = dx * root.ux + dy * root.uy;
        const dist = Math.hypot(dx, dy);

        if (!root.pulling) {
            // Still inside the wobble of a click, so nothing is decided yet.
            if (dist < root.slack)
                return;

            // The direction is decided ONCE, here, at the moment the press or
            // the stream becomes a gesture. `proj / dist` is the cosine of the
            // angle between where you went and the direction this pull is for,
            // so a gesture that set off across it fails this test and is spent:
            // it is not this pull, and it must not be allowed to become one
            // later by curving round. Testing the angle continuously instead
            // would mean the volume rail could lose a swipe it had already
            // started.
            //
            // A spent gesture then does nothing at all at the end, which is
            // deliberate: it is neither a pull nor a tap, because whatever it
            // was aimed at, it was not this. On the scroll path it is also what
            // hands the rest of the stream on: see the wheel handler.
            if (proj / dist < root.cosLimit) {
                root.spent = true;
                return;
            }

            root.pulling = true;
            root.lastProj = proj;
        }

        // Smoothed the same way, with the same constant, as the bottom edge,
        // and divided by its own dt so the unit is px per ms: see `velocity`
        // for why a magnitude the release will threshold cannot stay in
        // per-event units. The dt clamp is GlideList's, both ends of it: a
        // floor of one so a burst of events landing inside the same
        // millisecond cannot divide toward infinity, a ceiling of a hundred
        // so the first step after the slack, or after a mid-pull pause, reads
        // as slow rather than being spread over a stale timestamp.
        const now = Date.now();
        const dt = Math.max(1, Math.min(100, now - root.lastEvent));
        root.lastEvent = now;
        const step = proj - root.lastProj;
        root.lastProj = proj;
        root.velocity += (step / dt - root.velocity) * 0.4;

        root.progress = Math.max(0, Math.min(proj / root.travelFull, 1));
        root.pulled(root.progress);
    }

    // The end, however the input announced it: a lifted button, or a touchpad
    // stream that stopped sending. What follows is the same question either
    // way, which is the point of the whole refactor.
    function settle(): void {
        // Which way it goes is decided by MOMENTUM rather than by position,
        // because position asks "did you drag far enough" and momentum asks
        // "which way were you going", and only the second one is a question
        // about intent.
        //
        // But momentum alone read the answer at the WORST MOMENT OF THE
        // GESTURE. The lift is the noisiest instant there is: a finger peeling
        // off a surface drags the contact point backward as it goes, so the
        // velocity of a flick that had obviously happened could arrive here a
        // hair negative, and the clearest gesture a hand can make was being
        // answered with the panel bouncing home. So past the commit point the
        // question changes. A pull that has already covered `pullCommit` of
        // its travel has said what it wants, and only a SUSTAINED backward
        // motion, a real change of mind rather than lift-off recoil, takes it
        // back: the velocity has to beat `pullReversal`, not merely be
        // negative. The smoothed velocity is already the right measurand for
        // that distinction, because smoothing is precisely what separates
        // sustained motion from one noisy event; a raw last-event delta could
        // not tell them apart no matter where the threshold sat. And the
        // comparison only means one thing across devices because the velocity
        // is measured against the clock rather than against the event stream:
        // see `velocity` for the unit argument. Before the
        // commit point nothing changes: a pull abandoned early still goes
        // wherever it was travelling, which is what keeps this a drag rather
        // than a switch with a long throw.
        if (root.pulling)
            root.finished(root.velocity >= 0
                || (root.progress >= Appearance.sizes.pullCommit
                    && root.velocity > -Appearance.sizes.pullReversal));

        root.pulling = false;
        root.spent = false;
    }

    // THE DRAG PATH: a press, its origin, and the release.

    onPressed: mouse => {
        // NOT disabled when unarmed. Disabling a MouseArea mid-gesture tears
        // down the grab it is holding, and the gesture that unarms this one is
        // the gesture that opens what this is hiding: the release would arrive
        // at a dead item. It rejects the press instead, which lets it fall
        // through to whatever is now covering this zone.
        if (!root.armed) {
            mouse.accepted = false;
            return;
        }

        // A PRESS TAKES THE GESTURE OVER, and takes it over cleanly. Both paths
        // write one set of state, so a stream still running when a hand lands
        // has to be concluded before the press touches any of it: concluded by
        // its own rule, so a pull that two fingers had half-opened is ANSWERED
        // rather than abandoned halfway with nothing ever arriving to say which
        // way it went. Left alone instead, the stream would also still hold a
        // total measured from where the fingers began, and the first scroll
        // event after the release would hand that stale distance to a state the
        // press had since zeroed, jumping the gesture the whole way in one step.
        // After this the press owns everything, which is what the wheel handler
        // below enforces for as long as it is down.
        scroll.finish();

        // The origin is kept in the PARENT's coordinates. `mouse.x` is relative
        // to this item, and this item is anchored to an edge or a corner while
        // its own width and height follow a hover swell, so its top-left MOVES
        // during the gesture: a raw `mouse.x` would drift by exactly that much
        // for a pointer that never went anywhere. `root.x + mouse.x` is the
        // invariant, which is the same lesson the notification card records
        // (DESIGN.md 15). It is also the whole of what the scroll path does
        // without: see the header.
        root.fromX = root.x + mouse.x;
        root.fromY = root.y + mouse.y;
        root.begin();
    }

    // Parent coordinates again, for the reason the press records them.
    onPositionChanged: mouse => {
        if (root.pressed)
            root.advance(root.x + mouse.x - root.fromX, root.y + mouse.y - root.fromY);
    }

    onReleased: {
        // The TAP lives here rather than in settle(), because it is the one
        // thing on this path that the other path cannot have: a scroll has no
        // press to have been a click instead, so a stream that never became a
        // pull did nothing at all rather than tapping something.
        //
        // Consumers answer THIS and never MouseArea's own `clicked`. `clicked`
        // still fires for a press that set off across the direction and
        // wandered back, which is the one case that has to do nothing at all;
        // this signal is the one that knows the difference.
        if (!root.pulling && !root.spent)
            root.tapped();

        root.settle();
    }

    onCanceled: {
        // Not settle(): a cancel is not a release. The grab was taken away
        // rather than let go, so there is no intent in it to read a momentum
        // out of, and it always goes back.
        if (root.pulling)
            root.finished(false);
        root.pulling = false;
        root.spent = false;
    }

    // THE SCROLL PATH: two fingers, answered as the same swipe. See the header.
    //
    // Fed from this MouseArea's OWN wheel signal rather than from a handler
    // parked inside it, so both inputs arrive at the same item and are ordered
    // against everything else by the one rule this component already lives by:
    // declaration order. That matters most where it is deliberately BEHIND a
    // list (the launcher's results, a menu's rows), because there the list is
    // above it and takes the scrolls meant for scrolling before this ever sees
    // them, exactly as it already takes the presses meant for its rows.
    onWheel: wheel => {
        // A PRESS OWNS THE GESTURE WHILE IT LASTS. Both paths write one set of
        // state, so a scroll arriving mid-drag would be two inputs steering the
        // same pull from two origins; the press is the more deliberate of them
        // and keeps it. Refusing rather than ignoring, so the scroll reaches
        // whatever else might want it.
        //
        // `spent` is spelled in here rather than left to the primitive: a
        // stream this pull has judged to be crossing its direction is not this
        // gesture, and from that moment it should fall through, exactly as an
        // unarmed press does. The events BEFORE the judgement are consumed
        // either way, which is the drag path's behaviour too; a gesture cannot
        // be handed on until it is known not to be yours.
        wheel.accepted = !root.pressed && scroll.feed(wheel) && !root.spent;
    }

    ScrollGesture {
        id: scroll

        // The same gate the press applies, with the same meaning: it refuses to
        // START one and lets a running one finish.
        armed: root.armed

        // The whole adoption, three lines, which is the point of the primitive:
        // a stream is a press, a total is a delta, and a lapse is a release.
        // Unguarded, because a press concludes any stream in flight before it
        // touches the state (see onPressed), so an ending can never arrive at a
        // pull that something else is holding.
        onBegan: root.begin()
        onMoved: (dx, dy) => root.advance(dx, dy)
        onEnded: root.settle()
    }
}
