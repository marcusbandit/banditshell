import QtQuick
import qs.config
import qs.components
import qs.services

// The middle of the right edge is a volume rail: put the cursor on it and turn
// the wheel, or put a finger on it and push.
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
// The rail is a SEGMENT of the band, not the edge: a fraction of it
// (Appearance.sizes.volumeGrabFraction), centred. It used to run corner-zone to
// corner-zone, and a control that owns a whole screen edge intercepts
// everything else that lives on it, which on the right is every window's
// scrollbar. A centred third is still an enormous target by this shell's
// standards, and it hands the rest of the edge back to the windows; it also
// settles the old truce with the corners for free, because a centred segment
// cannot reach either one: the top-right stays the notification tray's summon
// zone and the bottom-right stays empty, untouched rather than negotiated with.
//
// A segment you cannot see has to be findable, so it SWELLS: put the cursor on
// it (or a finger; a press counts) and the band bulges by a hair along the
// segment's length, the same gesture the launch edge makes at the bottom of the
// screen. A hair on purpose. The alternative was drawing the segment on the
// band permanently, and a permanent mark is a control sitting on the edge all
// day; the swell is the shell noticing you, and at a glance there is still
// nothing there.
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

    // How far the segment bulges while noticed: a hair under the gap, the
    // launch edge's number for the launch edge's reason. Big enough to see,
    // small enough that the band never reaches the windows sitting inside that
    // gap, so the swell can never move anything or cover anything.
    readonly property real swellBy: Math.max(1, Appearance.sizes.gap - 1)

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

    // What drives the swell, and it is DELIBERATELY NARROWER than `active`: the
    // cursor or a hand on the segment itself, nothing else. Folding in `linger`
    // would bulge the edge every time a volume key is pressed from across the
    // desk, and the swell is the segment noticing an approach, not a readout of
    // the value; the panel already does that job. The `pressed` term carries
    // the same weight it does in `active`: a touch never hovers, and a drag is
    // free to leave the segment mid-gesture without the bulge collapsing under
    // the hand that is still holding it.
    //
    // Reading the rail's hover ALONE is only safe because of input order: the
    // rail is declared last of the two areas, so over its own footprint the
    // hover is always its own and `containsMouse` here means the cursor really
    // is on the segment. Declared the other way round, panelZone took the
    // hover one Follow tick into the approach and this went false under a
    // stationary cursor; panelZone's comment tells that story in full.
    readonly property bool held: rail.containsMouse || rail.pressed

    readonly property Item maskItem: panelZone

    // THE LANDING PAD, and it has to be in the mask ALWAYS, unlike the panel.
    //
    // The same argument the launch edge and the settings corner both make: a
    // target that only exists once it has been hit is not a target. `maskItem`
    // above is granted on `active`, and `active` cannot become true until
    // something has already pressed or hovered the rail, so on its own it is a
    // region that appears only for the input that did not need it.
    //
    // While `touchEdges` is off this is a stretch of the band, which the
    // chassis covers anyway, so the entry costs nothing and the widening is the
    // only thing that ever claims a pixel. And the widening now claims far
    // less: the mask takes this item's own geometry, so the rail becoming a
    // segment shrank the always-on claim to a third of the edge without
    // ShellWindow changing a line. That is the point of the contract: the
    // remaining two thirds of the edge, scrollbars and all, went back to the
    // windows.
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

    // TWO blobs now: the readout panel, then the swell.
    //
    // The panel arrives from OFF the screen and ends flush with the right edge,
    // so the approach is a real one: it reaches the band, merges with it, then
    // swells out to the left.
    //
    // The swell is the segment itself bulging under the cursor, the launch
    // edge's gesture transplanted to this edge: band thickness plus the
    // follower's few pixels, over exactly the rail's geometry, melting out of
    // the band rather than drawn on it. Dropped from the list below a hundredth
    // of a pixel so an idle rail contributes one parked blob rather than two.
    // NO level tick lives inside it, and that was considered: while anything is
    // active the readout's own track sits beside the segment at the same
    // centre, so a second mark carrying the same value a thumb's width from the
    // first would be the shell answering itself, and a nine pixel bulge has no
    // room to draw a level legibly anyway.
    readonly property var blobs: [
        {
            x: root.width - root.panelWidth + (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value),
            y: (root.height - root.panelHeight) / 2,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large
        }
    ].concat(swell.value <= 0.01 ? [] : [
        {
            x: root.width - (root.border + swell.value),
            y: rail.y,
            w: root.border + swell.value,
            h: rail.height,
            radius: Appearance.sizes.windowRadius
        }
    ])

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

    // WHAT ONE PIXEL OF DRAG IS WORTH: the whole range over the whole SEGMENT.
    //
    // One sweep from one end of the segment to the other covers everything the
    // volume can be, exactly once, so there is still no constant in here to
    // tune and the scale still derives from the thing under the hand
    // (~/.claude/rules/math-over-hardcoding.md); the thing under the hand has
    // simply become shorter. On the 1200px panel this was tuned on the segment
    // is ~360px, so a pixel is worth roughly 0.4% of volume: close to three
    // times the old full-edge sensitivity, and a full sweep is now a movement
    // of the wrist rather than of the whole arm, which is the right cost for a
    // control this size.
    //
    // Deliberately NOT the drawn track's length, still. The track in the panel
    // is 180px, about half the segment, so matching them would double the
    // sensitivity again to buy a correspondence nobody could see: the track and
    // the segment are not in the same place on the screen and never touch.
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

    Follow {
        id: swell

        target: root.held ? root.swellBy : 0
        speed: Appearance.anim.revealSpeed
        // A fifth of a pixel, the launch edge's epsilon for the launch edge's
        // reason: this whole motion is nine pixels, so Follow's default quarter
        // of a pixel would land it visibly short of where it was going.
        epsilon: 0.2
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

    // The panel's own hit area, following its left edge so the cursor can move
    // off the band and into the readout without leaving it, and keep scrolling
    // once it is there.
    //
    // DECLARED BEFORE THE RAIL, AND THE ORDER IS LOAD-BEARING. Declaration
    // order is input order in QML (Pull.qml's rule, leaned on here for hover
    // rather than for presses), and the two areas overlap: at rest this zone is
    // a border-wide strip over panelHeight, sitting inside the segment's
    // footprint on the same centre. Declared after the rail it was the topmost
    // of the two, and ShellWindow's measured doctrine (a hover goes to the
    // topmost item that accepts it and to that item's ancestors, and to nobody
    // else) played out exactly as written: hovering the segment set `active`,
    // one Follow tick of `reveal` cleared this zone's enable gate, and the zone
    // took the hover off the rail under a cursor that had not moved. `active`
    // never noticed, because it unions both areas and does not care which one
    // owns the hover; `held` reads the rail alone ON PURPOSE, so the swell
    // collapsed one beat after it began over the whole stretch of segment this
    // zone covers, and only ever held at the segment's uncovered ends. Declared
    // first, the rail is topmost over its own footprint and keeps its hover for
    // as long as the cursor is actually there, and this zone still hears
    // everything in the part the rail does not cover, which is the readout.
    // The rejected fix was teaching `held` the geometry (union this zone's
    // containsMouse, gated on the cursor being inside the segment's own
    // rectangle): that patches the symptom and leaves two siblings contesting
    // the same pixels, where ordering them ends the contest.
    //
    // Centred on the parent's height, which is the same middle the segment is
    // centred on, so gesture and reading coincide by construction: mid-drag the
    // readout sits directly beside the hand, and no offset had to be computed
    // to put it there. If the segment ever stops being centred this is the
    // binding to revisit.
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

    // THE RAIL, a centred fraction of the edge rather than a span between two
    // corner zones. The height is `grabFraction` of whatever height this screen
    // has and the centring is arithmetic on that same height, so the maths
    // survives any panel: there is no pixel count in the geometry to go wrong
    // on a taller screen, and the middle of the edge is the middle of the edge
    // everywhere.
    //
    // Declared AFTER `panelZone`, which is what makes `held` honest: input
    // order puts this area on top of their overlap, so the hover over the
    // segment belongs to the rail whenever the cursor is on it, panel out or
    // not. See panelZone's comment for the steal the other order produced.
    //
    // The DRAWN part is inside the band, which the chassis already covers. The
    // widened remainder of `grab` is claimed by the always-on `grabItem` entry
    // above, and from the press onward the implicit grab carries the drag
    // wherever it goes, mask or no mask, ON or OFF the segment: nothing below
    // gates on `containsMouse`, so a drag that runs past either end of the
    // segment mid-gesture keeps working until the release, exactly as it must.
    // While the panel is out its own entry covers the full width anyway, over
    // the height the panel occupies.
    MouseArea {
        id: rail

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.grab
        height: parent.height * Appearance.sizes.volumeGrabFraction

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
}
