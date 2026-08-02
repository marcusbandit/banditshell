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

    WheelHandler {
        // A touchpad sends pixels and a wheel sends notches. Using the pixels
        // when they are there keeps two-finger scrolling one-to-one with the
        // fingers, which is the whole reason it feels right; converting it to
        // notches would make it lurch.
        onWheel: event => {
            const byPixels = event.pixelDelta.y !== 0;
            const delta = byPixels ? event.pixelDelta.y : event.angleDelta.y / 120 * root.step;
            root.scrollTo(root.scrollTarget - delta);
            event.accepted = true;
        }
    }
}
