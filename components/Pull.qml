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

    // Far enough to be a gesture rather than the wobble inside a click. The same
    // number the bottom edge uses, because it is the same question being asked
    // of the same hand.
    readonly property real slack: Appearance.padding.large

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
    // often as it is direction.
    property real fromX: 0
    property real fromY: 0
    property bool pulling: false
    property bool spent: false
    property real velocity: 0
    property real lastProj: 0
    property real progress: 0

    preventStealing: true

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

        // The origin is kept in the PARENT's coordinates. `mouse.x` is relative
        // to this item, and this item is anchored to an edge or a corner while
        // its own width and height follow a hover swell, so its top-left MOVES
        // during the gesture: a raw `mouse.x` would drift by exactly that much
        // for a pointer that never went anywhere. `root.x + mouse.x` is the
        // invariant, which is the same lesson the notification card records
        // (DESIGN.md 15).
        root.fromX = root.x + mouse.x;
        root.fromY = root.y + mouse.y;
        root.pulling = false;
        root.spent = false;
        root.velocity = 0;
        root.lastProj = 0;
        root.progress = 0;
    }

    onPositionChanged: mouse => {
        if (!root.pressed || root.spent)
            return;

        // Parent coordinates again, for the reason the press records them.
        const dx = root.x + mouse.x - root.fromX;
        const dy = root.y + mouse.y - root.fromY;
        // How far along the gesture's own direction you have actually
        // travelled, which is not how far you have moved.
        const proj = dx * root.ux + dy * root.uy;
        const dist = Math.hypot(dx, dy);

        if (!root.pulling) {
            // Still inside the wobble of a click, so nothing is decided yet.
            if (dist < root.slack)
                return;

            // The direction is decided ONCE, here, at the moment the press
            // becomes a gesture. `proj / dist` is the cosine of the angle
            // between where you went and the direction this pull is for, so a
            // gesture that set off across it fails this test and is spent: it is
            // not this pull, and it must not be allowed to become one later by
            // curving round. Testing the angle continuously instead would mean
            // the volume rail could lose a swipe it had already started.
            //
            // A spent gesture then does nothing at all on release, which is
            // deliberate: it is neither a pull nor a tap, because whatever it
            // was aimed at, it was not this.
            if (proj / dist < root.cosLimit) {
                root.spent = true;
                return;
            }

            root.pulling = true;
            root.lastProj = proj;
        }

        // Smoothed the same way, with the same constant, as the bottom edge.
        const step = proj - root.lastProj;
        root.lastProj = proj;
        root.velocity += (step - root.velocity) * 0.4;

        root.progress = Math.max(0, Math.min(proj / root.travelFull, 1));
        root.pulled(root.progress);
    }

    onReleased: {
        // Which way it goes is decided by MOMENTUM rather than by position,
        // because position asks "did you drag far enough" and momentum asks
        // "which way were you going", and only the second one is a question
        // about intent.
        if (root.pulling)
            root.finished(root.velocity >= 0);
        else if (!root.spent)
            // Consumers answer THIS and never MouseArea's own `clicked`.
            // `clicked` still fires for a press that set off across the
            // direction and wandered back, which is the one case that has to do
            // nothing at all; this signal is the one that knows the difference.
            root.tapped();

        root.pulling = false;
        root.spent = false;
    }

    onCanceled: {
        if (root.pulling)
            root.finished(false);
        root.pulling = false;
        root.spent = false;
    }
}
