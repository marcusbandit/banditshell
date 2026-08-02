import QtQuick
import qs.config
import qs.components

// The bottom edge, as a way in.
//
// A phone has a gesture bar there and everyone already knows what it is for, so
// the shell does the same thing with the band it already has: put the cursor on
// the bottom of the screen and it swells a little, click it and the launcher
// comes up, or push up from it and it comes up with you.
//
// The swell is deliberately SMALL, a hair under the gap the windows already sit
// inside, so it never moves anything and never covers anything. It is the shell
// noticing you rather than the shell interrupting you: the whole affordance is
// that the edge is alive, and an edge only has to move a few pixels to say that.
Item {
    id: root

    // The band's own thickness, which the swell is added to rather than replaces.
    required property real border

    // Whether the edge is worth offering at all. Pointless while the thing it
    // opens is already open.
    property bool armed: true

    // A hair under the gap. Big enough to see, small enough that the band never
    // reaches the windows sitting inside that gap.
    readonly property real swellBy: Math.max(1, Appearance.sizes.gap - 1)

    // How far up counts as a push rather than a slip.
    readonly property real swipeBy: Appearance.sizes.rowHeight

    readonly property bool active: root.armed && zone.containsMouse

    // Always in the mask, not only while swollen. At rest the zone is exactly
    // the band, which the chassis already covers, so this costs nothing; while
    // swollen it reaches a few pixels past the band, and without it those pixels
    // would be the only part of the swell you could not touch.
    readonly property Item maskItem: zone

    signal requested

    readonly property var blobs: swell.value <= 0.01 ? [] : [
        {
            x: 0,
            y: root.height - (root.border + swell.value),
            w: root.width,
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

        // Follows the swell, so the cursor that caused it can stay inside it
        // rather than falling out of the thing it just opened.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.border + swell.value

        enabled: root.armed
        hoverEnabled: true

        property real from: 0
        property bool pushed: false

        onPressed: mouse => {
            zone.from = mouse.y;
            zone.pushed = false;
        }

        // The push. Fires as soon as it has gone far enough rather than waiting
        // for the finger to come off, because a gesture that only answers on
        // release feels like it did not hear the first half of it.
        onPositionChanged: mouse => {
            if (!zone.pressed || zone.pushed)
                return;
            if (zone.from - mouse.y >= root.swipeBy) {
                zone.pushed = true;
                root.requested();
            }
        }

        // A click is the whole gesture only if the push was not. Releasing after
        // a push has already opened it would open it twice, and the second one
        // is a toggle shut.
        onClicked: if (!zone.pushed)
            root.requested()
    }
}
