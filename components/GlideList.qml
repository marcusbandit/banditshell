import QtQuick
import qs.config

// A list that GLIDES.
//
// Qt's own wheel handling on a Flickable is a hard jump per notch: the content
// is simply somewhere else on the next frame, the eye has nothing to follow, and
// a wheel-scrolled list reads as a series of cuts rather than as a movement.
//
// Here a notch moves a TARGET and the content chases it by exponential
// smoothing, which is the same thing every other moving part of this shell does
// (see ~/.claude/rules/animation-smoothing.md). Fast when far, gentle as it
// lands, and notches during a glide extend it instead of restarting it, so a
// hard spin is one long roll rather than a stutter.
//
// Dragging and flicking are left to Flickable, which already has the momentum
// and the rubber band. The two paths cannot fight, because the glide stands down
// while the list is being handled directly and picks the target back up from
// wherever the drag left it.
ListView {
    id: root

    // How far one notch throws the list.
    property real step: Appearance.sizes.rowHeight * Appearance.sizes.wheelRows

    // Where the content is heading.
    property real scrollTarget: 0

    readonly property real maxScroll: Math.max(0, contentHeight - height)

    // DRAGGING ONLY, not `dragging || flicking`. `flicking` is also set when
    // Flickable runs its own bounds fixup, which it does in response to the
    // glide's own writes to contentY, so keying off it meant every glide
    // retriggered the resync below and pulled the target back to where the
    // content had got to. The scroll decayed to a stop a few rows in.
    //
    // Nothing has to suppress the glide during a real flick: at the moment the
    // finger lifts the target equals the position, so the glide is settled, its
    // timer is not running, and it writes nothing while Flickable coasts.
    readonly property bool handling: dragging

    // Overshoot on a DRAG, never on the wheel: the rubber band is what makes a
    // list feel physical when you throw it, and pure noise when a notch lands
    // you at an end you were already at.
    boundsBehavior: Flickable.DragAndOvershootBounds
    maximumFlickVelocity: Appearance.sizes.rowHeight * 60

    function scrollTo(y: real): void {
        root.scrollTarget = Math.max(0, Math.min(y, root.maxScroll));
    }

    // Bring a row into view by MOVING THE TARGET, so the keyboard scrolls the
    // list the same way the wheel does rather than teleporting it.
    //
    // Row height comes from the content rather than from a constant, so this
    // stays right for any delegate as long as the rows are uniform, and needs no
    // second place to update when one changes.
    function reveal(index: int): void {
        if (root.count <= 0)
            return;
        const rowHeight = root.contentHeight / root.count;
        const top = index * rowHeight;
        const bottom = top + rowHeight;

        if (top < root.anchor)
            root.scrollTo(top);
        else if (bottom > root.anchor + root.height)
            root.scrollTo(bottom - root.height);
    }

    // Back to the top, with no glide: a new set of results is a new list, and
    // watching it scroll up from where the last one happened to be is motion
    // that means nothing.
    //
    // It must NOT touch glide.target. That property is BOUND to scrollTarget,
    // and assigning to a bound property in QML does not set it for one frame, it
    // destroys the binding for good. reset() runs on every open, because opening
    // clears the query, so one assignment there left the glide permanently
    // pinned to 0: the target moved, the glide agreed it had already arrived,
    // and the list never scrolled again by wheel or by key. Setting scrollTarget
    // is enough; the binding carries it.
    function reset(): void {
        root.scrollTarget = 0;
        glide.value = 0;
        root.contentY = 0;
    }

    onContentHeightChanged: root.scrollTo(root.scrollTarget)

    Follow {
        id: glide

        speed: Appearance.anim.scrollSpeed
        // Half a pixel: below this the difference cannot be drawn, and chasing
        // it forever keeps the timer awake for nothing.
        epsilon: 0.5
        target: root.scrollTarget

        onValueChanged: if (!root.handling)
            root.contentY = value
    }

    // The one place the target is taken FROM the content instead of driving it:
    // a drag or a flick owns the position while it lasts, so the glide stands
    // down as it starts and picks the target back up from wherever it landed.
    //
    // This used to be onMovementEnded, and that was a feedback loop. Flickable
    // reports movement for ANY change to contentY, including the glide's own, so
    // every tick of a glide ended a "movement", which reset the target to the
    // position the glide had just reached, which stopped the glide. The scroll
    // fought itself to a standstill a few rows in and the target came out as a
    // number that corresponded to nothing.
    // Only a real DRAG hands the position back. Flickable emits flickEnded and
    // movementEnded for its own internal animations too, including the ones it
    // runs in response to the glide's writes, so listening to either meant the
    // target was repeatedly reset to wherever the glide had got to and the
    // scroll decayed to a halt somewhere in the middle of the list.
    onDraggingChanged: {
        glide.value = root.contentY;
        root.scrollTarget = root.contentY;
    }

    // Where a new scroll starts FROM.
    //
    // Mid-glide that is the target, so a second notch extends the throw instead
    // of restarting it from the content's current position. Otherwise it is
    // wherever the content actually is, which is what makes a flick's resting
    // place the start of the next scroll without anything having to observe the
    // flick ending.
    readonly property real anchor: glide.settled ? contentY : scrollTarget

    // A wheel and a touchpad are DIFFERENT INPUTS and want opposite treatment.
    //
    // A notch is a discrete request to go somewhere, so it moves the target and
    // the glide carries the eye there. Fingers are a continuous position, so
    // they move the content DIRECTLY: routing them through the same smoothing
    // put a lag between the fingers and the list, which is exactly the thing
    // that makes touchpad scrolling feel like driving something remotely rather
    // than touching it. Both went through the target at first, and on a wheel it
    // felt right for the same reason it felt wrong on a touchpad.
    //
    // The finger path then hands its VELOCITY to the glide when the fingers
    // leave, which is the coast: the list keeps going and eases down instead of
    // stopping dead the instant contact breaks.
    property real velocity: 0
    property real lastEvent: 0

    WheelHandler {
        onWheel: event => {
            event.accepted = true;

            if (event.pixelDelta.y === 0) {
                root.scrollTo(root.anchor - event.angleDelta.y / 120 * root.step);
                return;
            }

            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - root.lastEvent));
            root.lastEvent = now;

            const before = root.contentY;
            root.contentY = Math.max(0, Math.min(root.contentY - event.pixelDelta.y, root.maxScroll));

            // Smoothed, because one event's dt is noisy enough to throw a flick
            // in the wrong direction entirely if the last sample happened to be
            // a straggler.
            const sample = (root.contentY - before) / dt;
            root.velocity += (sample - root.velocity) * 0.4;

            // The glide is sitting exactly where the content is, so it has
            // nothing to pull against until the coast below gives it a target.
            root.scrollTarget = root.contentY;
            glide.value = root.contentY;

            coast.restart();
        }
    }

    // The fingers stopped sending. Either they lifted or they stopped moving,
    // and the coast tells those apart by itself: no movement means no velocity
    // means no throw.
    Timer {
        id: coast

        interval: Appearance.anim.fast
        onTriggered: {
            root.scrollTo(root.contentY + root.velocity * Appearance.sizes.coastMs);
            root.velocity = 0;
        }
    }
}
