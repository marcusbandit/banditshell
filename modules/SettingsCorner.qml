pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// The bottom-right corner, as a way in.
//
// A screen corner is the easiest target a pointing device has: it is the one
// place you can throw the cursor at full speed and be certain where it stops,
// because the edges catch it. Fitts's law calls that an infinitely large target,
// and this shell had one going spare. The top-right is the notification tray's
// summon zone, the two on the left belong to the sidebar, and the volume rail
// deliberately stops short of both ends of its edge so that no corner does two
// things.
//
// THE CORNER IS THE CONTROL. There is no button in it and there must not be
// one: a button inside the corner is a smaller target sitting in the middle of
// the perfect one, and the whole reason to use a corner is that you do not have
// to aim. So the swell holds a glyph and nothing else, and the click is taken by
// the corner region itself, at any point in it, whether or not the glyph is
// under the cursor when you press.
//
// AND THERE IS A SECOND WAY IN, because all of the above is an argument about a
// cursor. A corner is only the cheapest target there is if something can be
// thrown at it; a finger has no hover at all, so on a touchscreen everything the
// swell does happens after the press and none of it can be read before. So the
// corner also answers a PUSH away from itself, along its own diagonal: press
// anywhere in it and drag inward, and the page comes out with the gesture, as
// far as the gesture has gone. Reverse before letting go and it goes back where
// it came from, which is the whole reason to prefer a drag to a click here (see
// DESIGN.md section 15). components/Pull.qml has the mechanics: what counts as
// a pull rather than the wobble inside a press, which directions are the wrong
// way out of a corner, and what a release decides.
//
// It comes out DIAGONALLY, parked a full melt-distance clear of both edges when
// closed, for the reason SessionMenu records: a blob that merely shrinks in
// place keeps pulling the band toward it the whole way down and leaves a
// permanent bulge where it used to be. Off the corner and back is a real
// approach.
Item {
    id: root

    // The band's own thickness. The swell reaches the screen's edge and includes
    // it, so the shape starts at the band rather than floating clear of it.
    required property real border

    signal activated

    // How far the page has been pulled out of the corner, 0 to 1.
    signal dragged(real fraction)
    // Let go: true carries on, false puts it back.
    signal finished(bool open)

    // WHAT THE CORNER BECOMES, and the only number here that is set rather than
    // derived. The swell exists to hold this, so it is sized from the glyph
    // outwards and never the other way round.
    readonly property real mark: Appearance.sizes.cornerIcon

    // The glyph, its breathing room, and the band it grows out of.
    readonly property real reach: root.border + root.mark + Appearance.padding.normal * 2

    // HOW BIG THE TARGET IS AT REST, which is not how big the swell is.
    //
    // Same lesson the launch edge wrote down: a target cannot be conditional on
    // having already been hit. At rest there is nothing on screen here, so this
    // has to be a constant patch of corner big enough to notice a cursor that
    // stopped near rather than exactly on the corner.
    readonly property real grab: Math.max(root.border + Appearance.padding.normal, Appearance.sizes.minTarget)

    // Parked clear of BOTH edges, diagonally: the swell's own size plus the
    // melt, applied to x and y alike, which is the 45 degree direction out of
    // the corner it belongs to.
    readonly property real slide: (root.reach + Appearance.sizes.melt) * (1 - reveal.value)

    readonly property real padX: root.width - root.reach + root.slide
    readonly property real padY: root.height - root.reach + root.slide

    // OUT WHILE POINTED AT, WHILE HELD, and for the grace period after either.
    //
    // The `pressed` term is not redundant with `containsMouse`. A pull leaves the
    // grab square inside its first few pixels, by construction: the square is
    // barely bigger than the minimum target and the gesture's whole job is to
    // travel inward away from it. Hover goes false the instant it does, so
    // without this the swell the gesture started from would collapse under the
    // finger at exactly the moment the gesture became one, and the corner would
    // look like it had let go of something you are still holding. `pressed` is
    // true for the whole of the implicit grab, so the corner stays out until the
    // release actually happens.
    readonly property bool open: zone.containsMouse || zone.pressed || linger.running

    // The corner patch always, and the whole swell while it is out. Both are
    // anchored to the same corner, so their union is one rectangle and the
    // MouseArea can simply BE it: at rest it collapses to the grab square, and
    // while the swell is out it is exactly the swell.
    readonly property Item maskItem: zone

    readonly property var blobs: reveal.value <= 0.001 ? [] : [
        {
            x: root.padX,
            y: root.padY,
            w: root.reach,
            h: root.reach,
            radius: Appearance.rounding.large,
            // A fillet is as wide as it is told to be regardless of what it is
            // filleting, so a melt wider than the swell's own half would reach
            // further along both surfaces than the swell is big and eat it. See
            // blob.frag. Derived from the shape rather than tuned, so a corner
            // that grows with the icon size does not need this revisited.
            smooth: Math.min(Appearance.sizes.melt, root.reach / 2)
        }
    ]

    Follow {
        id: reveal

        target: root.open ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // Hover is a sloppy input, and this one is reached by throwing the cursor at
    // a corner, which is the sloppiest gesture there is. Without the grace, an
    // overshoot that bounces a pixel off the edge closes the thing you were
    // arriving at.
    Timer {
        id: linger

        interval: Appearance.anim.grace
    }

    Pull {
        id: zone

        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // The union, live: the grab square until the swell overtakes it. Written
        // as a max rather than as a branch on `open`, so the region grows WITH
        // the shape and the cursor that summoned it is never left outside the
        // thing it just summoned.
        width: Math.max(root.grab, root.width - root.padX)
        height: Math.max(root.grab, root.height - root.padY)

        // WHICH WAY THE GESTURE GOES, and the only two numbers in the file that
        // say so: the inward diagonal, written as a vector. Bottom-right, so
        // inward is leftward and upward, hence both components negative.
        // Everything else about the gesture is derived from this one vector:
        // which way the pull is measured, which directions reject the press
        // outright, and which way a reversal has to run to put the page back.
        // Move this item to another corner and turning the vector round is the
        // whole of the change.
        dirX: -1
        dirY: -1

        // A SUMMONING pull, so it is measured against the surface rather than
        // against the thing being summoned: the page is not on screen yet, so it
        // has no size to be a fraction of. The diagonal of the surface the
        // corner belongs to, which for this item is the screen's, because it
        // fills the screen.
        //
        // Taken from `root` rather than from the zone on purpose: the zone is
        // only the grab square, and measuring a screen-sized gesture against a
        // patch of corner would count the first inch of the pull as the whole
        // of it.
        travel: Math.hypot(root.width, root.height) * Appearance.sizes.pullTravel

        hoverEnabled: true

        onExited: linger.restart()
        onEntered: linger.stop()

        // ANY point in the corner, not the glyph. See the header: the glyph is
        // what the corner looks like, not what you have to hit.
        //
        // `tapped` rather than `clicked`, which is not interchangeable here.
        // `clicked` still fires for a press that wandered off in a direction the
        // pull rejects and then came back to where it started, and that is the
        // one press in this corner that has to do nothing at all: the gesture
        // said "not that way", and answering it by opening the page anyway would
        // make the rejection meaningless. `tapped` is the press that never became
        // a pull AND never went the wrong way.
        onTapped: root.activated()

        onPulled: fraction => root.dragged(fraction)
        onFinished: open => root.finished(open)
    }

    // The mark, riding in with the shape rather than being revealed inside a
    // frame that arrived first.
    //
    // Centred on the part of the swell that is NOT band. The band is the
    // outermost `border` of both edges and belongs to the chassis, so a glyph
    // centred on the whole square would sit visibly closer to the screen's
    // corner than to the swell it is in.
    Item {
        x: root.padX
        y: root.padY
        width: root.reach - root.border
        height: root.reach - root.border

        visible: reveal.value > 0.001
        opacity: reveal.value

        Icon {
            anchors.centerIn: parent

            name: "settings"
            size: root.mark
            color: Appearance.colour.text
        }
    }
}
