import QtQuick
import qs.config
import qs.components
import qs.services

// The middle of the right edge is a volume rail: put the cursor on it and turn
// the wheel, or put a finger on it and push. Once it has opened, the thing that
// came out of the band is a SLIDER, with a handle you can take hold of.
//
// The gesture comes first and the readout second. Scrolling an edge is a thing
// you do without looking, so the rail answers the wheel whether or not anything
// is on screen; what comes out of the band is there to tell you where you landed.
//
// AND THEN IT IS ALSO SOMETHING TO AIM AT, which is the one sentence of this
// header that changed. The line above used to end "not to be aimed at", and that
// was a claim about the READOUT justified by a fact about the BAND: the band
// shows no scale, so a press on it cannot be aimed, so the rail is relative, so
// (the leap) the panel is a report rather than a control. The middle steps are
// still true and the conclusion never followed from them. The panel does show a
// scale, it is the only place in this shell that shows this one, and while it is
// open it sits under the hand that opened it: a control you can see and cannot
// touch is the worst of both, and on a touchscreen, where there is no hover to
// hold it open and no wheel to turn, it was the whole interface. So the meter
// grew a handle and the handle takes a press. What is unchanged is the BAND: no
// scale, no aiming, still relative; see `onPressed` at the bottom of this file
// for why that one must stay relative even now that its neighbour is not.
//
// The panel is therefore two controls in one body, which is not a contradiction
// but a division of labour by what each one can be aimed at. The band is the
// eyes-free half (a wheel notch, a shove with the thumb, no scale, no target).
// The panel is the deliberate half (a track, a mark at 100%, a handle to grab
// and a place to put it). The sound menu's slider remains the third way in and
// the only one you have to go looking for.
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
// WHAT THE READOUT SAYS, and it is three things: how loud, whether that is
// muted, and how much trouble the level is. The fill's HEIGHT carries the
// first, the glyph in the puck the second, and the fill's COLOUR the third.
// There was a percentage above the meter and it has gone. A number is an
// instrument's answer, and the paragraph at the top of this file says this is a
// glance: it repeated what the meter had already said, at a precision nobody
// reads off the edge of a screen, and it was three times wider than everything
// else in the panel put together, which is the single reason the readout
// measured 127 by 314 and looked like a box parked on the edge rather than
// something that had come out of it. The exact figure still exists where an
// exact figure belongs, on the sound menu's slider, which is the control you go
// to on purpose.
//
// AND IT IS DRAWN AS CAELESTIA DRAWS ITS OSD SLIDERS, which is a shape argument
// rather than a borrowed style. A bare fill states the value and nothing else:
// every part of it is the same object, so no part of it says "this end is the
// thing that moves", and a control whose moving part is invisible is one you
// can only ever nudge. So the fill gets a PUCK on its end, a circle exactly as
// wide as the track, with the level's own glyph inside it.
//
// Full width is the load-bearing part of that. It means the handle cannot be
// lost against the track, it means there is no overhang to find room for in a
// column on a screen edge, and it means the thing you can see and the thing you
// can hit are ONE SHAPE rather than a thin mark with an invisible target grown
// around it. Material's slider, which this replaced, is the opposite trade: a
// four-pixel bar and a gap either side to stop it reading as a seam. That is a
// beautiful drawing and the wrong one here, because the gap breaks the single
// line the eye is actually reading (how far up the colour has come) and because
// a four-pixel bar is a handle you aim at rather than one you grab.
//
// AND IT NEVER CHANGES SIZE. Material's handle narrows under the press and that
// went with it. On a mark you only point at, a shape change is the cheapest
// possible acknowledgement; on a thing you take hold of it is the thing under
// your finger deforming at the exact moment you grab it, which reads as the
// grab having gone wrong rather than as it having worked. What answers the
// press is the value moving and the colour changing, both of which are on the
// axis the gesture is actually about.
//
// THE COLOUR IS THE ONE PLACE IN THIS SHELL WHERE HUE MEANS SOMETHING. See
// `lit` for the whole argument; the short version is that "amplified" is not
// one state. Between 100% and the ceiling there is half again of gain, and one
// accent colour says the same sentence at 101% and at 150% when those are not
// the same situation. So the fill climbs a hazard ladder: the theme's accent
// while the level is normal, amber past 100%, red past halfway up the headroom.
//
// AND IT IS ONE BODY, which cost a bug to learn. The segment used to bulge under
// the cursor as a SECOND blob, the launch edge's gesture transplanted to this
// edge, and two blobs on one edge is precisely what DESIGN.md's section 14
// forbids: the shader melts each blob into the shell separately and then unions
// the results with a plain min, so a swell that reaches further out than the
// panel does at that height meets the panel's shoulder at a hard corner rather
// than a fillet. On the 1200px panel this was measured on, the segment is 360px
// and the readout was 314px, so the swell stood proud of each shoulder by
// twenty-three pixels: the outline ran down the band, turned out to the swell's
// straight edge, held that line for a dozen rows and then broke to the panel's
// top, which is a tooth bitten out of the readout's edge. Shrinking the readout,
// which the rest of this file does, would have made it worse rather than better:
// against the body it is now, 156px settled and 174 at full reach, the same
// swell would have stood proud of each shoulder by a hundred and two.
//
// It cannot be fixed by making the swell smaller, and that is the part worth
// writing down: a SECOND blob can never be seen without the panel, because
// `held` is a subset of `active` and so the panel is ALWAYS out whenever the
// segment is being touched. A swell shorter than the panel is hidden inside it
// and says nothing; a swell longer than the panel creases against it; there is
// nothing in between. So the bulge moved into the one rectangle, as height:
// while a hand is on it the body reaches a hair further ALONG the edge at each
// end, which is the same hair spent on the axis the rail actually runs down.
// Spending it SIDEWAYS was rejected outright, and not on taste: the readout's
// own hit area follows its left edge, so a body that retracted the moment the
// cursor stepped off the rail would pull that edge out from under the cursor
// that was arriving.
//
// AND A REACH NOBODY EVER SEES IS NOT AN ACKNOWLEDGEMENT, which the first
// version of that move was. `held` read the segment's own hover alone and both
// Follows run at `revealSpeed`, so on an approach from nothing the reveal and
// the reach left together and summed into one motion: the body simply arrived
// nine pixels taller at each end than it settles at, the settled height was
// never on screen during an approach at all, and the only moment the difference
// was ever drawn was the cursor sliding off the segment into the readout, where
// the body pulled IN from under the hand that was arriving. That is the
// sideways failure rejected in the paragraph above, turned ninety degrees. Two
// things fix it and both are structural rather than tuning: the reach waits for
// the reveal to LAND, so it is a second beat with nothing else moving, and
// `held` counts a hand anywhere on the body rather than on the segment alone,
// so the body only ever relaxes when nothing at all is touching it. The second
// one pays for itself twice, because it is also what lets the hit area be
// exactly the drawn shape instead of a frozen maximum; see panelZone.
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

    // How far the body reaches along the edge while noticed: a hair under the
    // gap, the launch edge's number for the launch edge's reason. Big enough to
    // see, small enough that it is an acknowledgement rather than a movement.
    readonly property real swellBy: Math.max(1, Appearance.sizes.gap - 1)

    readonly property real step: Appearance.sizes.volumeStep

    // Everything above 1.0 is amplification, so the rail runs to the same
    // ceiling the sound menu's slider does and marks where normal ends. A rail
    // that stopped at 100% would have nowhere to show the part worth warning
    // about.
    readonly property real ceiling: Audio.maxVolume
    readonly property real warnAbove: 1

    // WHERE "LOUD" BECOMES "TOO LOUD", which is the second of two lines rather
    // than a second opinion about the first. `warnAbove` is where the hardware
    // stops being asked for what it has and starts being asked for more, and it
    // is a fact about the sink. This one is a fact about the HEADROOM: halfway
    // up whatever amplification the ceiling allows. Derived rather than named,
    // so raising the ceiling moves it (~/.claude/rules/math-over-hardcoding.md);
    // a hardcoded 125% would sit at the halfway mark today and a third of the
    // way up a ceiling of 200, which is the wrong place for the same word.
    readonly property real dangerAbove: root.warnAbove + (root.ceiling - root.warnAbove) / 2

    readonly property bool muted: Audio.muted
    readonly property real volume: Audio.volume

    // THE FILL SAYS HOW LOUD IT IS ABOUT TO BE, in four states, and this is the
    // one place in the shell where colour carries meaning instead of weight.
    //
    // Everywhere else this material separates things by opacity and never by
    // inventing a second hue (see Appearance's ramp), and the rail used to obey
    // that: one colour at three weights, with the accent standing in for
    // "amplified". What that could not do is say HOW amplified. Between 100%
    // and the ceiling there is half again of gain that a sink will happily
    // apply to a track already mastered loud, and "the accent" is the same
    // sentence at 101% and at 150% when those are not the same situation. So
    // the ladder here is a hazard ladder: normal, warning, danger.
    //
    // The first rung is the THEME's accent, so "normal and loud" is the same
    // colour the rest of the shell is wearing. The other two are absolute, and
    // that is deliberate rather than an oversight: a warning colour that
    // changes with the palette is not a warning colour. Amber means amber on
    // every theme, which is the entire content of the mark. They live in Config
    // so they are tunable without a module knowing a hex value.
    //
    // Read off `shown` rather than off `volume`, so the colour turns under the
    // hand at the instant the handle crosses the line rather than after
    // PipeWire has agreed. Crossing a hazard line is exactly when a beat of lag
    // is worst.
    readonly property real shownVolume: root.shown * root.ceiling
    readonly property color lit: root.muted ? Appearance.colour.textFaint : root.shownVolume > root.dangerAbove ? Appearance.colour.volumeDanger : root.shownVolume > root.warnAbove ? Appearance.colour.volumeWarn : Appearance.colour.accent

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
    //
    // `grip.pressed` is the handle's half of the same argument. A hand holding
    // the handle is not hovering the band, may have dragged the pointer clean
    // off the panel, and on a touchscreen reports no hover at any point in the
    // gesture; without it the control would retract out from under the finger
    // that is working it.
    readonly property bool active: rail.containsMouse || rail.pressed || panelZone.containsMouse || grip.containsMouse || grip.pressed || linger.running

    // What drives the swell, and it is `active` MINUS the linger: a hand
    // somewhere on this thing, on the segment or on the readout the segment
    // opened, and nothing else. Folding in `linger` would stretch the body
    // every time a volume key is pressed from across the desk, and the reach is
    // the rail acknowledging a hand, not a readout of the value; the meter
    // already does that job. The `pressed` term carries the same weight it does
    // in `active`: a touch never hovers, and a drag is free to leave the
    // segment mid-gesture without the reach collapsing under the hand that is
    // still holding it.
    //
    // COUNTING THE READOUT'S OWN ZONE is the load-bearing half. Read off the
    // segment alone this went false the instant the cursor stepped off the
    // segment into the readout, and the body pulled in by nine pixels at the
    // top and at the bottom while the hand was still arriving: the header's
    // sideways failure on the other axis. The cure that was applied instead was
    // a hit area frozen at the body's maximum, and a frozen hit area claims
    // screen with nothing painted in it. Counted this way the body is at full
    // reach for as long as anything is touching it and relaxes only once
    // nothing is, so no edge of it can move under a pointer, and the claimed
    // region below can simply BE the drawn shape.
    //
    // This is NOT the fix panelZone's comment rejects. That one was to union
    // this zone's hover GATED on the cursor being inside the segment's own
    // rectangle: the geometry written a second time to paper over an input
    // order bug. This is the plain union of the two areas, and the ordering
    // below is untouched. The order still decides which of them owns the hover
    // over their overlap; this simply no longer cares which one won.
    readonly property bool held: rail.containsMouse || rail.pressed || panelZone.containsMouse || grip.containsMouse || grip.pressed

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

    // THE METER'S LENGTH, and it is the readout's one proportion.
    //
    // A count of the glyph that stands under it, so the meter is the body of
    // the column and the glyph is its foot, rather than two marks of a similar
    // size arguing about which of them is the reading. Sized off the icon
    // because that is the number every other mark in this shell is sized off
    // (the sidebar's slots, the tray, the settings corner all do exactly this),
    // so the whole readout rescales from one token instead of from a pixel
    // count that would stop matching the glyph the first time the icons moved.
    //
    // THE COUNT IS THE SETTING, and it is the one Config's `railLength` became.
    // That token was deleted for being a pixel length measured against a rail
    // which no longer exists, and its replacement went in here as a bare `* 3`,
    // which is the same stale-number failure with the name taken off: the one
    // proportion of the readout, sitting in a module, where whoever tunes the
    // look does not edit and no comment stands next to the other volume values.
    // Every comparable derived size in this shell keeps its multiplier in
    // Config and its arithmetic in Appearance (`wsIcon`, `trayIcon`,
    // `cornerIcon`, `sessionIcon`, `lockDot` are all exactly this), so this one
    // does too.
    //
    // What it replaced was 180, which was taller than everything else in the
    // panel put together and read as an instrument bolted to the edge. At this
    // length one wheel notch still moves the fill by more than the shell's own
    // hairline, which is the only thing the length actually has to buy: a step
    // you cannot see is a rail that looks broken while it is working.
    // HOW LONG THE TRACK IS, in nominal icons.
    //
    // Measured against `Appearance.font.iconSize` rather than against the drawn
    // glyph's own implicitHeight, and that is now load-bearing rather than
    // merely tidy. The glyph moved INSIDE the handle, and the handle's position
    // is computed from the travel, which is computed from this length: reading
    // the live glyph's height here would make the track's length depend on the
    // position of something the track's length decides, which is a binding loop
    // and not a subtle one. The nominal size is a constant, so the loop cannot
    // form. It is also the more correct measure for the same reason `panelWidth`
    // already used it: an icon font is only usually monospaced, and a panel
    // measured off what is currently drawn would resize as the level changed
    // the glyph.
    readonly property real meterLength: Appearance.font.iconSize * Appearance.sizes.volumeMeterGlyphs

    // THE TRACK AND THE PUCK THAT RIDES IT, both out of the one token.
    //
    // The handle is a CIRCLE EXACTLY AS WIDE AS THE TRACK, which is Caelestia's
    // rule for its OSD sliders and is worth taking whole. It settles three
    // things at once that were three decisions before: the handle can never be
    // lost against the track because it is the full width of it, there is no
    // overhang to find room for in the column, and it is big enough to be a
    // touch target at its drawn size rather than needing an invisible one grown
    // around it. A four-pixel bar with a hidden twenty-four-pixel target is a
    // control that lies about where it is; a thirty-pixel puck does not have to.
    //
    // AND IT NEVER CHANGES SIZE. Not on hover, not under the press, not while
    // dragging. The press used to narrow it, which is Material's own
    // acknowledgement and is wrong on a handle you are meant to hold: the thing
    // under your finger changing shape at the moment you take hold of it reads
    // as the grab having gone wrong. What answers the press is the value moving
    // and the fill's colour, which is plenty and is on the axis the gesture is
    // actually about.
    readonly property real trackWidth: Appearance.sizes.volumeRailWidth
    readonly property real handleSize: root.trackWidth
    readonly property real stopDot: Math.max(Appearance.font.stem, Math.round(root.trackWidth / 6))

    // THE PANEL, sized by what is in it rather than by a number picked here.
    // One column, one control: the glyph that used to stand under the meter is
    // in the handle now, so the readout is the slider and nothing else.
    readonly property real contentWidth: Math.max(root.trackWidth, Appearance.font.iconSize)
    readonly property real contentHeight: root.meterLength

    readonly property real panelWidth: root.border + root.contentWidth + Appearance.padding.large * 2
    readonly property real panelHeight: root.contentHeight + Appearance.padding.large * 2

    // The body's height as it is DRAWN, which is the panel plus whatever the
    // rail's acknowledgement is currently worth, at both ends. See the header:
    // this is where the old second blob went. The hit area is this same number
    // rather than its maximum, which is a thing `held` earns; see panelZone.
    readonly property real bodyHeight: root.panelHeight + swell.value * 2

    // ONE blob, and one is the whole point; see the header for the tooth that
    // two of them made.
    //
    // It arrives from OFF the screen and ends flush with the right edge, so the
    // approach is a real one: it reaches the band, merges with it, then swells
    // out to the left. It is a PERMANENT slot rather than one that empties,
    // because a blob that shrank in place would pull the band toward it the
    // whole way down and leave a bulge on the edge with nothing in it; parked a
    // full melt clear of the screen, the field at rest is the band and nothing
    // else. The park is measured with the SHELL's melt, which is never smaller
    // than this blob's own below, so it clears whatever the join turns out to
    // be worth.
    //
    // AND THE MELT IS DERIVED, not kept. A fillet is as wide as it is told to
    // be regardless of what it is filleting, so blob.frag's test is the melt
    // against the SMALLER half-dimension of the shape being joined, and reading
    // it against the long axis is reading it against the axis that was never in
    // danger. This body is 78 wide and 156 tall, so the number the melt has to
    // stay under is 39, and the shell's 34 clears it by five pixels: it passes
    // today, and it passes by an amount nobody would notice losing. Padding's
    // base moving 6 to 4 takes the width to 62 and puts 34 past half of it, and
    // the readout would quietly start being eaten by its own join with nothing
    // here to notice. Written as a minimum it cannot, which is the settings
    // corner's arithmetic for the settings corner's reason. Measured on the
    // SETTLED panel rather than on `bodyHeight`, so the reach does not animate
    // the shape of the join as well as the size of the body; the two are
    // different statements and only one of them is a movement.
    readonly property var blobs: [
        {
            x: root.width - root.panelWidth + (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value),
            y: (root.height - root.bodyHeight) / 2,
            w: root.panelWidth,
            h: root.bodyHeight,
            radius: Appearance.rounding.large,
            smooth: Math.min(Appearance.sizes.melt, Math.min(root.panelWidth, root.panelHeight) / 2)
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
    // Deliberately NOT the drawn meter's length, and the shrinking of that
    // meter has made the point louder rather than quieter. The meter is now
    // about a fifth of the segment, so matching them would multiply the
    // sensitivity by five to buy a correspondence nobody could see: the meter
    // and the segment are not in the same place on the screen and never touch.
    readonly property real perPixel: root.ceiling / Math.max(1, rail.height)

    // The same question asked of the PANEL's track, which is a different and
    // much shorter ruler: the whole range across `meter.travel` instead of
    // across the segment. Both gestures move the same value and neither can be
    // expressed in the other's pixels, which is why the detent below has to be
    // told which one it is arbitrating.
    readonly property real perTrackPixel: root.ceiling / Math.max(1, meter.travel)

    // EXACT UNDER A HAND, smoothed when the value moves on its own.
    //
    // components/Slider.qml's split, for its reason: a control that eases toward
    // your finger feels broken, and one that cuts when a media key moves it
    // looks broken. `dragged` is what the hand asked for, kept because the value
    // only comes back once PipeWire has agreed to it and rounded it to whole
    // percent on the way.
    //
    // The WHEEL is deliberately on the smoothed side of this line even though it
    // is also a hand: a notch is a step, and a fill that jumps between steps
    // reads as a series of states rather than as one thing being turned up. A
    // drag is not a step and must not be smoothed.
    property real dragged: 0
    readonly property bool dragging: rail.pressed || grip.pressed
    readonly property real shown: Math.max(0, Math.min(1, (root.dragging ? root.dragged : level.value) / root.ceiling))

    // A MAGNET AT 100%, and only for the gesture that can SEE the mark.
    //
    // 100% is the value you land on far more often than any other and the one
    // you cannot hit by hand, because on this track it is a single row of pixels
    // two thirds of the way up; but going past it is exactly what the range
    // above it is for, so the notch has to let go when you keep pulling. Within
    // a handle's thickness of the mark the value takes the mark exactly, and
    // past that the hand is obeyed: it catches, and you can pull through it.
    //
    // Measured in PIXELS OF HAND MOVEMENT converted through the ruler of
    // whichever gesture is asking, because what makes a detent feel right is how
    // far your hand has to move to escape it, and that is pixels rather than
    // percent. The same rule stated in percent would swallow a fifth of the
    // panel's short track and a twentieth of the band's long one.
    //
    // The BAND does not get one, and that is not an oversight. A magnet you
    // cannot see is a control sticking for no stated reason: on the panel the
    // stop dot is right there and the catch reads as landing on it, on the band
    // there is no mark, no scale and nothing to have landed on.
    function snap(v: real, perPixel: real): real {
        const reach = root.stopDot * 2 * perPixel;
        return Math.abs(v - root.warnAbove) < reach ? root.warnAbove : v;
    }

    // Ask for a value with a HAND: clamped, then SHOWN before it is sent. The
    // handle has to be where the finger put it this frame, and PipeWire cannot
    // answer before the next one.
    function put(v: real): void {
        const wanted = Math.max(0, Math.min(root.ceiling, v));
        root.dragged = wanted;
        level.value = wanted;
        Audio.setVolume(wanted);
    }

    Follow {
        id: reveal
        speed: Appearance.anim.revealSpeed
        target: root.active ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: swell

        // AFTER THE ARRIVAL, NOT WITH IT, and that gate is the whole of what
        // makes the reach legible. Both of these run at `revealSpeed`, so a
        // target read straight off `held` left at the same instant the reveal
        // did and the two summed into one motion: the body arrived at the
        // swollen height and its settled height was never drawn during an
        // approach at all. Held back until the reveal is home, the reach is a
        // second beat and the only thing on screen moving while it happens.
        // `settled` is exact equality rather than an epsilon test (see Follow),
        // so this cannot start against a body still a sliver short of place.
        //
        // Retracting is ungated on purpose: the pair leave together when the
        // hand does, which is one shape going away rather than a shape taking
        // its acknowledgement back and then leaving.
        target: root.held && reveal.settled ? root.swellBy : 0
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
    // a border-wide strip over the readout's height, sitting inside the
    // segment's footprint on the same centre. Declared after the rail it was
    // the topmost of the two, and ShellWindow's measured doctrine (a hover goes
    // to the topmost item that accepts it and to that item's ancestors, and to
    // nobody else) played out exactly as written: hovering the segment set
    // `active`, one Follow tick of `reveal` cleared this zone's enable gate,
    // and the zone took the hover off the rail under a cursor that had not
    // moved. `active` never noticed, because it unions both areas and does not
    // care which one owns the hover; `held` read the rail ALONE at the time, so
    // the reach collapsed one beat after it began over the whole stretch of
    // segment this zone covers, and only ever held at the segment's uncovered
    // ends. Declared first, the rail is topmost over its own footprint and
    // keeps its hover for as long as the cursor is actually there, and this
    // zone still hears everything in the part the rail does not cover, which is
    // the readout. The rejected fix was teaching `held` the geometry (union
    // this zone's containsMouse, GATED on the cursor being inside the segment's
    // own rectangle): that patches the symptom and leaves two siblings
    // contesting the same pixels, where ordering them ends the contest.
    //
    // `held` does union this zone now, ungated and for an unrelated reason (the
    // reach must not come in under a hand, see its own comment), and that union
    // is not a second cure for the steal and does not stand in for this order.
    // What it changes is the consequence: a steal that used to be fatal to the
    // reach is now merely a question of which of two areas reports the cursor,
    // and both answers mean the same thing downstream. The order still decides
    // who hears it, which is how it should be decided.
    //
    // EXACTLY THE DRAWN BODY, top to bottom, which it earns from the way `held`
    // is counted rather than from being careful. What you can hit is allowed to
    // be bigger than what is drawn (`grab` above is precisely that), and this
    // was: frozen at the body's tallest so that the reach coming in could not
    // shrink the readout out from under a cursor that had entered near the top
    // or the bottom. What that cost is the failure this file's own header
    // records for the old wheel-only rail. While the reach was in, two strips
    // of screen nine pixels tall and the readout's full width sat inside the
    // window's input region with nothing painted in them: a click on the window
    // there went to this surface, was refused by an area that takes no buttons,
    // and reached nothing at all. That is not a corner case, it is the ordinary
    // keyboard one, because a volume key opens the readout for a second and a
    // bit with the pointer parked wherever it already was.
    //
    // Since `held` counts this zone as well as the segment, the body is at full
    // reach whenever a pointer is anywhere inside it and comes in only once
    // none is, so tracking it takes nothing away from anybody: a pointer in
    // what used to be the frozen strip is a pointer holding the body out at
    // that size. The claim and the drawing are one rectangle again.
    //
    // Centred on the parent's height, which is the same middle the segment is
    // centred on, so gesture and reading coincide by construction: mid-drag the
    // readout sits directly beside the hand, and no offset had to be computed
    // to put it there. If the segment ever stops being centred this is the
    // binding to revisit.
    MouseArea {
        id: panelZone

        anchors.right: parent.right
        y: (parent.height - height) / 2
        width: Math.max(root.border, root.panelWidth - (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value))
        height: root.bodyHeight

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

            // THE SLIDER: a track, a fill rising from the bottom, and a puck
            // riding the top of the fill with the level's own glyph in it.
            //
            // Caelestia's OSD slider, which is where this shape comes from. The
            // fill starts at the handle's TOP EDGE rather than stopping short of
            // it, so the puck caps the fill instead of floating above a gap. The
            // gap it replaced was Material's, and Material needs one because its
            // handle is a four-pixel bar that would otherwise read as a seam in
            // the fill rather than as an object on it. A puck the full width of
            // the track has no such problem: it is already unmistakably a
            // different thing, and a gap beneath it only breaks the one line the
            // eye is actually reading, which is how far up the colour has come.
            Item {
                id: meter

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: root.contentWidth
                height: root.meterLength

                // WHERE THE HANDLE IS. It stays wholly inside the track's ends
                // rather than half hanging off them, so the full length of the
                // track is reachable and looks it.
                //
                // Nothing in this mapping moves when the handle is pressed,
                // because nothing about the handle moves when it is pressed; see
                // `handleSize`. The version before this had to be careful to
                // measure against a resting size the drawing then departed from,
                // and that entire class of care went away with the animation.
                readonly property real travel: Math.max(1, height - root.handleSize)
                readonly property real handleTop: (1 - root.shown) * travel
                readonly property real centre: handleTop + root.handleSize / 2

                // Where the mark at 100% sits, on the same mapping as the handle,
                // so the two coincide exactly when the value does.
                readonly property real markY: travel * (1 - root.warnAbove / root.ceiling) + root.handleSize / 2

                // THE TRACK: the whole range, always, at full length. A slider
                // that draws only the part you have used cannot say how much is
                // left, and on this control the part you have NOT used is the
                // part worth knowing about.
                G2Rect {
                    anchors.fill: parent
                    radius: width / 2
                    color: Appearance.colour.fillStronger
                }

                // HOW FAR IT HAS COME, and how alarming that is.
                //
                // Never shorter than the puck, so its own radius is always valid:
                // at zero the handle is parked at the bottom of the travel and
                // this is exactly the circle underneath it.
                //
                // The colour is the hazard ladder (see `lit`), and it CROSSFADES
                // rather than switching. The lines it crosses are real but the
                // crossing is not an event: a hard cut at 100% reads as the
                // control changing mode, when what is happening is one quantity
                // getting worse. Slow enough to see the change happen, short
                // enough that the colour is settled before you have finished
                // moving.
                G2Rect {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: meter.handleTop
                    width: parent.width
                    height: parent.height - y
                    radius: width / 2
                    color: root.lit

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                // WHERE NORMAL ENDS: a dot on the track at 100%, because the
                // range runs past it and without the mark the top third is
                // indistinguishable from headroom. It is not headroom, it is
                // amplification, and it is the line the fill changes colour on.
                //
                // A dot rather than a rule across the track, because the track is
                // wide enough now that a rule reads as the track being cut in two
                // there. It takes its weight from whichever surface is actually
                // behind it, asked of the FILL'S OWN TOP EDGE rather than of the
                // value: "is the volume past 100" and "is the fill under the dot"
                // are the same question only if the fill ends exactly at the
                // value, and it ends at the top of a thirty-pixel puck.
                G2Rect {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: meter.markY - height / 2
                    width: root.stopDot
                    height: root.stopDot
                    radius: width / 2
                    color: meter.handleTop <= meter.markY ? Appearance.colour.surfaceSolid : Appearance.colour.textDim
                }

                // THE HANDLE: a puck the full width of the track, with the
                // level's own glyph in it. The one thing here that is an object
                // rather than a measurement, and the only thing you take hold of.
                //
                // It does NOT take the hazard colour, and that is deliberate. The
                // fill is the quantity and the puck is the grip; if the grip went
                // red too there would be nothing on the control that stayed put,
                // and the one mark you are meant to aim at is the worst one to
                // keep repainting. It also has to stay legible against green,
                // amber and red in turn, and the top of the ramp is the only
                // colour that manages all three.
                G2Rect {
                    x: (meter.width - width) / 2
                    y: meter.handleTop
                    width: root.handleSize
                    height: root.handleSize
                    radius: width / 2
                    color: Appearance.colour.text

                    // THE GLYPH RIDES THE PUCK, which is the other half of what
                    // Caelestia's slider does and the reason this readout is one
                    // column rather than two things stacked. Standing under the
                    // meter it said "muted or not" about a value drawn somewhere
                    // else; in the puck it is ON the value, moves with it, and
                    // the crossed-out speaker lands exactly where you are already
                    // looking. Read off `shownVolume` so it changes under the
                    // hand rather than after PipeWire has agreed.
                    //
                    // Dark on light, which is the one inversion in this shell,
                    // and it is earned: the puck is the only surface in the panel
                    // that is not the panel's own body.
                    Icon {
                        anchors.centerIn: parent
                        name: Audio.icon(root.shownVolume, root.muted)
                        color: Appearance.colour.surfaceSolid
                    }
                }

                // TAKE HOLD OF IT.
                //
                // The whole track, so the bar itself is the control rather than
                // a picture of one next to a control. Grown sideways only to this
                // shell's floor for anything you are meant to hit (WCAG 2.2 SC
                // 2.5.8, and `minTarget` is where that number lives), which at a
                // thirty-pixel track is nothing at all: the drawing is already
                // bigger than the minimum, which is the point of drawing it this
                // size.
                //
                // Declared LAST, so it is topmost over the marks it drives and no
                // part of the drawing can take a press off it.
                MouseArea {
                    id: grip

                    anchors.fill: parent
                    anchors.leftMargin: -Math.max(0, (Appearance.sizes.minTarget - meter.width) / 2)
                    anchors.rightMargin: anchors.leftMargin

                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                    // The grab is this control's from the press and nothing may
                    // take it back. Nothing is currently in a position to try,
                    // and that is precisely why it is written down: the panel is
                    // a lid over a screen edge and everything around it is a
                    // gesture surface.
                    preventStealing: true

                    // HOW FAR THE HAND IS FROM THE PUCK'S CENTRE, kept from the
                    // press so the puck does not teleport under it. Grab it by
                    // its lower edge and it stays grabbed by its lower edge; a
                    // slider that recentres on the finger throws the value away
                    // at the instant you take hold of it, which on a touchscreen
                    // is the instant your finger covers the answer.
                    property real offset: 0

                    // ABSOLUTE HERE, and relative on the band, which is the one
                    // real decision in this file restated for the half of the
                    // control that reversed it. The band is a uniform strip with
                    // no scale on it, so a press there cannot be aimed and an
                    // absolute mapping would commit to a number you had no way to
                    // choose; a palm brushing it would slam the output to half
                    // again above full. This track shows its whole range, its
                    // ends, its puck and the mark at 100%. Everything the relative
                    // mapping was protecting you from not being able to see, you
                    // can see. So a press on the track means the value under the
                    // press, which is what a slider has trained everyone to expect
                    // and what makes one movement enough.
                    function report(y: real): void {
                        const f = 1 - (y - root.handleSize / 2) / meter.travel;
                        const v = Math.max(0, Math.min(1, f)) * root.ceiling;
                        root.put(root.snap(v, root.perTrackPixel));
                    }

                    // Mapped into the meter rather than offset by the margins
                    // above: undoing those by hand means writing the same number
                    // twice with opposite signs, and components/Slider.qml
                    // already wrote one of them with the wrong one.
                    onPressed: mouse => {
                        const y = grip.mapToItem(meter, mouse.x, mouse.y).y;

                        // ON THE PUCK, keep it where it is and follow the hand
                        // from there. ANYWHERE ELSE on the track, come to the hand
                        // first and follow it after, so one press-and-drag both
                        // lands on a value and keeps adjusting it. "On the puck"
                        // is the puck's own radius, which needs no padding now
                        // that the puck is the full width of the track: the thing
                        // you can hit and the thing you can see are one shape.
                        if (Math.abs(y - meter.centre) <= root.handleSize / 2) {
                            grip.offset = y - meter.centre;
                        } else {
                            grip.offset = 0;
                            grip.report(y);
                        }
                    }

                    onPositionChanged: mouse => {
                        if (grip.pressed)
                            grip.report(grip.mapToItem(meter, mouse.x, mouse.y).y - grip.offset);
                    }

                    // A TOUCH HAS NO HOVER TO LEAVE BEHIND. The mouse can let go
                    // of the puck and the panel stays out because the cursor is
                    // still on it; a finger lifting reports nothing at all, and
                    // without this the panel would leave at the same instant as
                    // the finger, taking the result of the adjustment with it.
                    onReleased: linger.restart()

                    onWheel: wheel => root.nudge(wheel)
                }
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
    // Declared AFTER `panelZone`, which is what keeps this area's own hover
    // honest: input order puts it on top of their overlap, so the hover over
    // the segment belongs to the rail whenever the cursor is on it, panel out
    // or not. See panelZone's comment for the steal the other order produced,
    // and for why `held` unioning both areas is not a substitute for it.
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
        // AND THE PANEL NOW HAS A HANDLE, which is an argument FOR this staying
        // relative rather than against it. The obvious reading of the handle is
        // that the band should become absolute to match, and it is the wrong way
        // round: the two halves of this control are not two styles of the same
        // gesture, they are the eyes-free one and the aimed one, and each takes
        // the mapping its own surface can support. Making the band absolute
        // would take the aimed gesture, which now has a proper home four
        // centimetres to the left, and put it back on the one surface that
        // cannot show you what you are aiming at, reintroducing the palm-brush
        // hazard above in exchange for nothing.
        //
        // UP IS LOUDER. Not a fourth convention: it is the direction the panel's
        // own track already fills (from the bottom), the direction its handle
        // travels, and the direction the wheel already means. One fact stated
        // several times rather than several conventions to keep straight.
        onPressed: mouse => {
            rail.fromY = mouse.y;
            rail.fromVolume = Audio.volume;
        }

        // `mouse.y` raw, unlike Pull's parent-coordinate anchor. That trick
        // exists to cancel the drift of an item whose own top-left moves under
        // the gesture; this one is pinned to a fixed edge at a fixed height and
        // cannot move, so there is nothing to cancel and the offset would only
        // be a number written twice.
        //
        // Through `put` rather than straight to Audio, so the handle tracks the
        // finger EXACTLY while it is down instead of easing after it. A drag
        // from the band and a drag on the handle are the same hand moving the
        // same value, and only one of them looking like it is catching up would
        // read as the band being the sloppier of the two.
        onPositionChanged: mouse => {
            if (rail.pressed)
                root.put(rail.fromVolume + (rail.fromY - mouse.y) * root.perPixel);
        }

        // THE TAP THAT MOVES NOTHING is the one that has to leave the panel out.
        //
        // On a touchscreen this band is the only way to open the panel at all:
        // there is no hover, so `active` cannot become true until something
        // presses, and the press is this one. A finger that lands, opens the
        // panel and lifts without dragging has changed no volume, so `linger`
        // was never restarted, so the panel leaves with the finger, and the
        // handle it just revealed was on screen for as long as the touch lasted
        // and never once available to be grabbed. Restarted here, a tap on the
        // edge is exactly what it looks like: a way of asking for the control.
        onReleased: linger.restart()

        onWheel: wheel => root.nudge(wheel)
    }
}
