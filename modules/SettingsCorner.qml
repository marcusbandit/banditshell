pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
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
    //
    // AND `containsMouse` IS A CLAIM, NOT A FACT, which is what the `hoverLost`
    // veto is about. On a Wayland layer surface the leave event that would take
    // it down can simply never arrive: cross from the masked corner into the
    // click-through content hole and the pointer walks out of the surface's
    // input region without Qt ever hearing a leave, or let a fullscreen window
    // take the pointer over, and the claim stays true forever, so the swell
    // sits in the corner with nobody anywhere near it. The watchdog below asks
    // the compositor for the truth while the claim stands, and its veto is what
    // lets a provably wrong claim be overruled without touching the two honest
    // terms beside it.
    readonly property bool open: (zone.containsMouse && !root.hoverLost) || zone.pressed || linger.running

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

    // THE WATCHDOG: `containsMouse`, checked against reality.
    //
    // WHAT GOES STALE. Qt only knows the pointer left this zone if the
    // compositor delivers a leave, and on a layer surface it sometimes never
    // does: the two cases seen in the wild are the cursor crossing from the
    // masked corner straight into the click-through content hole (out of the
    // surface's input region, so the surface stops hearing about the pointer
    // at all), and a fullscreen window taking the pointer over. Either way
    // `containsMouse` stays true forever, `open` stays true with it, and the
    // swell squats in the corner while the cursor is provably on the other
    // side of the screen.
    //
    // WHY NOT ANOTHER HOVER SOURCE. The tempting fix is to gate on something
    // that also watches the pointer, ShellWindow's whole-surface HoverHandler
    // being the obvious one, but every hover source on this surface is fed by
    // the same event stream that just failed to deliver the leave, so it can
    // go stale in exactly the same way and the bug merely moves house. The
    // only party that always knows where the cursor is, is the compositor, so
    // the compositor is who gets asked.
    //
    // WHY POLLING IS ACCEPTABLE HERE. The timer's running condition IS the
    // claim being checked: at rest `containsMouse` is false, so there is no
    // timer, no process, no cost of any kind. The moment the claim is either
    // disproven (`hoverLost`) or upgraded to a press, the condition goes false
    // and the polling stops again.
    //
    // BUT NOTHING BOUNDS A HOVER, which is the hole that argument had in it.
    // "The handful of seconds a hover claim stands unpressed" is a guess about
    // the user, not a property of the code: park the cursor in the corner to
    // read the glyph, or leave it there while reading the page it opened, and
    // `containsMouse` is legitimately true for as long as you like. A probe
    // that merely CONFIRMS the claim leaves every term of the running condition
    // exactly as it found them, so at one hyprctl per grace that is a fork, an
    // exec and a socket round trip five and a half times a second, for hours,
    // for a cursor that is doing nothing at all. See `patience` for the bound.
    //
    // WHY NOT WHILE PRESSED. During a pull the cursor legitimately walks out
    // of this zone while the swell must stay out; that is the entire point of
    // the `pressed` term in `open`. A poll running through the gesture would
    // prove the cursor "elsewhere" and yank the swell closed under a held
    // finger, which is precisely the collapse that term exists to prevent.
    property bool hoverLost: false

    // HOW MANY GRACES THE NEXT CHECK WAITS. Doubled every time the compositor
    // agrees with the claim, reset to one by any real pointer event.
    //
    // A CONFIRMED CLAIM IS LESS WORTH CHECKING THAN A FRESH ONE, and that is
    // the whole of the bound. The failure this watchdog exists for is a LOST
    // LEAVE, and a leave can only be owed once the pointer has MOVED; a cursor
    // that has been sitting still since the last confirmation cannot have gone
    // anywhere, so asking again at the same rate is asking a question whose
    // answer cannot have changed. So the poll relaxes while nothing happens,
    // and a parked cursor costs a handful of probes over minutes instead of
    // five and a half a second, forever.
    //
    // AND THE STALE CASE IS NEVER THE QUIET ONE, which is why relaxing costs
    // no latency where it matters. The leave that goes missing is the cursor
    // crossing out of the masked corner into the click-through hole, and it
    // travels there THROUGH this zone: the hover motion on the way out arrives
    // as `positionChanged`, resets this to one, and the check that catches the
    // crossing is a single grace behind it, exactly as before. What relaxes is
    // only the case where nothing is moving, which is the case where nothing
    // can be wrong.
    //
    // UNCAPPED, deliberately. A cap would be a number saying how long a
    // motionless cursor is allowed to be believed, and there is no honest
    // value for it: the one situation that could outrun the backoff is the
    // pointer leaving with no motion event at all (a warp, or the fullscreen
    // window taking it over), and a warp into another surface delivers a real
    // leave while the fullscreen grab is invisible to `cursorpos` at any
    // interval whatsoever, so no cap buys either of them. Growth is geometric,
    // so this is small for the whole of any hover a hand actually makes.
    property int patience: 1

    // The window this corner is drawn in, for the screen it is on: hyprctl
    // answers in the compositor's layout coordinates, and only the screen's
    // origin turns the zone's own rectangle into that frame.
    readonly property var shellWindow: QsWindow.window

    Timer {
        id: watchdog

        // The grace tier, reused rather than a tier of its own, because it is
        // the same tolerance pointed the other way: `linger` is how long a
        // hover claim survives being wrong about "gone", and this is how long
        // one may stand unverified about "still here". A faster poll buys
        // nothing (the swell closing within a grace of the cursor leaving is
        // already better than the permanent squat this replaces) and a slower
        // one is a visibly loitering corner.
        //
        // Times `patience`, so that is the interval a claim gets while anything
        // is happening and the floor of every longer one. Written into the
        // interval rather than counted off inside `onTriggered`, because a
        // Timer restarts its countdown when its interval changes and leaves
        // `running` alone doing it: motion resetting `patience` therefore
        // pushes the next check a full grace out from the motion, which is the
        // point, and it does it without an imperative `restart()` that would
        // overwrite the declarative binding below with a plain `true`.
        interval: Appearance.anim.grace * root.patience
        repeat: true

        // Only while the corner BELIEVES, only unpressed (see the header),
        // only until the belief is disproven, and only where hyprctl is the
        // compositor's own word: on anything but Hyprland the probe would be
        // asking a process that does not exist, so the watchdog stays off and
        // the corner keeps trusting Qt the way it always did.
        running: Compositor.isHyprland && zone.containsMouse && !zone.pressed && !root.hoverLost

        // Restarted, never overlapped: a poll that lands while the previous
        // hyprctl is still running is the same question already in flight, so
        // it is simply skipped rather than queued.
        onTriggered: {
            if (!probe.running)
                probe.running = true;
        }
    }

    // The Process + StdioCollector idiom services/Settings.qml uses for
    // hyprctl, with `-j` so the answer is JSON rather than a string to be
    // picked apart by hand.
    Process {
        id: probe

        command: ["hyprctl", "-j", "cursorpos"]

        stdout: StdioCollector {
            onStreamFinished: root.judge(text)
        }
    }

    // What hyprctl answered, measured against the zone's own rectangle.
    function judge(text: string): void {
        let pos = null;
        try {
            pos = JSON.parse(text);
        } catch (e) {
            return;
        }
        // A malformed answer disproves nothing. The override closes a live
        // control, so it is only ever dropped on evidence, never on a shrug.
        if (!pos || typeof pos.x !== "number" || typeof pos.y !== "number")
            return;

        // The claim can have resolved itself while hyprctl ran: a real leave
        // arrived, or a press began. Either way the question this answer was
        // for no longer exists, and judging a dead question would race the
        // events that settled it.
        if (!zone.containsMouse || zone.pressed)
            return;

        const screen = root.shellWindow?.screen;
        if (!screen)
            return;

        // THE ZONE'S OWN RECTANGLE, not a restatement of it. `mapToItem(null)`
        // is the zone's live position in the surface, wherever its anchors and
        // its swell-following size currently put it, and the surface covers
        // the screen, so the screen's origin is all that separates surface
        // coordinates from the layout ones hyprctl speaks. Spelling the
        // geometry out again here (right edge minus grab, and so on) would be
        // a second copy that drifts the first time the zone's expressions
        // change.
        const corner = zone.mapToItem(null, 0, 0);
        const left = screen.x + corner.x;
        const top = screen.y + corner.y;

        // Inclusive on every side, which errs toward believing the claim: a
        // cursor pinned into the screen's corner reports the last pixel, and
        // a boundary misjudgment here must only ever delay a close, never
        // close a swell the cursor is actually resting on.
        //
        // THE CLAIM STANDS, and standing is the answer that has to change
        // something: nothing else in this file moves when the compositor
        // agrees, so without the backoff the same question is asked again a
        // grace later, and again, for as long as a hand cares to rest there.
        // See `patience`.
        if (pos.x >= left && pos.x <= left + zone.width && pos.y >= top && pos.y <= top + zone.height) {
            root.patience *= 2;
            return;
        }

        // Provably elsewhere. The claim is overruled until a REAL entry says
        // otherwise; see the zone's handlers for why the clearing is an event
        // and not a timer.
        root.hoverLost = true;
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

        // A REAL enter clears the watchdog's veto, and the clearing is an
        // EVENT, never a timer. A timed clear would be guessing about the
        // cursor a second time in the one place a guess already went stale,
        // and a wrong guess reopens the swell over a corner nobody is in,
        // which is the original bug wearing the fix as a coat. An enter is
        // the compositor saying the cursor is here, and that is the only
        // authority the veto answers to.
        onEntered: {
            linger.stop();
            root.hoverLost = false;
            root.patience = 1;
        }

        // A hover MOVE clears it too, and this is not belt and braces: it is
        // the half of the return the enter cannot announce. When the leave was
        // never delivered, Qt still believes this item is hovered, so the
        // cursor's genuine return is not an enter to Qt at all and `entered`
        // never fires; what does arrive is hover motion inside the zone, which
        // is the same proof of a live cursor from the same authority. Motion
        // only reaches this item while the pointer is really inside its
        // rectangle, so there is no spurious clearing to pay for it. This
        // handler runs alongside Pull's own `onPositionChanged` rather than
        // replacing it; QML connects both.
        //
        // AND IT IS WHAT WINDS THE WATCHDOG BACK UP. Motion is the only thing
        // that can make a standing claim wrong, so motion is where the poll's
        // urgency comes back: every one of these puts the next check a single
        // grace away again, no matter how long the cursor had been resting
        // before it moved. The reset is free where it is cheap and pays where
        // it counts, because these arrive precisely while the pointer is inside
        // the rectangle and stop arriving the moment it is not. See `patience`.
        onPositionChanged: {
            root.hoverLost = false;
            root.patience = 1;
        }

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
