pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components
import qs.services
import "../../components/wave.js" as Wave

// Where the track is, and where to send it: the ONE seek bar in the shell.
//
// Android's media notification draws its progress this way, and it is worth
// copying exactly. The part you have heard is a wave, the part you have not
// is a straight run, a vertical pip stands between them with a gap on either
// side, and the two times sit under the two ends. At a glance it says three
// things a bead on a rail cannot: sound has gone by, this much of it, and it
// is still going. The bead slider is for a level you SET, and a volume is
// one; a place in a song is a place in something that moves on its own.
//
// THE WAVE IS FIXED AT THE LEFT EDGE, and the pip uncovers it. The first cut
// pinned the phase at the pip instead, so that every crest met it the same
// way, and it looked wrong the moment the pip moved: the whole pattern slid
// along with it, a beat behind, and a drag read as pushing the wave rather
// than revealing more of it. Pinned at the start, nothing already drawn ever
// moves; the pip only decides how much of one wave is showing
// (components/wave.js), and the clock advances the phase so the crests
// travel toward it.
//
// MOTION MEANS SOUND GOING BY. Playing, the wave travels; paused, it settles
// flat into a line and the whole bar goes still, so the state can be read
// from across the room without a glyph. The amplitude is smoothed, so a pause
// is the water going still rather than a switch being thrown.
//
// One scrubber rather than a notch one and a menu one, for the reason there
// is one MediaTransport: two would drift.
Item {
    id: root

    // Whether anyone can see it. The wave is a clock, and a clock nobody is
    // looking at still wakes the render thread sixty times a second and hands
    // the compositor a fresh surface to blur each time. The host says.
    property bool watched: true

    readonly property real stroke: Appearance.sizes.scrubStroke
    readonly property real amp: Appearance.sizes.scrubWaveAmplitude
    readonly property real wavelength: Appearance.sizes.scrubWaveLength
    readonly property real gap: Appearance.padding.small

    // The pip's height, and the row the track lives in. Tall enough that the
    // wave at full swing sits inside it with a stroke to spare above and
    // below, so the pip always overreaches the wave it stops.
    readonly property real band: root.amp * 2 + root.stroke * 3
    readonly property real centre: root.band / 2

    // The pip is `stroke` wide and travels inside the ends, so a fraction of
    // one puts its far edge on the right edge rather than half past it.
    readonly property real travel: Math.max(1, width - root.stroke)
    readonly property real pipX: root.shown * root.travel
    readonly property real waveEnd: Math.max(0, root.pipX - root.gap)

    readonly property bool active: pointer.pressed || pointer.containsMouse

    // EXACT under the hand, smoothed when the player moves it. The Slider's
    // split, for the Slider's reason: a pip easing toward the cursor feels
    // broken, and one that jumps each time the position poll lands looks
    // broken.
    property real dragged: 0
    readonly property real shown: pointer.pressed ? root.dragged : glide.value

    implicitWidth: Appearance.sizes.menuWidth / 2
    implicitHeight: root.band + Appearance.padding.small + elapsed.implicitHeight

    Follow {
        id: glide

        target: Media.progress
        speed: Appearance.anim.trackSpeed
        epsilon: 0.001
    }

    // How much of the wave is showing: all of it playing, none of it paused.
    Follow {
        id: swell

        target: Media.playing ? 1 : 0
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.004
    }

    // The one permitted looping clock, the same one MicIndicator's processing
    // ripple runs on: a travelling wave chases no target, so there is nothing
    // for Follow to follow. One loop is exactly one wavelength of travel,
    // which is what makes the wrap from 1 back to 0 invisible.
    QtObject {
        id: clock

        property real t: 0
    }

    NumberAnimation {
        target: clock
        property: "t"
        from: 0
        to: 1
        duration: Math.round(root.wavelength / Appearance.sizes.scrubWaveSpeed * 1000)
        loops: Animation.Infinite
        // Linear: easing would make the current speed up and slow down. Gated
        // on being seen, on playing, and on there being any wave left to
        // move, because a flat line does not need a clock either.
        running: root.watched && root.visible && Media.playing && swell.value > 0
    }

    // The part you have heard.
    Shape {
        id: wave

        x: 0
        y: root.centre - height / 2
        width: root.waveEnd
        // The stroke's own thickness on top of the swing, so the item's box is
        // the ink's box. Shapes are not clipped, but a box that lies about
        // its contents is one a layout gets wrong.
        height: root.amp * 2 + root.stroke
        visible: root.waveEnd > 0
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: Appearance.colour.text
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                // Sampled at half a stroke: at that pitch the round joins make
                // the polyline read as a curve, and the point count stays in
                // the low hundreds at the widest the bar gets.
                path: Wave.points(wave.width, root.amp * swell.value, root.wavelength, 2 * Math.PI * clock.t, Math.max(1, root.stroke / 2)).map(p => Qt.point(p[0], wave.height / 2 + p[1]))
            }
        }
    }

    // Where you are. Drawn whether or not you can move it, because it marks
    // the position either way; the cursor is what says whether it will answer
    // a hand.
    G2Rect {
        x: root.pipX
        y: 0
        width: root.stroke
        height: root.band
        radius: width / 2
        color: Appearance.colour.text

        // Swells to meet the cursor and gives when pushed, exactly as the
        // Slider's bead does.
        scale: pointer.pressed ? 1.15 : root.active ? 1.3 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    // The part you have not.
    G2Rect {
        x: root.pipX + root.stroke + root.gap
        y: root.centre - height / 2
        width: Math.max(0, root.width - x)
        height: root.stroke
        radius: height / 2
        visible: width > 0
        color: Appearance.colour.fillStrong
    }

    // The two times, under the two ends. The elapsed one follows the hand
    // while it is on the pip, so a scrub says where it will land before it
    // lands there.
    StyledText {
        id: elapsed

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: Media.timeLabel(pointer.pressed ? root.dragged * Media.length : Media.position)
        color: Appearance.colour.textDim
    }

    StyledText {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: Media.timeLabel(Media.length)
        color: Appearance.colour.textDim
    }

    MouseArea {
        id: pointer

        // The band is what you see. Grown to the accessible minimum the way
        // the Slider's is: WCAG 2.2 SC 2.5.8 puts the floor for the thing you
        // can hit at 24, and the labels below are not part of it.
        readonly property real grow: Math.max(0, (Appearance.sizes.minTarget - root.band) / 2)

        x: -Appearance.padding.small
        y: -grow
        width: root.width + Appearance.padding.small * 2
        height: root.band + grow * 2
        hoverEnabled: true
        // A press on a scrubber is never ambiguous: the control is the target,
        // not the surface it sits on, so nothing else may take the grab. The
        // Slider carries the full argument.
        preventStealing: true
        // Only when the player says it will answer. A scrubber that takes a
        // drag and does nothing with it is worse than a bar that never moved.
        enabled: Media.canSeek
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        // Mapped rather than offset by the margins above, for the reason the
        // Slider gives: the same number written twice with opposite signs.
        function place(mx: real): void {
            const f = (pointer.mapToItem(root, mx, 0).x - root.stroke / 2) / root.travel;
            root.dragged = Math.max(0, Math.min(1, f));
        }

        onPressed: mouse => place(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                place(mouse.x);
        }

        // Sent on release, not on every move. A scrub is a decision about
        // where to land, and SetPosition sixty times a second is a request
        // storm the player answers late and out of order, so the pip would be
        // fought over by the hand and the echoes of the hand.
        //
        // The smoother is snapped first, for the reason Slider.ask sets
        // `glide.value`: the pip has to stay where the hand left it while the
        // player catches up, and the next position poll is up to a second off.
        onReleased: {
            glide.value = root.dragged;
            Media.seekTo(root.dragged * Media.length);
        }

        // A wheel over the scrubber means seek, whatever the wheel does
        // nearby. Notches rather than pixels, so a touchpad's fractions add up
        // to the same travel as a wheel's clicks.
        onWheel: wheel => Media.seekBy(wheel.angleDelta.y / 120 * Appearance.sizes.scrubWheelSeek)
    }
}
