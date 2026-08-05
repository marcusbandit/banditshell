import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components

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

    readonly property real contentWidth: glyph.implicitWidth + Appearance.padding.large + root.barsWidth
    readonly property real contentHeight: Math.max(glyph.implicitHeight, root.barMax)

    // Fixed across every phase. The shape must not resize as the phase changes:
    // a pill that grew and shrank between listening, processing and typing would
    // be three animations of the chassis reflowing, on top of the one thing that
    // is actually meant to be moving.
    readonly property real pillWidth: root.contentWidth + Appearance.padding.huge * 2
    readonly property real pillHeight: root.border + root.contentHeight + Appearance.padding.large * 2

    // Empty at rest rather than a zero-width slot parked off-screen: the field
    // has twelve slots and several are permanently spoken for, so something idle
    // most of the day should not hold one. It takes a slot when the reveal
    // starts and gives it back once fully retracted.
    readonly property var blobs: drop.value > 0.001 ? [
        {
            x: (width - root.pillWidth) / 2,
            y: -(root.pillHeight + Appearance.sizes.melt) * (1 - drop.value),
            w: root.pillWidth,
            h: root.pillHeight,
            radius: Appearance.rounding.large
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
        if (root.phase === "listening")
            root.resetHistory();
    }

    Component.onCompleted: root.resetHistory()

    // The daemon's event stream.
    Socket {
        id: events

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

        onConnectionStateChanged: {
            if (!connected) {
                // No daemon, no microphone open. Anything else would leave a
                // "listening" pill on screen with nothing behind it.
                root.phase = "idle";
                root.resetHistory();
            }
        }
    }

    // The socket only exists while the daemon does, and the daemon restarts
    // (package upgrade, config change, a crash). Without this the shell would
    // silently never show the indicator again until the next login.
    Timer {
        interval: 2000
        running: !events.connected
        repeat: true
        onTriggered: events.connected = true
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

        anchors.horizontalCenter: parent.horizontalCenter
        width: root.contentWidth
        height: root.contentHeight
        y: root.pillHeight - (root.pillHeight + Appearance.sizes.melt) * (1 - drop.value) - height - Appearance.padding.large
        opacity: drop.value

        Icon {
            id: glyph

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            name: root.phase === "processing" ? "autorenew" : root.phase === "typing" ? "keyboard" : "mic"
            color: Appearance.colour.accent
            font.pixelSize: Appearance.font.size.normal
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            // Explicit, not implicit from the tallest bar. A Row that sizes to
            // its children changes height as the bars move, and bottom-anchored
            // bars would then be measuring against a floor shifting under them
            // every frame.
            height: root.contentHeight
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
