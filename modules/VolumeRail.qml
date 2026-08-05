import QtQuick
import qs.config
import qs.components
import qs.services

// The right edge is a volume rail: put the cursor on it and turn the wheel, or
// put a finger on it and push.
//
// The gesture comes first and the readout second. Scrolling an edge is a thing
// you do without looking, so the rail answers the wheel whether or not anything
// is on screen; what comes out of the band is there to tell you where you landed,
// not to be aimed at. That is the difference between this and the slider in the
// sound menu, which is a control you go to on purpose.
//
// THE WHEEL IS THE MOUSE'S ANSWER AND NOBODY ELSE'S, which is what the second
// gesture is here to fix. A touchscreen emits no wheel event at all, so for the
// whole of this rail's life the right edge was a strip of screen that took a
// finger and did nothing whatever with it, and it was worse than a strip that
// was not there: the band sits inside the window's input mask, so the compositor
// routed the touch to this surface, and this surface refused the button and
// dropped it. The touch did not change the volume AND did not reach the window
// underneath either. So the press is taken now, and a drag along the rail is the
// same instruction the wheel already was, given by the one input that had none.
//
// It is a blob in the shell's distance field, like the notch and the menus, so it
// melts out of the right band rather than being drawn over it. At rest it is
// parked a full melt-distance clear of the screen, because a blob that merely
// shrinks still pulls the band toward it the whole way and would leave a
// permanent bulge halfway down the edge.
//
// The rail is the band MINUS a corner at each end. The top-right corner is the
// notification tray's summon zone and cannot also be this; the bottom-right is
// left free to match, so no corner on this edge does two things and neither end
// of the rail is a place you arrive at by accident.
Item {
    id: root

    // The band's own thickness, and what the rail is DRAWN as: the blob below
    // ends flush with the screen's edge and the chassis's band is the rest of
    // the picture. What you can HIT is wider than this and always was allowed to
    // be; see `grab`.
    required property real border

    // HOW WIDE THE TARGET IS, which is not how wide the rail looks.
    //
    // Ten pixels is under this shell's own floor for anything you are meant to
    // hit (WCAG 2.2 SC 2.5.8 puts it at 24, and Appearance.sizes.minTarget is
    // where that number lives), and a fingertip is nearer eight millimetres than
    // ten pixels. The same split the sound menu's slider already makes: the rail
    // stays thin, the thing you can hit does not. Nothing about the drawing
    // moves, because the drawing is the band and the band belongs to the
    // chassis.
    // A SWITCH, because widening this is not free: see Config's `touchEdges`.
    // The extra pixels have to be taken from the window underneath, and on the
    // right edge that is where scrollbars are. Off, it collapses back to the
    // band, which the chassis already owns, and nothing is claimed at all.
    readonly property real grab: Appearance.sizes.touchEdges ? Math.max(root.border, Appearance.sizes.minTarget) : root.border

    readonly property real corner: Appearance.sizes.cornerZone
    readonly property real step: Appearance.sizes.volumeStep

    // Everything above 1.0 is amplification, so the rail runs to the same
    // ceiling the sound menu's slider does and marks where normal ends. A rail
    // that stopped at 100% would have nowhere to show the part worth warning
    // about.
    readonly property real ceiling: Audio.maxVolume
    readonly property real warnAbove: 1

    readonly property bool muted: Audio.muted
    readonly property real volume: Audio.volume

    // ONE colour at three weights, the same ladder the sound menu's slider uses:
    // muted says the value is not in effect, past 100% says it is more than the
    // hardware was asked for, and everything else is simply the level.
    readonly property color lit: root.muted ? Appearance.colour.textFaint : root.volume > root.warnAbove ? Appearance.colour.accent : Appearance.colour.text

    // Out while the cursor is on it, while a hand is holding it, and for a
    // moment after the last change, so a volume key pressed from across the desk
    // still shows you what it did.
    //
    // The `pressed` term is not redundant with `containsMouse`, and it is the
    // same argument the settings corner writes down. Hover is the mouse's
    // report and a touch has none to give: a finger pressing the rail sets no
    // hover at all on the way down, so without this the one input that has
    // NOTHING but the press would be dragging the volume about behind a readout
    // that never appeared. It also covers the mouse case where a drag carries
    // the pointer off the rail's own width, which it must be free to do.
    readonly property bool active: rail.containsMouse || rail.pressed || panelZone.containsMouse || linger.running

    readonly property Item maskItem: panelZone

    // THE LANDING PAD, and it has to be in the mask ALWAYS, unlike the panel.
    //
    // The same argument the launch edge and the settings corner both make: a
    // target that only exists once it has been hit is not a target. `maskItem`
    // above is granted on `active`, and `active` cannot become true until
    // something has already pressed or hovered the rail, so on its own it is a
    // region that appears only for the input that did not need it.
    //
    // While `touchEdges` is off this is exactly the band, which the chassis
    // covers anyway, so the entry costs nothing and the widening is the only
    // thing that ever claims a pixel.
    readonly property Item grabItem: rail

    // THE PANEL, sized by what is in it rather than by a number picked here.
    //
    // Wide enough for the WIDEST reading it can ever show, not for the one it is
    // showing. The number is the only thing in here that changes width, and it
    // does so in the middle of the gesture that changes it: sized to fit, the
    // panel would step wider crossing 100% and back again on the way down, so
    // the shape would be answering the wheel as well as the value. Measured off
    // the ceiling rather than assumed, so raising maxVolume cannot outgrow it.
    readonly property real contentWidth: Math.max(widest.width, Appearance.sizes.volumeRailWidth, glyph.width)
    readonly property real contentHeight: readout.implicitHeight + Appearance.padding.normal + Appearance.sizes.volumeRailLength + Appearance.padding.normal + glyph.height

    readonly property real panelWidth: root.border + root.contentWidth + Appearance.padding.large * 2
    readonly property real panelHeight: root.contentHeight + Appearance.padding.large * 2

    // It arrives from OFF the screen and ends flush with the right edge, so the
    // approach is a real one: it reaches the band, merges with it, then swells
    // out to the left.
    readonly property var blobs: [
        {
            x: root.width - root.panelWidth + (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value),
            y: (root.height - root.panelHeight) / 2,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large
        }
    ]

    // WHICH WAY THE HAND WENT, not which way the event points.
    //
    // Natural scrolling has already flipped the event by the time it arrives, and
    // it is right to: content is a sheet of paper under the finger, and pushing
    // the paper down moves you up the page. A rail is not paper. It is a thing
    // standing on the edge of the screen with a level on it, and pushing down on
    // a thing lowers it, whatever the setting says about documents.
    //
    // So the setting is UNDONE here rather than obeyed, and only for the device
    // that has it: this machine runs natural scrolling on the touchpad and not on
    // the mouse, and both have to end up meaning the same thing.
    //
    // Asked TWO ways, because either one alone can come back empty. Qt sets
    // `inverted` when the stack has already flipped the axis, which is the direct
    // answer when it is there; when it is not, the device is told apart by
    // reporting pixels as well as an angle, which a wheel does not do, and the
    // compositor is asked what that kind of device is set to. Agreeing to invert
    // is enough: a wheel with natural scrolling off trips neither.
    function nudge(wheel: var): void {
        const touchpad = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;
        const natural = wheel.inverted || (touchpad ? Compositor.naturalScrollTouchpad : Compositor.naturalScrollMouse);
        const notches = wheel.angleDelta.y / 120 * (natural ? -1 : 1);
        Audio.setVolume(Audio.volume + notches * root.step);
    }

    // WHAT ONE PIXEL OF DRAG IS WORTH: the whole range over the whole rail.
    //
    // One sweep from one end of the rail to the other covers everything the
    // volume can be, exactly once, which means there is no constant in here to
    // tune and no number that goes wrong on a taller screen or on the day the
    // corners at the ends change size. The rail is the scale because the rail is
    // the thing under the hand (~/.claude/rules/math-over-hardcoding.md).
    //
    // Deliberately NOT the drawn track's length. The track in the panel is 180px
    // and the rail is most of the screen, so matching them would make the fill
    // travel exactly as far as the finger and cost a fifth of the sweep for the
    // whole range: about a percent of volume for every pixel of slip. The two
    // are not in the same place on the screen and never touch, so the
    // correspondence would be arithmetic nobody could see, bought with a
    // sensitivity everybody would feel.
    readonly property real perPixel: root.ceiling / Math.max(1, rail.height)

    // What the widest reading measures, so the panel can be built around it
    // without anyone having to know how wide a digit is.
    TextMetrics {
        id: widest

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.normal
        text: `${Math.round(root.ceiling * 100)}%`
    }

    Follow {
        id: reveal
        speed: Appearance.anim.revealSpeed
        target: root.active ? 1 : 0
        epsilon: 0.005
    }

    // The fill TRAVELS to the level. A wheel notch is a step, and a bar that
    // jumps between steps reads as a series of states rather than as one thing
    // being turned up.
    Follow {
        id: level
        speed: Appearance.anim.trackSpeed
        target: root.volume
        epsilon: 0.001
    }

    Timer {
        id: linger
        interval: Appearance.sizes.volumeLinger
    }

    // Anything that changes the volume shows it, not just the wheel: the keyboard
    // keys, the sound menu, another application ducking it. The readout is about
    // the value, and the value does not care who moved it.
    Connections {
        target: Audio

        function onVolumeChanged(): void {
            linger.restart();
        }

        function onMutedChanged(): void {
            linger.restart();
        }
    }

    // THE RAIL.
    //
    // The DRAWN part is inside the band, which the chassis already covers, so it
    // needs no mask entry of its own. The rest of `grab` gets none either, and
    // that is a real limit rather than an oversight: it reaches `minTarget -
    // border` past the band's inner edge, which is inside the content area the
    // window's mask subtracts, so the compositor keeps routing those pixels to
    // whatever window is sitting there. Which is the right way round for a shell
    // that must not eat clicks, and it means the widening buys REACH rather than
    // a bigger landing pad: the press still has to start in the band, and from
    // the press onward the implicit grab carries the drag wherever it goes,
    // mask or no mask. While the panel is out its own entry covers the full
    // width anyway, over the height the panel occupies.
    MouseArea {
        id: rail

        anchors.right: parent.right
        y: root.corner
        width: root.grab
        height: Math.max(0, parent.height - root.corner * 2)

        // WHERE THE HAND WENT DOWN and what the volume was when it did.
        //
        // Anchored rather than accumulated. Adding each move's own delta onto
        // the live volume would feed Audio.quantise's rounding to whole percent
        // back into the sum, so a slow drag would shed a percent at a time and a
        // fast one would not: the same journey would end somewhere different
        // depending on how many events the hardware happened to send.
        property real fromY: 0
        property real fromVolume: 0

        hoverEnabled: true

        // THE PRESS IS TAKEN NOW. The reason it was refused (that the whole
        // right edge would swallow a click meant for the window behind it) does
        // not survive contact with the mask: the band IS the compositor's
        // `gaps_out`, the dead space between a window and the screen, so there
        // is no window under it with a click to lose. What the refusal actually
        // cost was every input that has no wheel.
        acceptedButtons: Qt.LeftButton

        // RELATIVE, NOT ABSOLUTE, and it is the one real decision in this file.
        //
        // Absolute is what a slider does and what components/Slider.qml does two
        // files over: press three tenths of the way along and the value becomes
        // three tenths. It is more direct, it is what a slider has trained
        // everyone to expect, and it is wrong HERE, because a slider shows its
        // scale and this rail deliberately shows nothing. At rest the right edge
        // is a uniform band with no track on it, no ends and no marks: the
        // drawing that says where thirty percent is lives in the panel, and the
        // panel does not exist until you have already pressed. So an absolute
        // mapping would be a mapping onto an invisible scale, where the first
        // thing the gesture does is commit to a number you had no way to aim at.
        // With a ceiling of 150% that is not a slightly worse mapping, it is a
        // hazard: a palm brushing the top of the edge would slam the output to
        // half again above full, which is the kind of mistake that is loud,
        // instant and occasionally expensive.
        //
        // Relative cannot do that at all. The press commits to nothing; it only
        // remembers where the finger landed and what the volume already was.
        // From there the volume moves by exactly as much as the hand does, so
        // the worst a mis-touch can cost is the distance the hand actually
        // travelled, and a ten-pixel slip is ten pixels' worth of volume. The
        // thing given up is landing on a value in one movement, which was never
        // on offer here anyway: you cannot aim at a scale you cannot see.
        //
        // UP IS LOUDER. Not a fourth convention: it is the direction the panel's
        // own fill already runs (it fills from the bottom) and the direction the
        // wheel already means. One fact stated three times rather than three
        // conventions to keep straight.
        onPressed: mouse => {
            rail.fromY = mouse.y;
            rail.fromVolume = Audio.volume;
        }

        // `mouse.y` raw, unlike Pull's parent-coordinate anchor. That trick
        // exists to cancel the drift of an item whose own top-left moves under
        // the gesture; this one is pinned to a fixed edge at a fixed height and
        // cannot move, so there is nothing to cancel and the offset would only
        // be a number written twice.
        onPositionChanged: mouse => {
            if (rail.pressed)
                Audio.setVolume(rail.fromVolume + (rail.fromY - mouse.y) * root.perPixel);
        }

        onWheel: wheel => root.nudge(wheel)
    }

    // The panel's own hit area, following its left edge so the cursor can move
    // off the band and into the readout without leaving it, and keep scrolling
    // once it is there.
    MouseArea {
        id: panelZone

        anchors.right: parent.right
        y: (parent.height - root.panelHeight) / 2
        width: Math.max(root.border, root.panelWidth - (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value))
        height: root.panelHeight

        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: reveal.value > 0.01

        onWheel: wheel => root.nudge(wheel)

        // Hung from the LEFT edge, which is the edge that moves, so the contents
        // ride in with the shape instead of being revealed inside a shape that
        // has already arrived.
        Item {
            id: content

            x: Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter
            width: root.contentWidth
            height: root.contentHeight
            opacity: reveal.value

            StyledText {
                id: readout

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                // The number, not a name. "Muted" would be the one word the icon
                // below already says, and it would throw away the level you are
                // about to go back to.
                text: `${Math.round(root.volume * 100)}%`
                font.pixelSize: Appearance.font.size.normal
                color: root.lit
            }

            G2Rect {
                id: track

                anchors.horizontalCenter: parent.horizontalCenter
                y: readout.implicitHeight + Appearance.padding.normal
                width: Appearance.sizes.volumeRailWidth
                height: Appearance.sizes.volumeRailLength
                radius: width / 2
                color: Appearance.colour.fillStronger

                // Fills from the BOTTOM, because that is the end the wheel moves
                // away from.
                G2Rect {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(0, Math.min(1, level.value / root.ceiling)) * parent.height
                    radius: width / 2
                    color: root.lit
                }

                // WHERE NORMAL ENDS. One hairline, at 100%, because the rail runs
                // past it: without the mark the top third is indistinguishable
                // from headroom, and it is not headroom, it is amplification.
                Rectangle {
                    x: 0
                    y: parent.height * (1 - root.warnAbove / root.ceiling) - height / 2
                    width: parent.width
                    height: 1
                    color: Appearance.colour.surface
                }
            }

            Icon {
                id: glyph

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom

                name: Audio.icon(root.volume, root.muted)
                color: root.muted ? Appearance.colour.textFaint : Appearance.colour.textDim
            }
        }
    }
}
