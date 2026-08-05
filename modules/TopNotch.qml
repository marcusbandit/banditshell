import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.modules.media
import qs.services

// The notch: cursor to the top-centre edge and the time swells out of the band.
//
// It is NOT a pill that slides out from behind the edge. It is a blob in the
// shell's distance field, exactly like a menu, so it melts out of the top band
// and back into it. At rest its rectangle is precisely the band's own height, so
// it is entirely inside the body and invisible; growing past that is what makes
// it appear.
//
// That is the difference between something drawn over the shell and something
// the shell does.
//
// It carries TWO things, and only one of them was asked for. The time is the
// focus: it is what going to the top of the screen means. Whatever is playing
// rides underneath it, quieter, because the same trip is when you would want to
// know (DESIGN.md 2.4, contextual prominence). The clock does not move to make
// room: the contents hang from the notch's bottom edge and the notch is as long
// as its contents, so a track appearing grows the notch DOWNWARD and leaves the
// time exactly where it was.
//
// AND IT LATCHES, which is the whole reason there is anything here but a hover.
// The thing riding under the clock is not a picture: MediaPreview carries a
// press that raises the player, and MediaTransport's play, pause and skip are
// full-sized buttons sitting right there. Behind a hover strip they were
// unreachable by construction. To press one you had to hold the strip open with
// one hand and press with the other, and Qt Quick synthesises its mouse from the
// FIRST touch point only, so on a touchscreen that is not merely awkward, it is
// arithmetically impossible: the second finger does not exist. Every media
// control the shell has was behind a strip of edge the thickness of the band,
// and the notch is the only live media surface there is.
//
// So the notch can be OPENED and LEFT open: tap the strip and it stays, tap it
// again and it goes, push down on it and it comes out with the hand, push it
// back up and it goes home (DESIGN.md 15: everything returns into the edge it
// came out of, by the gesture that brought it out, reversed). Hover still works
// and is still the mouse's cheapest way in; it is now one of the things that can
// hold the notch out rather than the only one.
Item {
    id: root

    // PINNED: asked for by a tap or a pull, and therefore not something a
    // wandering pointer gets to take away.
    //
    // The notification tray records the argument in full and it is the same
    // argument here. A hover-opened notch closes when the pointer leaves,
    // because the pointer leaving is the only thing that could ever have meant
    // "done with it": nothing was asked for, so there is nothing to take back. A
    // notch you deliberately opened WAS asked for, and closing it by that rule
    // would take it away the instant you reached down toward the pause button,
    // which is the only reason anybody opens it. On a touchscreen the rule is
    // not merely wrong but unrunnable: there is no pointer to leave.
    property bool pinned: false

    // A pull in progress, and how far it has got. The notch moves the instant
    // the gesture is recognised rather than on release, so the pull can be
    // abandoned by reversing it: what you are deciding about is a notch you can
    // already see.
    property bool pulling: false
    property real pullProgress: 0

    // OUT IF ANY OF THEM SAYS SO. Derived, and written by nothing.
    //
    // Four things can hold this notch out and they overlap freely: a pinned
    // notch is hovered the whole time you are reaching into it, a pull ends with
    // the pointer parked on the strip it started from, and the strip and the
    // body are adjacent, so crossing between them is one of them going false as
    // the other goes true. A plain bool that each of them assigned would be
    // decided by whichever finished LAST, so a hover leaving would close a notch
    // that had been pinned, and a release would close one the pointer had never
    // left. Every fix for that is the same fix: check the other three before
    // writing, at which point the flag is no longer the answer, it is a cache of
    // the answer. A union has no ordering to get wrong.
    readonly property bool active: zone.containsMouse || notchZone.containsMouse || root.pinned || root.pulling
    readonly property Item maskItem: notchZone

    // THE SUMMON STRIP, in the mask ALWAYS, unlike the notch itself.
    //
    // `maskItem` is granted on `active`, and nothing can make `active` true
    // without first pressing or hovering this strip, so on its own it is a
    // region that only exists for the input that did not need it. The launch
    // edge and the settings corner both write the same sentence: a target that
    // only exists once it has been hit is not a target.
    //
    // While `touchEdges` is off this is exactly the band, which the chassis
    // covers anyway, so it claims nothing that was not already claimed.
    readonly property Item grabItem: zone

    // HOW FAR DOWN IT ACTUALLY IS, which is the smoother EXCEPT while a hand is
    // on it.
    //
    // The settings page needed the same third state for the same reason. Out or
    // away was enough while the only ways in were a hover and a tap, both of
    // which are instants; a drag is neither. While one is happening the notch's
    // depth is the POINTER'S rather than the animation's, because a notch that
    // lagged the hand by a smoother's worth of easing would be a switch with a
    // picture of a drag on it, and the whole value of the gesture is being able
    // to see how far you have pulled and change your mind. `drop` is left alone
    // underneath, still resting at its own target, which is what lets the
    // release hand over in a single assignment instead of starting a second
    // animation from somewhere the hand never was.
    //
    // EVERYTHING geometric reads this and not `drop.value`: the blob that feeds
    // the chassis field, the hit area that follows it down, and the weight of
    // what is inside. A single one of them left on `drop.value` would be a piece
    // of the notch tracking a target the hand is not at, and the blob is the
    // shell's own body, so that piece would be a bulge in the band.
    readonly property real descent: root.pulling ? root.pullProgress : drop.value

    property int border: Appearance.sizes.border

    // HOW TALL THE TARGET IS, which is not how tall the summon strip looks.
    //
    // Nothing here is drawn: the strip is a patch of the band and the band is
    // the chassis's. But `border` is the compositor's gap, ten pixels, and this
    // shell's own floor for something you are meant to hit is
    // Appearance.sizes.minTarget, 24 (WCAG 2.2 SC 2.5.8). The region reaches
    // further in than the band does while the picture stays exactly where it
    // was.
    // A SWITCH, for the reason Config's `touchEdges` sets out: the extra pixels
    // are taken from the window underneath, so a mouse pays for a widening only
    // a hand needs. Off, this is the band and the shell claims nothing new.
    readonly property real grab: Appearance.sizes.touchEdges ? Math.max(root.border, Appearance.sizes.minTarget) : root.border

    // A pull, arriving. BOTH gestures come through here: the summon reports how
    // far out it has got and the push back reports the same number inverted, so
    // there is one place that knows what "how far down the notch is" means and
    // one place that hands the smoother back its job.
    function dragTo(fraction: real): void {
        root.pulling = true;
        root.pullProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        // Guarded, because a release always arrives and a pull does not always
        // precede it: Pull reports the end of every gesture it recognised, and a
        // press that never travelled far enough is a tap instead.
        if (!root.pulling)
            return;
        root.pulling = false;
        // Hand the smoother the depth the drag ended at, so the notch carries on
        // from there rather than snapping back to the band to begin the journey
        // again. Let go short of it and `pinned` is about to be false, so the
        // same assignment is what walks it home.
        drop.value = root.pullProgress;
        root.pullProgress = 0;
        root.pinned = open;
    }

    // What is in it, and therefore how big it is: the time always, the track
    // when there is one. `hasTrack` rather than `available`, because a player
    // that is merely open is not something to make the notch longer for.
    readonly property bool showsMedia: Media.hasTrack
    readonly property real contentWidth: Math.max(label.implicitWidth, showsMedia ? preview.implicitWidth : 0)
    readonly property real contentHeight: label.implicitHeight + (showsMedia ? Appearance.padding.large + preview.implicitHeight : 0)

    // The SHAPE follows the contents rather than being them, because the
    // contents change while the notch is open: a track ends, the next one has a
    // longer name, a player disappears. Taking those instantly would make the
    // shell twitch at something the cursor did not do. Snapped as it opens, so
    // arriving is never an animation of the notch finding its own size.
    readonly property real notchWidth: wide.value + Appearance.padding.huge * 2
    readonly property real notchHeight: root.border + tall.value + Appearance.padding.large * 2

    // THE SAME LENGTH, SETTLED: measured off the contents themselves rather than
    // off the smoother that is chasing them, and it is what a gesture must be
    // scaled against.
    //
    // `notchHeight` is a live number by design, and a live number as a pull's
    // `travel` is a scale that moves while it is being used: the fraction is
    // `projection / travel`, so a travel that shrinks under the hand makes the
    // same finger movement worth more with every frame and the notch runs away
    // from the finger it is supposed to be following. The gesture has to be
    // measured against where the notch is GOING, which is a number the gesture
    // does not touch.
    readonly property real notchFull: root.border + root.contentHeight + Appearance.padding.large * 2

    // What the chassis needs to melt this into the body.
    //
    // It DESCENDS from above the screen rather than growing in place. A blob
    // that merely shrinks to nothing still pulls the band toward it the whole
    // way, because a smooth minimum blends anything within `melt` of the
    // surface, so at rest the band would carry a permanent bulge where the notch
    // is parked. Starting a full melt-distance clear of the band means at rest
    // it has no influence at all, and the arrival is a real approach: it reaches
    // the band, merges with it, then swells out below.
    readonly property var blobs: [
        {
            x: (width - notchWidth) / 2,
            y: -(notchHeight + Appearance.sizes.melt) * (1 - root.descent),
            w: notchWidth,
            h: notchHeight,
            radius: Appearance.rounding.large
        }
    ]

    onActiveChanged: {
        if (!root.active)
            return;
        wide.snap();
        tall.snap();
        // Ask the player where it is. MPRIS does not push position and Media
        // only polls it while something is PLAYING, so a paused track that was
        // seeked in the player itself would open showing where it used to be.
        Media.active?.positionChanged();
    }

    Follow {
        id: drop
        speed: Appearance.anim.revealSpeed
        target: root.active ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: wide
        speed: Appearance.anim.resizeSpeed
        target: root.contentWidth
    }

    Follow {
        id: tall
        speed: Appearance.anim.resizeSpeed
        target: root.contentHeight
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
        // Only tick while it is being looked at. A seconds clock bound to a
        // visible label wakes the render thread once a second whether or not
        // anything is on screen, and every one of those frames redraws the whole
        // chassis field and hands the compositor a new surface to blur.
        enabled: root.active
    }

    // SUMMON ZONE: a strip of the band at top-centre, and the handle.
    //
    // The band's own thickness is inside the body, which is already in the input
    // mask, so that much needs no mask entry. The rest of `grab` gets none: it
    // reaches `minTarget - border` past the band's inner edge, which is inside
    // the content area the window's mask subtracts, so the compositor keeps
    // routing those pixels to whatever window is there. That is the right way
    // round for a shell that must not eat clicks, and it means the widening buys
    // REACH rather than a bigger landing pad: the press has to start in the
    // band, and from the press onward the implicit grab carries the gesture
    // wherever it goes.
    //
    // ON TOP of the notch body, which it was not before and had to become. The
    // two are exactly coincident while the notch is away (both are the band's
    // thickness at top-centre) and the body is declared second, so the body was
    // quietly taking everything and this strip has never been hit in its life.
    // That did not matter while both did the same one thing. It matters now,
    // because the tap that puts a pinned notch away has to land on the handle
    // and the handle is inside the notch by then.
    //
    // Its PARENT is `root`, which fills the screen and never moves, which is the
    // condition Pull's press anchor needs (see the push-back below for what
    // happens when it is not met). This item's own geometry does move: it is
    // centred on a width that follows the track name. That is the case the anchor
    // is built for and it cancels exactly.
    Pull {
        id: zone

        z: 1

        hoverEnabled: true
        height: root.grab
        width: root.notchWidth
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        // STRAIGHT DOWN, which is the direction the notch already descends.
        // There is nothing to infer and nothing to branch on: the vector is the
        // gesture (~/.claude/rules/math-over-hardcoding.md).
        dirX: 0
        dirY: 1

        // An EDGE's tolerance rather than a corner's. A corner has ninety
        // degrees of "into the screen" to divide up and an edge has a hundred
        // and eighty, so the same number is stingy in one place and greedy in
        // the other. What the extra room is being kept away from here is the
        // gesture that runs ALONG the top band, and there is not one.
        angle: Appearance.sizes.pullAngleEdge

        // The notch's own full height, not a fraction of the screen. This is a
        // summoning pull by the letter of Pull's own note, but what it summons
        // has a size that is known before the gesture starts, and it is the size
        // the hand is being asked to travel: one notch-length of hand is one
        // notch-length of notch. `notchFull` and not `notchHeight`, for the
        // reason written there: a scale that moves during the gesture is not a
        // scale.
        travel: root.notchFull

        // A TAP IS THE LATCH, and it is what makes the buttons reachable at all.
        // One press on the strip and the notch stays out to be used; a second
        // puts it away. `tapped` rather than `clicked`, which is not
        // interchangeable: `clicked` still fires for a press that set off across
        // the direction the pull rejects and then wandered back, and that is the
        // one press here that has to do nothing at all.
        onTapped: root.pinned = !root.pinned

        onPulled: fraction => root.dragTo(fraction)
        onFinished: open => root.dragEnd(open)
    }

    // THE WAY BACK, and it is this gesture reversed rather than a second one to
    // learn. Everything in this shell goes back into the edge it came out of, by
    // the gesture that brought it out, pointed the other way (DESIGN.md 15),
    // which is exactly why Pull takes a vector instead of being told which corner
    // it is sitting in. Pushing the notch up into the top band is what a close
    // button would otherwise be, and a small permanent control drawn on a panel
    // is the thing this shell is trying hardest not to have.
    //
    // A SIBLING WEARING THE NOTCH'S RECTANGLE, rather than a child living inside
    // it, and that is not a stylistic choice. Pull anchors its press in its
    // PARENT's coordinates (`root.x + mouse.x`), which is exactly right for a
    // zone that moves or resizes inside a parent that does not: the zone's own x
    // rises by d, `mouse.x` falls by d, and the sum is untouched. It does not
    // survive the PARENT moving, because then `mouse.x` shifts with nothing on
    // the other side of the sum to cancel it, and the gesture collapses into the
    // frame-to-frame remainder. Inside `notchZone` that is precisely the trap:
    // that item's width is the notch's width, which changes with the track name,
    // and its height is the thing this very gesture is driving. Out here the
    // parent is `root`, which fills the screen and never moves, and the rectangle
    // is copied in rather than inherited.
    //
    // BEFORE `notchZone` in the file, because declaration order is input order.
    // Everything inside the notch is declared after this and therefore sits above
    // it: the transport's play, pause and skip, and the preview's
    // raise-the-player press, all keep their own presses, and what is left over,
    // the notch's empty space, is what begins a push. That makes `z: -1`
    // unnecessary rather than merely redundant: ordering does as a sibling what
    // the z did as a child, and two mechanisms saying one thing is one too many.
    // `notchZone` takes no buttons at all (see below), so a press falls past it
    // to here instead of being swallowed by a hover region on the way down.
    Pull {
        id: putBack

        x: notchZone.x
        y: notchZone.y
        width: notchZone.width
        height: notchZone.height

        dirX: 0
        dirY: -1
        angle: Appearance.sizes.pullAngleEdge

        // Measured against the PANEL rather than the surface, which is the half
        // of Pull's travel note that applies to putting something away: the notch
        // is right there under the finger and the whole point is that its edge
        // tracks the hand. `notchFull` and not the live height, for the reason
        // written there: this gesture changes the notch's height, so the live one
        // would be a ruler that shrank as it was read.
        travel: root.notchFull

        // INVERTED, both ways round, because this gesture measures the same
        // journey from the other end: a push that is halfway home has left the
        // notch half out, and a push that CARRIED is a notch that has gone. So
        // `open` from Pull means "the push committed", and what the notch does
        // about that is close.
        onPulled: fraction => root.dragTo(1 - fraction)
        onFinished: open => root.dragEnd(!open)

        // `tapped` is deliberately unwired. A press on the notch's empty space is
        // somebody reaching past a button and missing, and a panel that vanished
        // when you missed a button would be worse than one with no way out at
        // all. The handle at the top is where a tap means something.
    }

    // The notch's own hit area, which follows the blob so the cursor can move
    // down into it without leaving.
    MouseArea {
        id: notchZone

        hoverEnabled: true
        // HOVER ONLY. It never had a click to do and it used to swallow one
        // anyway, which cost nothing while there was nothing underneath to hear
        // it. There is now: the push-back above is a sibling declared earlier, so
        // it sits below this rectangle rather than inside it, and a press this
        // item accepted and then did nothing with would be a press the gesture
        // never sees.
        acceptedButtons: Qt.NoButton
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.notchWidth
        // Follows the blob's lower edge, so the cursor can move down into the
        // notch without leaving it. `descent` and not `drop.value`, so during a
        // drag the region is where the notch IS rather than where it was heading
        // before a hand got hold of it.
        height: Math.max(root.border, root.notchHeight - (root.notchHeight + Appearance.sizes.melt) * (1 - root.descent))

        // Everything the notch holds, hung from its bottom edge so it rides the
        // descending blob: the contents arrive WITH the shape rather than being
        // revealed inside a shape that is already there.
        Item {
            id: content

            anchors.horizontalCenter: parent.horizontalCenter
            width: wide.value
            height: root.contentHeight
            y: parent.height - height - Appearance.padding.large
            opacity: root.descent

            StyledText {
                id: label

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                font.pixelSize: Appearance.font.size.large
            }

            MediaPreview {
                id: preview

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: implicitHeight
                visible: root.showsMedia
            }
        }
    }
}
