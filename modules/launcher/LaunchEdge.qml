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
        property real from: 0
        property bool pulling: false
        property real velocity: 0
        property real lastY: 0
        property real progress: 0

        onPressed: mouse => {
            if (!root.armed) {
                mouse.accepted = false;
                return;
            }
            zone.from = mouse.y;
            zone.lastY = mouse.y;
            zone.pulling = false;
            zone.velocity = 0;
            zone.progress = 0;
        }

        onPositionChanged: mouse => {
            if (!zone.pressed)
                return;

            // Up is POSITIVE, because up is the direction that opens it and the
            // sign is what the release reads.
            const step = zone.lastY - mouse.y;
            zone.lastY = mouse.y;
            zone.velocity += (step - zone.velocity) * 0.4;

            if (!zone.pulling && zone.from - mouse.y < root.slack)
                return;

            zone.pulling = true;
            zone.progress = Math.max(0, Math.min((zone.from - mouse.y) / root.travelFull, 1));
            root.dragged(zone.progress);
        }

        // A press that never became a drag is a click, and a click just opens
        // it. One that did is answered by which way it was travelling, with the
        // same allowance Pull makes: the lift is the noisiest instant of the
        // gesture, a finger peeling off drags the point backward, so past the
        // commit fraction only a SUSTAINED backward motion (beating the
        // reversal speed) still counts as a change of mind. This edge predates
        // Pull and hand-rolls the same gesture, so it reads the same tokens for
        // the same reasons; drifting apart here would make the bottom edge the
        // one place a flick still bounced home off its own recoil.
        onReleased: {
            if (zone.pulling)
                root.finished(zone.velocity >= 0 || (zone.progress >= Appearance.sizes.pullCommit && zone.velocity > -Appearance.sizes.pullReversal));
            else
                root.finished(true);
            zone.pulling = false;
        }

        onCanceled: {
            if (zone.pulling)
                root.finished(false);
            zone.pulling = false;
        }
    }
}
