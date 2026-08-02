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
    readonly property bool handling: dragging || flicking

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

        if (top < root.scrollTarget)
            root.scrollTo(top);
        else if (bottom > root.scrollTarget + root.height)
            root.scrollTo(bottom - root.height);
    }

    // Back to the top, with no glide: a new set of results is a new list, and
    // watching it scroll up from where the last one happened to be is motion
    // that means nothing.
    function reset(): void {
        root.scrollTarget = 0;
        glide.value = 0;
        glide.target = 0;
        root.contentY = 0;
    }

    // The list moved under its own power, so the target follows it rather than
    // yanking the content back to where the wheel last left it.
    onMovementEnded: root.scrollTarget = root.contentY
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

    // While a drag or a flick owns the content, the glide has nothing to say.
    // It picks the position back up the moment that ends.
    onHandlingChanged: if (root.handling) {
        glide.value = root.contentY;
        root.scrollTarget = root.contentY;
    }

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
                root.scrollTo(root.scrollTarget - event.angleDelta.y / 120 * root.step);
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
