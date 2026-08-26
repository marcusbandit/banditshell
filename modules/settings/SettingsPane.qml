pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// One column of the settings page that scrolls: the list of sections is one,
// the section being read is another, and on a wide face they stand side by
// side. Whatever is declared inside lands in `holder` and is slid up and down;
// the pane asks nothing of it except that it have a height.
//
// THE GESTURE IS THE PAGER'S OLD ONE, kept whole. A hand-rolled MouseArea
// BEHIND the content, which is every drag in this shell (DESIGN.md 15): rows
// and switches declared later keep their own presses, and only the quiet parts
// of the page begin a gesture here. Two fingers on a touchpad arrive at the same
// three functions through ScrollGesture, so the two inputs cannot drift into
// two opinions about what a swipe is. The mouse wheel is the one thing declined
// and handed to the WheelHandler below, because a notch has no motion in it to
// track.
//
// THE SECOND AXIS IS "BACK", not "next page". The page used to be a strip of
// every section side by side, swiped between like a carousel, and a carousel
// is the wrong picture for a list you enter and leave: sections are not
// neighbours, they are rooms off one hall. So on a narrow face the horizontal
// axis is the phone's own gesture, a drag to the right that slides the section
// away and shows the list underneath, following the finger the whole way. A
// wide face has the list beside the section already and `backable` is off.
Item {
    id: root

    // Whether a drag to the right means "back". The face sets it per pane and
    // per shape; the pane only reports.
    property bool backable: false

    // Air the content keeps clear at the bottom, for the corner grip the
    // face draws over this pane's foot on the shell's copy.
    property real inset: 0

    default property alias content: holder.data

    // THE SCROLL: a target chased by a Follow, GlideList's glide idiom, because
    // the content is arbitrary rows rather than a uniform ListView. Wheel
    // notches and the drag both move the target; the content follows.
    property real target: 0
    readonly property real position: flow.value
    readonly property real limit: Math.max(0, holder.childrenRect.height + holder.childrenRect.y + root.inset - root.height)

    // HOW FAR THE HAND HAS PULLED THE PANE BACK, as a fraction of its width,
    // and whether it is doing so right now. The face draws the pane at the
    // hand's offset while `backing` is true and hands the number to its own
    // smoother on release, which is the Follow handover every gesture here
    // makes.
    readonly property bool backing: swipe.backing
    readonly property real backFraction: Math.max(0, Math.min(1, swipe.backX / Math.max(1, root.width)))

    // The release. `committed` says whether it was far enough or fast enough
    // to count; the face decides what "back" means.
    signal backed(bool committed)

    clip: true

    function scrollTo(y: real): void {
        root.target = Math.max(0, Math.min(y, root.limit));
    }

    // The finger owns the position while it is down: value and target move
    // together, so nothing smooths between hand and content.
    function drag(y: real): void {
        root.scrollTo(y);
        flow.value = root.target;
    }

    // The lift's velocity spent as distance. `v` is in pixels per
    // MILLISECOND: coastMs is milliseconds of the velocity the drag ended at,
    // so only a per-ms figure multiplies against it into pixels.
    function coast(v: real): void {
        root.scrollTo(flow.value + v * Appearance.sizes.coastMs);
    }

    // Content that SHRANK under the view would otherwise leave the pane parked
    // past its own end, which looks like the rows scrolled off the top.
    onLimitChanged: root.scrollTo(root.target)

    Follow {
        id: flow

        target: root.target
        speed: Appearance.anim.scrollSpeed
        epsilon: 0.5
    }

    MouseArea {
        id: swipe

        // Parent-frame anchors, Pull's invariant: `x + mouse.x` is the pointer
        // whether or not this area is ever given geometry of its own.
        property real anchorX: 0
        property real anchorY: 0
        property real fromScroll: 0

        // Which axis won, decided ONCE per gesture. `spent` is a horizontal
        // drag on a pane that has no horizontal meaning: it does nothing, and
        // it must not become a scroll halfway through either.
        property bool scrolling: false
        property bool backing: false
        property bool spent: false

        // The back drag's offset in pixels, and the smoothed velocity of
        // whichever axis is live. The velocity's UNIT depends on the axis, the
        // pager's old arrangement: scrolling is per millisecond (coastMs is
        // written in that), backing is per event (flickVelocity is written in
        // that). Only one axis is ever live, so one property wears both.
        property real backX: 0
        property real velocity: 0
        property real lastEvent: 0

        anchors.fill: parent

        function begin(): void {
            // A GESTURE ARRESTS WHATEVER IS MOVING before anything is
            // measured, so the origin captured below is the truth of what the
            // hand is holding rather than a photograph of a moving thing.
            root.drag(root.position);
            swipe.fromScroll = root.position;
            swipe.scrolling = false;
            swipe.backing = false;
            swipe.spent = false;
            swipe.backX = 0;
            swipe.velocity = 0;
            swipe.lastEvent = Date.now();
        }

        function advance(dx: real, dy: real): void {
            if (swipe.spent)
                return;
            if (!swipe.scrolling && !swipe.backing) {
                if (Math.abs(dx) < Appearance.sizes.dragThreshold && Math.abs(dy) < Appearance.sizes.dragThreshold)
                    return;
                if (Math.abs(dy) > Math.abs(dx))
                    swipe.scrolling = true;
                else if (root.backable && dx > 0)
                    swipe.backing = true;
                else {
                    swipe.spent = true;
                    return;
                }
            }

            if (swipe.scrolling) {
                // Sampled in pixels per millisecond, dt clamped the way
                // GlideList clamps it: a floor so a burst inside one tick
                // cannot divide toward infinity, a ceiling so a step after a
                // pause is not crushed toward zero.
                const now = Date.now();
                const dt = Math.max(1, Math.min(100, now - swipe.lastEvent));
                swipe.lastEvent = now;
                const before = root.position;
                root.drag(swipe.fromScroll - dy);
                swipe.velocity += ((root.position - before) / dt - swipe.velocity) * 0.4;
                return;
            }

            // Clamped at zero: there is nothing to the left of "back", and
            // pulling the pane the wrong way with nothing under it reads as
            // tearing rather than resisting.
            const next = Math.max(0, dx);
            swipe.velocity += (next - swipe.backX - swipe.velocity) * 0.4;
            swipe.backX = next;
        }

        function settle(meant: bool): void {
            if (swipe.backing) {
                // MOMENTUM before position, Pull's own release rule: a flick
                // is an intention expressed as speed, so it goes back however
                // little ground it covered, and only a slow release asks how
                // far it got. Past the commit fraction it stands regardless.
                const thrown = swipe.velocity >= Appearance.sizes.flickVelocity;
                const far = root.backFraction >= Appearance.sizes.pullCommit;
                swipe.backing = false;
                root.backed(meant && (thrown || far));
            } else if (swipe.scrolling && meant) {
                root.coast(swipe.velocity);
            }
            swipe.scrolling = false;
            swipe.spent = false;
        }

        onPressed: mouse => {
            // A press takes the gesture over cleanly: a stream still running
            // when a hand lands is concluded by its own rule first.
            scroll.finish();
            swipe.anchorX = swipe.x + mouse.x;
            swipe.anchorY = swipe.y + mouse.y;
            swipe.begin();
        }

        onPositionChanged: mouse => {
            if (swipe.pressed)
                swipe.advance(swipe.x + mouse.x - swipe.anchorX, swipe.y + mouse.y - swipe.anchorY);
        }

        onReleased: swipe.settle(true)
        onCanceled: swipe.settle(false)

        // A touchpad stream is a press, a total is a delta, and a lapse is a
        // release. What the primitive declines (a mouse wheel, a stream under
        // a held press) is answered HERE, on this area's own wheel signal,
        // rather than by a WheelHandler on the pane: the two inputs then
        // arrive at one item and are ordered against the rows above by
        // declaration alone, which is how Pull and Slider already take the
        // wheel. A notch scrolls by GlideList's own step; the pixel branch
        // answers a touchpad scroll the gesture declined because a press was
        // already down.
        onWheel: wheel => {
            if (scroll.feed(wheel))
                return;
            wheel.accepted = true;
            const step = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * Appearance.sizes.rowHeight * Appearance.sizes.wheelRows;
            root.scrollTo(root.target - step);
        }

        ScrollGesture {
            id: scroll

            armed: !swipe.pressed

            onBegan: swipe.begin()
            onMoved: (dx, dy) => swipe.advance(dx, dy)
            onEnded: swipe.settle(true)
        }
    }

    Item {
        id: holder

        width: root.width
        y: -root.position
    }

}
