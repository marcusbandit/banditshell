import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// LOAD-BEARING. Do not delete this module, do not drop it from ShellWindow's
// `panels` list, and do not "simplify" the reconnect below. This is the only
// thing on screen that says the microphone is open.
//
// It is specifically DICTATION. It is not the volume rail, not a notification,
// not a generic status pill, and it is not covered by any of them: SUPER + R
// (`voice toggle`) opens the mic with no other feedback anywhere in the session,
// so with this gone you are talking to a machine that looks idle. That is the
// bug it exists to prevent, and it has been reintroduced more than once by work
// that was aimed at something else entirely.
//
// If you are running the shell from a trimmed copy or a scratch directory, copy
// this file too, or dictation will look broken to whoever is actually at the
// desk.
//
// Dictation, as one thing that changes shape rather than a stack of popups.
//
// The daemon (~/bin/voice-daemon) pushes newline-delimited JSON down a unix
// socket: a phase, and while listening a 0..1 level metered off the actual
// microphone samples about thirty times a second. So the waveform is NOT an
// animation that means "recording" - it is the sound of the room. Speak and it
// moves; stop and it flattens.
//
// Four phases, each with its own shape, because "what is it doing" should be
// answerable at a glance and from across the desk:
//
//   listening   the waveform, scrolling right to left, driven by your voice
//   processing  the row fills with liquid and ripples
//   typing      a caret running left to right, filling the row behind it
//   idle        gone, and the band is clean
//
// The phases are told apart by how the bars are ANCHORED as much as by what
// moves them. Listening and typing hang off the centre line, so they read as a
// waveform and a line of text; processing sits its bars on the floor, so the
// same bars read as a volume of something with a surface. Changing the axis is
// what makes the phase legible at a glance, and it is what the two earlier
// attempts at this phase were missing.
//
// Like the notch it is a blob in the shell's distance field rather than
// something drawn on top, so it melts out of the top band. It descends from a
// full melt-distance above the screen because a blob that merely shrinks in
// place still drags the band toward it and would leave a permanent bulge.
Item {
    id: root

    property int border: Appearance.sizes.border

    readonly property string socketPath: Quickshell.env("HOME") + "/.local/share/gvoice/events.sock"

    // What the daemon last said. `idle` is also what a dropped connection means:
    // if the daemon is not there, nothing is listening to you, so the honest
    // thing to draw is nothing.
    property string phase: "idle"
    property real level: 0

    // WHICH SCREEN THIS COPY IS ON, asked of the window rather than handed in,
    // the same way the notification tray asks it and for the same reason: the
    // preview harnesses build this module on windows that are in none of the
    // shell's wiring and could not be told a name.
    readonly property var host: QsWindow.window?.screen ?? null

    // THE SCREEN THE KEYBOARD IS ON, as an object and not as a name, because
    // what is wanted from it is an origin and a width rather than an identity.
    // Its own geometry is what the pill is kept inside of, so the pill comes to
    // rest within the screen it is resting on and not within the one drawing it.
    readonly property var stage: Quickshell.screens.find(s => s.name === Hypr.focusedScreen) ?? root.host

    // WHERE THE WORDS ARE GOING, IN THE LAYOUT'S COORDINATES - one number for
    // the whole desk, not a position on this screen.
    //
    // This is the difference between a pill that CHANGES MONITOR and one that
    // TRAVELS to another monitor, and it is the whole of why the coordinate is
    // global. Per-screen, each copy could only ever say "not mine" or "mine,
    // here", so a move across the desk was one screen dropping the pill and
    // another catching it, at a position each worked out on its own: it flicked
    // in from whichever edge the old window's coordinates clamped to on the new
    // screen. Measured against the desk instead, there is ONE position, every
    // screen computes the same one, and each simply draws whatever part of it
    // falls inside its own bounds. The pill then walks off the edge of one
    // monitor and onto the next because that is literally what the number does.
    //
    // No window at all (a bare workspace, the compositor still starting) falls
    // back to the middle of the focused screen, which is where this came from.
    readonly property real centre: {
        const box = Hypr.activeClient?.lastIpcObject;
        if (box?.at && box?.size)
            return box.at[0] + box.size[0] / 2;
        return root.stage ? root.stage.x + root.stage.width / 2 : 0;
    }

    // KEPT ON THE SCREEN IT IS RESTING ON, by its own width rather than by a
    // margin someone measured once. A window can hang off the edge of the
    // layout, and half a pill past the corner would tear the band open where the
    // chassis rounds. A screen too narrow to hold the pill inside its own
    // margins gets the middle, because there is no honest answer there and the
    // middle is at least symmetrical.
    //
    // Clamped against `stage` and not against this screen, so the clamp is the
    // same answer on every screen: a limit each copy applied locally would bend
    // the journey differently in each one and the hand-over would not line up.
    readonly property real margin: root.pillWidth / 2 + root.border + Appearance.padding.large
    readonly property real anchor: {
        if (!root.stage)
            return root.centre;
        const lo = root.stage.x + root.margin;
        const hi = root.stage.x + root.stage.width - root.margin;
        return hi < lo ? root.stage.x + root.stage.width / 2 : Math.max(lo, Math.min(hi, root.centre));
    }

    // The travelling position, brought back to this screen's own coordinates.
    readonly property real axis: slide.value - (root.host?.x ?? 0)

    // IS ANY OF IT HERE? This is what replaced asking whether the focused screen
    // was this one. That question could only be answered yes or no, and the
    // answer changed in one frame, which is exactly the pop that made a monitor
    // change look like a glitch. Overlap is the same question asked of a
    // position, so it answers "half of it" during the crossing.
    //
    // A melt of slack on each side, because the pill is a blob in the chassis
    // field rather than a sprite: one just past the corner still pulls on the
    // band, and that pull IS the hand-over, seen from the screen it is leaving.
    readonly property bool here: root.axis + root.pillWidth / 2 > -Appearance.sizes.melt && root.axis - root.pillWidth / 2 < root.width + Appearance.sizes.melt

    // The vertical reveal is the DICTATION's, not this screen's: every copy
    // descends together and the ones the pill is not over simply have nothing to
    // draw. Gating this per screen is what made an arrival at a new monitor a
    // drop out of the band rather than a pill sliding in from the side.
    readonly property bool out: root.phase !== "idle"

    // The waveform's memory: one slot per bar, oldest at the left. A new level
    // shifts the row along, which is what makes it scroll rather than flicker.
    property var history: []

    // GEOMETRY, ALL DERIVED. Change barCount alone and the pill resizes, the
    // history re-lengths and every phase still lays out evenly, because nothing
    // below this line knows the number.
    // 45, paired with the daemon's 16ms chunks, keeps the waveform covering the
    // same ~0.7s of history as before at half the step size. The scroll speed is
    // therefore unchanged and only the resolution goes up, which is what was
    // making it look choppy: the window in seconds is barCount x chunk length,
    // so the two numbers have to move together.
    readonly property int barCount: 45
    readonly property real barWidth: Math.max(2, Math.round(Appearance.font.size.small / 6))
    readonly property real barGap: root.barWidth
    readonly property real barMax: Appearance.font.size.large * 1.6
    readonly property real barMin: root.barWidth
    readonly property real barsWidth: root.barCount * root.barWidth + (root.barCount - 1) * root.barGap

    // The waveform's well, and how much room the bars get inside it. Uniform, so
    // the inset reads as one frame around one thing rather than as a margin that
    // was tuned per edge.
    readonly property real wellPad: Appearance.padding.normal
    readonly property real contentWidth: root.barsWidth + root.wellPad * 2
    readonly property real contentHeight: root.barMax + root.wellPad * 2

    // Fixed across every phase. The shape must not resize as the phase changes:
    // a pill that grew and shrank between listening, processing and typing would
    // be three animations of the chassis reflowing, on top of the one thing that
    // is actually meant to be moving.
    // THE PILL'S RIM, and deliberately the smallest padding there is.
    //
    // It was padding.large on every side, which was the right number when the
    // pill held a glyph AND a row of bars and had to keep the two apart. With
    // one thing inside it that number is just a wide dark border: 24px of frame
    // around a well 54 tall, so most of what hung below the band was rim rather
    // than readout. The well is the shape now and the pill is the edge it sits
    // in, so the edge is an edge.
    readonly property real rim: Appearance.padding.small
    readonly property real pillWidth: root.contentWidth + root.rim * 2
    readonly property real pillHeight: root.border + root.contentHeight + root.rim * 2

    // Empty at rest rather than a zero-width slot parked off-screen: the field
    // has twelve slots and several are permanently spoken for, so something idle
    // most of the day should not hold one. It takes a slot when the reveal
    // starts and gives it back once fully retracted.
    readonly property var blobs: drop.value > 0.001 && root.here ? [
        {
            x: root.axis - root.pillWidth / 2,
            y: -(root.pillHeight + Appearance.sizes.melt) * (1 - drop.value),
            w: root.pillWidth,
            h: root.pillHeight,
            radius: Appearance.rounding.large,
            // THE JOIN, SIZED BY WHAT IT IS JOINING. The shell's 34px fillet was
            // set by panels that come out of the band a long way; measured
            // against this one it was half of everything below the band, so the
            // pill read as a bulge in the band with a well in it rather than as
            // a thing hanging off it. Derived from the free height rather than
            // picked, so it stays right if the bars or the rim ever change; the
            // volume rail caps its own melt the same way and for the same
            // reason.
            smooth: Math.min(Appearance.sizes.melt, (root.pillHeight - root.border) / 3)
        }
    ] : []

    function resetHistory(): void {
        const blank = [];
        for (let i = 0; i < root.barCount; i++)
            blank.push(0);
        root.history = blank;
    }

    function pushLevel(v: real): void {
        const next = root.history.slice(1);
        next.push(v);
        root.history = next;
    }

    // The bar heights for the current phase, as a fraction of full.
    //
    // One function rather than three sets of bars, so every phase is guaranteed
    // the same row geometry and switching between them can never reflow the pill.
    function barFraction(i: int): real {
        if (root.phase === "listening")
            return root.history[i] ?? 0;

        if (root.phase === "processing") {
            // LIQUID. The bars bottom-anchor for this phase only (see the Row
            // below), so instead of a waveform mirrored about the centre this is
            // a body of fluid with a surface on top of it.
            //
            // That anchoring is doing most of the work. Centre-anchored bars
            // read as "audio waveform" no matter what drives them, which is why
            // every previous attempt at this phase either looked like more
            // listening or had to resort to a gimmick to escape it.
            //
            // The surface is three travelling sines summed. Their SPATIAL
            // frequencies are deliberately incommensurate (1.3, 2.7, 4.1), so
            // crests drift in and out of alignment and the motion never settles
            // into a pattern you can predict - which is what makes it read as
            // fluid rather than as a mechanism. Their TIME coefficients are
            // whole numbers, so the whole thing is seamless across the loop.
            const p = i / (root.barCount - 1);
            const t = flow.t;
            const wave = 0.30 * Math.sin(2 * Math.PI * (1.3 * p - t))
                       + 0.17 * Math.sin(2 * Math.PI * (2.7 * p + t) + 1.1)
                       + 0.09 * Math.sin(2 * Math.PI * (4.1 * p - 2 * t) + 2.3);
            // A slow swell under the ripples, so the body breathes as well as
            // rippling. Same trick: an integer time coefficient keeps it seamless.
            const swell = 0.46 + 0.10 * Math.sin(2 * Math.PI * t);
            // `fill` pours the liquid in when the phase starts rather than
            // snapping to full depth, which is the "expand upwards" moment.
            //
            // Clamped at the top because the three crests can align: the sum
            // peaks at 1.12, and anything over 1 is a bar taller than the row
            // that would poke out through the lid of the pill.
            return Math.min(1, Math.max(0.04, (swell + wave) * fill.value));
        }

        // TYPING: the caret advances and leaves text behind it.
        //
        // A caret that only blinks shows a cursor existing, not a cursor doing
        // anything, which is why the first version felt inert. Here it runs left
        // to right and the cells it passes stay filled, so the row fills up the
        // way a line of text does. That is the thing being depicted.
        const caret = writer.position * (root.barCount - 1);
        if (i > caret + 0.5)
            return 0.05;                      // not written yet
        if (i > caret - 0.9)
            return 1;                         // the caret itself
        return 0.34;                          // already written
    }

    onPhaseChanged: {
        if (root.phase !== "listening")
            return;
        root.resetHistory();
        // The window's position comes off an IPC round trip that this shell only
        // makes when Hyprland says something happened, and a window RESIZED by
        // hand says nothing at all. So the one moment this module reads geometry
        // of its own accord, it asks first, rather than descending onto where
        // the window was at the last focus change.
        if (root.mine)
            Hypr.resync();
    }

    // ARRIVING IS NOT A MOVE, and nothing behind the band is moving.
    //
    // The slide tracks the focused window, but a pill coming out belongs over
    // the window it is coming out FOR, not skating across from wherever the last
    // dictation happened, which draws the eye along the path instead of to the
    // words. So while it is still up behind the band, a change of target is a
    // PLACEMENT and is taken instantly; once it is down where it can be seen,
    // the same change is a JOURNEY and is smoothed like everything else.
    //
    // The second rule is not tidiness. `activewindow` and the geometry behind it
    // arrive on separate IPC round trips, so the correct position routinely
    // lands a frame or two after the phase does; without this the pill descends
    // onto a stale position and then slides off to the real one, which is the
    // flick this pair exists to remove.
    onOutChanged: {
        if (root.out)
            slide.snap();
    }

    onAnchorChanged: {
        if (drop.value < 0.05)
            slide.snap();
    }

    Component.onCompleted: {
        root.resetHistory();
        slide.snap();
    }

    // Between windows it TRACKS rather than jumps. This is a blob in the chassis
    // distance field, so a teleport would pop the band open in one place and
    // shut in another within a single frame, which reads as a glitch rather than
    // as a move.
    //
    // HALF THE SHELL'S TRACKING SPEED, and the only place in the shell that
    // slows it down. Exponential smoothing takes the same TIME whatever the
    // distance - that is the point of it - so the speed that reads as tracking
    // when a plate follows a workspace across 200px reads as a smear when this
    // crosses 3000px of desk to another monitor, because the velocity is what
    // scales with the distance. This is the one indicator whose journeys are
    // desk-scale rather than widget-scale, so it is the one that wants longer to
    // make them. Still exponential, still the same curve: fast away, gentle in.
    Follow {
        id: slide

        target: root.anchor
        speed: Appearance.anim.trackSpeed / 2
    }

    // The daemon's event stream.
    //
    // The Socket lives inside a Loader because a Quickshell Socket that fails
    // its FIRST connect is dead for good: `connected` reads false from then on,
    // and neither reassigning `path` nor pushing `connected` back through false
    // and up again will make it try a second time. Retrying means building a
    // NEW socket, which is what toggling `active` does.
    //
    // That is not a hypothetical. The shell and the daemon are both started off
    // graphical-session.target, so whoever wins the race decides: if the shell
    // reaches this line before the daemon has bound its socket, the connect
    // fails with ServerNotFoundError and the indicator is dark for the whole
    // session. The retry below used to just re-assign `connected = true`, which
    // is a no-op on a dead socket, so it never recovered.
    Loader {
        id: events

        active: true
        sourceComponent: eventSocket

        // The real connection state, from whichever socket is currently loaded.
        readonly property bool up: item?.connected ?? false

        onUpChanged: {
            if (!up) {
                // No daemon, no microphone open. Anything else would leave a
                // "listening" pill on screen with nothing behind it.
                root.phase = "idle";
                root.resetHistory();
            }
        }
    }

    Component {
        id: eventSocket

        Socket {
            path: root.socketPath
            connected: true

            parser: SplitParser {
                splitMarker: "\n"
                onRead: line => {
                    let msg;
                    try {
                        msg = JSON.parse(line);
                    } catch (e) {
                        return;
                    }
                    if (msg.phase !== undefined)
                        root.phase = msg.phase;
                    if (msg.level !== undefined) {
                        root.level = msg.level;
                        if (root.phase === "listening")
                            root.pushLevel(msg.level);
                    }
                }
            }
        }
    }

    // The socket only exists while the daemon does, and the daemon starts late,
    // restarts (package upgrade, config change, a crash) and takes its socket
    // with it when it goes. So the shell keeps knocking until something answers.
    // Without this the indicator would stay dark until the next login.
    Timer {
        interval: 2000
        running: !events.up
        repeat: true
        onTriggered: {
            events.active = false;
            events.active = true;
        }
    }

    // Exponential approach, the same one the notch drops with, so this arrives
    // out of the band on the shell's timing rather than its own.
    Follow {
        id: drop

        speed: Appearance.anim.revealSpeed
        target: root.out ? 1 : 0
        epsilon: 0.005
    }

    // Only the phases that need a clock get one. A running animation wakes the
    // render thread every frame, and every one of those frames redraws the whole
    // chassis field and hands the compositor a new surface to blur; the notch's
    // clock is gated for the same reason. Listening needs no timer at all - the
    // microphone is its clock.
    // PROCESSING: the row fills with liquid and ripples.
    //
    // This replaced a bouncing ball, which replaced converging fronts. The ball
    // was playful in the wrong register - cartoon, not fluid - and the fronts
    // read as a progress bar being clever about itself. What the phase actually
    // wants to say is "something is churning away in here", and a body of moving
    // liquid says that without being a mascot about it.
    QtObject {
        id: flow

        property real t: 0
    }

    NumberAnimation {
        target: flow
        property: "t"
        running: root.phase === "processing"
        from: 0
        to: 1
        // Linear and unhurried. Easing would make the current appear to speed up
        // and slow down, and water in a channel does neither.
        duration: Appearance.anim.slow * 9
        loops: Animation.Infinite
    }

    // Depth of the liquid: pours in when the phase begins, drains when it ends.
    // Exponential approach, so it arrives quickly and settles rather than
    // sliding in at a constant rate.
    Follow {
        id: fill

        speed: Appearance.anim.resizeSpeed
        target: root.phase === "processing" ? 1 : 0
        epsilon: 0.004
    }

    QtObject {
        id: writer

        property real position: 0
    }

    NumberAnimation {
        target: writer
        property: "position"
        running: root.phase === "typing"
        from: 0
        to: 1
        // Roughly the pace of the phase itself, so a short burst of text reads
        // as one pass of the caret rather than a frantic loop.
        duration: Appearance.anim.slow * 2
        loops: Animation.Infinite
    }

    // Contents hang from the pill's lower edge so they ride the descending blob:
    // they arrive WITH the shape rather than being revealed inside a shape that
    // is already there.
    Item {
        id: content

        // On the pill's axis, not the screen's; see `centre` above.
        x: root.axis - width / 2
        visible: root.here
        width: root.contentWidth
        height: root.contentHeight
        y: root.pillHeight - (root.pillHeight + Appearance.sizes.melt) * (1 - drop.value) - height - root.rim
        opacity: drop.value

        // THE BARS' OWN WELL, and now the only thing in the pill.
        //
        // The glyph that used to sit on the left is GONE. It named the phase
        // ("mic", "autorenew", "keyboard") which is the same fact the bars are
        // already spelling out in the one way that can be read from across the
        // desk: two readouts of one state, and the small one was the slower of
        // the two to take in. Removing it also stops the pill saying the phase
        // twice and disagreeing with itself for the frame between the icon
        // swapping and the bars re-anchoring.
        //
        // A G2Rect and never a Rectangle, per ~/.claude/rules/g2-corners.md.
        // This is a shape inside another shape, which is exactly where the
        // difference shows: nested G2 corners stay visually concentric, and
        // nested circular arcs visibly do not.
        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fillStronger

            Row {
                anchors.centerIn: parent
                // Explicit, not implicit from the tallest bar. A Row that sizes
                // to its children changes height as the bars move, and
                // bottom-anchored bars would then be measuring against a floor
                // shifting under them every frame.
                height: root.barMax
                spacing: root.barGap

                Repeater {
                    model: root.barCount

                    Rectangle {
                        required property int index

                        // Bound to `history` as well as the phase so a new level
                        // actually repaints this bar; barFraction() reading the
                        // array is not enough on its own to register a dependency
                        // when the array is replaced wholesale.
                        readonly property real fraction: (root.history, root.phase, flow.t, fill.value, writer.position, root.barFraction(index))

                        readonly property bool liquid: root.phase === "processing"

                        width: root.barWidth
                        height: root.barMin + (root.barMax - root.barMin) * fraction
                        radius: width / 2
                        color: Appearance.colour.accent

                        // THE BASELINE IS THE PHASE. Centre-hung bars read as an
                        // audio waveform whatever drives them, because a shape
                        // mirrored about its own axis is what a waveform IS. Sitting
                        // them on a floor instead turns the very same bars into a
                        // volume of liquid with a surface, which is why this phase
                        // finally looks like something other than more listening.
                        //
                        // Plain `y`, NOT a pair of conditional anchors. Swapping
                        // between anchors.verticalCenter and anchors.bottom left both
                        // bound at once, and an item anchored top-and-bottom is
                        // stretched between them with its height binding discarded:
                        // every bar came out identical, full height and frozen. A Row
                        // positions its children in x only, so y is ours to set and
                        // there is no anchor to conflict with.
                        y: liquid ? parent.height - height : (parent.height - height) / 2
                    }
                }
            }
        }
    }
}
