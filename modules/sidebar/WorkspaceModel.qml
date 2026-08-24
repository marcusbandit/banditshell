pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// The workspace column's LAYOUT, MOTION and SCRUB, with no opinion about how
// any of it looks.
//
// Every style in this directory draws the same numbers: which workspaces there
// are, what is on each, how tall each one is, and where each one sits while the
// column is rearranging itself. Only the drawing differs, so only the drawing
// should be written twice.
//
// THE VERTICAL RHYTHM IS THE STYLE'S TO SET. A slot is `base` tall with one row
// on it and `pitch` taller for each row after that, which covers a stack of icon
// tiles (base 28, pitch 20), a stack of hairline bars (base 6, pitch 9) and a
// single row of blocks (pitch 0) without any of them being special-cased.
Item {
    id: root

    property int base: Appearance.sizes.wsSlot
    property int pitch: Appearance.sizes.wsWindowPitch
    property int gap: Appearance.sizes.wsGap

    // WHETHER THE STYLE DRAWS APPLICATIONS OR WINDOWS, which is the one thing
    // about a workspace's contents the model cannot decide for itself.
    //
    // A style that draws a MARK per window wants a run of one application's
    // windows folded into one mark and a number (Hypr.stackClients): the mark
    // says which application, and twelve copies of it say nothing twelve times. A style that draws the LAYOUT does not: `map` gives every window a
    // bar as long as the window is wide, and folding twelve tiled terminals into
    // one bar would be a picture of a screen that is not there. So the styles
    // that draw pictures of applications ask for this and the ones that draw
    // pictures of screens leave it alone.
    //
    // It has to be here rather than in the style because it changes the layout:
    // a stack is one ROW, and how many rows a workspace has is how tall it is.
    property bool stack: false

    // HOW MANY MARKS SHARE A ROW, for a style that lays them out sideways.
    //
    // One is a column of marks, which is what `plates` and `map` draw and what
    // every number in here assumed. `blocks` is the other shape: it puts a
    // square per window in a ROW, and a row is only as wide as the band, so past
    // a certain count it has to wrap. How many fit is a fact about that style's
    // own geometry, so the style works it out and hands it in; what the model
    // does with it is turn a count of marks into a count of LINES, which is the
    // only part that is height and therefore the only part that is the model's.
    property int perRow: 1

    readonly property int count: Hypr.count

    // WHICH SCREEN'S COLUMN THIS IS, by output name.
    //
    // The sidebar is drawn on every monitor and always has been, but until
    // bands existed every one of those columns asked shell-wide questions and
    // got the FOCUSED screen's answers, so two monitors drew the same
    // workspaces and lit the same plate: the second screen's sidebar was a
    // copy of the first one's rather than a picture of itself. This property
    // is the whole fix, and everything below it is that one string spent.
    //
    // A NAME rather than a ShellScreen, because that is what every question in
    // Hypr is keyed by (`specialByMonitor`, `occupancy`, `activeByMonitor`):
    // the compositor talks about outputs by name, and carrying the object here
    // would only mean unwrapping it three times. Empty is survivable and means
    // the first band, which is what every column drew before this existed.
    required property string screen

    // THE RUN OF WORKSPACES THIS COLUMN OWNS, resolved once here and spent
    // everywhere: slot i is `band + i`, and the ids it produces are real
    // workspace ids, so `Hypr.switchTo` and `Hypr.clientsIn` mean exactly what
    // they always meant. Nothing in this file or in a style knows the number
    // one any more (see ~/.claude/rules/math-over-hardcoding.md); they know an
    // index into a run whose start is a fact about the screen.
    readonly property int band: Hypr.bandFor(root.screen)

    function idAt(i: int): int {
        return root.band + i;
    }

    // WHERE THIS SCREEN IS, which is not where the KEYBOARD is. A monitor has
    // its own active workspace whether or not it is focused, so the column on
    // the screen you are not looking at still lights the plate you left it on,
    // and moving the keyboard between monitors changes which column is beside
    // the accent rather than what any of them say.
    readonly property int active: Hypr.activeOn(root.screen)

    // THE SPECIAL LYING OVER THIS SCREEN, carried by the MODEL rather than read
    // from Hypr by each style. Every style already shares this object for its
    // geometry, and "you are on a workspace you cannot currently see" is a
    // fact about the column, not about any one drawing of it: a style derives
    // its ghost as `isActive && eclipsed` and inherits sane behaviour the day
    // it learns to draw specials at all. Asked of Hypr in each file instead,
    // blocks and map would ship with the accent sitting on a covered plate
    // until someone noticed, which is exactly the per-style branching the
    // model exists to prevent.
    //
    // PER SCREEN, through the map Hypr has kept all along rather than through
    // `specialShown`: a scratchpad is pulled over ONE monitor, so a card
    // opened on the laptop must not grey out the plate you are standing on
    // over on the desk. That was the same mistake as the active workspace,
    // wearing the other costume.
    //
    // `special` is the wire name ("special:magic", "" when none), for the one
    // style question `eclipsed` cannot answer: WHICH card is out, so the rack
    // can light the right bar and the card can know it is the one travelling.
    readonly property string special: Hypr.specialOn(root.screen)
    readonly property bool eclipsed: special !== ""

    // THE LAYOUT: { id, y, h, windows, marks } per slot, in one pass. Where slot i
    // sits depends on what the slots above it are holding, so nothing knows its
    // own y and adding a workspace or a window changes only the data this runs
    // over (see ~/.claude/rules/math-over-hardcoding.md).
    //
    // BOTH LISTS, because the two questions are different ones: `windows` is
    // everything that is on the workspace, and `marks` is what a column draws
    // one of each of, which with `stack` off is the same list wearing a count of
    // one. The height comes from `marks`, because rows are what take up room.
    //
    // NOTHING IS TRUNCATED HERE ANY MORE. A workspace used to cap at
    // `maxWindows` and spend its last row on an "and more" ellipsis, so a busy
    // workspace was drawn as four windows and a shrug: the cap existed because
    // twenty identical terminal glyphs would run the column off the screen, and
    // stacking is the answer to that which does not throw anything away. Twenty
    // windows of twenty different applications now draw twenty marks, which is
    // what a column of applications is FOR.
    readonly property var slots: {
        const out = [];
        let y = 0;
        for (let i = 0; i < root.count; i++) {
            const id = root.idAt(i);
            const windows = Hypr.clientsIn(id);
            const marks = root.stack ? Hypr.stackClients(windows) : windows.map(w => ({
                        client: w,
                        cls: Hypr.classOf(w),
                        count: 1
                    }));

            // WHERE EACH MARK SITS, in rows from the top of the slot, and how
            // many rows the lot of them come to. Counted here rather than in the
            // style for the same reason the slot's own y is: a mark's place
            // depends on what is above it, so nothing can know its own
            // (~/.claude/rules/math-over-hardcoding.md).
            for (let m = 0; m < marks.length; m++) {
                // Which line it lands on and how far along it, which is only ever
                // interesting to a style that WRAPS: down a column each mark is
                // its own line, and `blocks` fills a line before starting another.
                marks[m].row = Math.floor(m / root.perRow);
                marks[m].col = m % root.perRow;
            }
            const rows = Math.max(1, Math.ceil(marks.length / root.perRow));

            const h = root.base + (rows - 1) * root.pitch;
            out.push({
                id,
                y,
                h,
                windows,
                marks
            });
            y += h + root.gap;
        }
        return out;
    }

    readonly property real total: root.live.length ? root.live[root.live.length - 1].y + root.live[root.live.length - 1].h : root.base

    // THE MOTION, smoothed HERE and once, for the same reason the layout is one
    // pass: everything drawn on a slot has to agree with it to the pixel. Two
    // components chasing the same target with the same maths still disagree for a
    // frame at a time, and a plate half a pixel behind its own icons reads as a
    // wobble.
    //
    // Exponential smoothing, as everywhere else in this shell: fast when far,
    // gentle when close, correct at any frame time (see
    // ~/.claude/rules/animation-smoothing.md).
    property var live: []

    function at(i: int): var {
        return root.live[i] ?? root.slots[i] ?? ({
                y: 0,
                h: root.base
            });
    }

    readonly property bool moving: {
        if (root.live.length !== root.slots.length)
            return true;
        for (let i = 0; i < root.slots.length; i++)
            if (root.live[i].y !== root.slots[i].y || root.live[i].h !== root.slots[i].h)
                return true;
        return false;
    }

    function step(dt: real): void {
        const f = 1 - Math.exp(-Appearance.anim.trackSpeed * dt);
        const n = Math.max(root.live.length, root.slots.length);

        // Where a slot that no longer exists collapses to: the end of the column
        // it used to be part of.
        const last = root.slots[root.slots.length - 1];
        const end = last ? last.y + last.h : 0;

        const out = [];
        for (let i = 0; i < n; i++) {
            const t = root.slots[i] ?? ({
                    y: end,
                    h: 0
                });
            const l = root.live[i];
            // A slot that did not exist a moment ago starts FLAT rather than at
            // its full height, so it grows into the column instead of shoving it.
            if (!l) {
                out.push({
                    y: t.y,
                    h: 0
                });
                continue;
            }
            // Close enough to land. Exponential decay is asymptotic, so without
            // this the timer would tick forever getting nowhere.
            out.push({
                y: Math.abs(t.y - l.y) < 0.25 ? t.y : l.y + (t.y - l.y) * f,
                h: Math.abs(t.h - l.h) < 0.25 ? t.h : l.h + (t.h - l.h) * f
            });
        }

        // A ghost is dropped once it has finished collapsing, and only from the
        // END: workspaces are numbered from 1, so the list can only ever shrink
        // there. Both numbers have to have landed, or the column's total height
        // jumps by whatever was left of it.
        //
        // NEVER WHILE A PRESS IS DOWN. The styles size their slot Repeaters by
        // this list, so a pop destroys the last delegate, and that delegate can
        // be the doorway HOLDING THE GRAB: scrubbing up off a trailing empty
        // workspace collapses the very slot the hand pressed on, and Qt does
        // not promise `canceled` to an item mid-teardown, so the drag would die
        // silently under a hand still moving and could leave the gesture state
        // latched. A landed ghost is flat and draws nothing, so it simply waits
        // the press out, and the tick after the release drops it. Held HERE
        // rather than guarded in each style, because the model is the one place
        // that knows a press is live at all.
        while (!root.scrubHeld && out.length > root.slots.length && out[out.length - 1].h === 0 && out[out.length - 1].y === end)
            out.pop();

        root.live = out;
    }

    // A NEW SLOT IS FLAT UNTIL THE TIMER GETS TO IT. Without this it draws at
    // full height for the one frame between the count changing and the first
    // tick, and since the column is centred in the bar, one frame of full height
    // is a visible jolt of half a slot.
    //
    // This is the whole reason switching to a workspace that was not on the list
    // yet used to snap: workspace 6 appearing made the column 40px taller
    // instantly, so everything above it moved 20px, in no time at all.
    // DEFERRED, not immediate: `moving` reads both lists, so assigning one of
    // them from inside the other's change handler invalidates a binding while it
    // is still being evaluated, and Qt calls that a loop and gives up on it.
    // callLater runs before the frame is drawn, which is all this needs.
    onSlotsChanged: Qt.callLater(root.pad)

    function pad(): void {
        if (root.live.length >= root.slots.length)
            return;
        const out = root.live.slice();
        for (let i = out.length; i < root.slots.length; i++)
            out.push({
                y: root.slots[i].y,
                h: 0
            });
        root.live = out;
    }

    function snap(): void {
        root.live = root.slots.map(s => ({
                    y: s.y,
                    h: s.h
                }));
    }

    // THE SCRUB: a vertical drag anywhere on the numbered column, stepping the
    // active workspace along it, so a finger changes workspace without aiming
    // at a plate. It lives HERE rather than in the style because the gesture
    // has several doorways: the plates' slot targets, the window rows lying on
    // top of them, and the backstop under the gaps all take presses, and
    // whichever one a hand lands on must be the same gesture. Tracked
    // per-area it would be three gestures that disagree about where the drag
    // began; fed through these three functions it is one, owned by the object
    // every doorway already shares.
    //
    // Coordinates arrive in the WINDOW's frame: every caller maps its own
    // mouse point all the way out to the scene before handing it over. That
    // is Pull's parent-frame anchor, generalised one step further. The map
    // reads the chain's offsets as they are NOW, so a slot gliding through a
    // reflow or a plate giving up its hover swell cancels out of the
    // difference and only the hand's own travel remains.
    //
    // The column's OWN frame, which this measured in first, is not still
    // enough to be the anchor. The column is centred in the sidebar and its
    // height IS the data: a window mapping or closing ANYWHERE re-centres it
    // mid-gesture, whether or not the scrub caused it, and a shift read back
    // through a moving frame is indistinguishable from hand travel
    // (components/Pull.qml, the stationary-parent caveat). Half a pitch of
    // phantom travel lands as phase in the ratchet, and one sharp event of it
    // can shove the smoothed velocity past the flick threshold, so a release
    // just after someone else's window closed could switch workspaces on its
    // own. The window is the one frame the world cannot move, so the scrub
    // measures against it and the column is free to rearrange itself under
    // the gesture.
    //
    // AND TWO FINGERS ON A TOUCHPAD ARE THE SAME GESTURE, through the same
    // three functions rather than beside them. A scroll reports motion and
    // never a position, so it has no window point to anchor with; what it
    // hands over is the TOTAL travel since the stream began, which is exactly
    // the number the drag path computes for itself one line into scrubMove
    // (`y - scrubFromY`). Fed in from an origin of zero, the arithmetic below
    // is then identical in both signs and for both inputs: one ratchet, one
    // angle test, one clamp and one flick, so the two can never drift into
    // disagreeing about what a swipe down the column means. A scroll path
    // with a ratchet of its own would have been a second opinion to keep in
    // step by hand, which is the thing the three doorways were already merged
    // into one gesture to avoid. See components/ScrollGesture.qml for how a
    // stream is told from a wheel, which way its signs run, and why its end
    // has to be inferred from silence.

    // ONE WORKSPACE OF TRAVEL IS THE SETTLED ONE-ROW PITCH: base plus gap,
    // the same two numbers every slot in `slots` is built from. Deliberately
    // NOT each slot's drawn height: a busy plate is taller than an idle one,
    // so measuring the hand against the drawn column would price the step to
    // workspace three differently from the step to workspace four depending
    // on what happens to be open, and a drag must never be measured against a
    // dimension the world can change under it (DESIGN.md 15). Equal
    // workspaces, equal travel.
    readonly property real scrubPitch: root.base + root.gap

    // Whether a press is being tracked, whether it has latched into the
    // scrub, and whether it has disqualified itself by setting off sideways.
    // `scrubSpent` is Pull's `spent`, for Pull's reason: a press that was
    // aimed across the column was aimed at something else, and it must not be
    // allowed to become a tap later by wandering back.
    property bool scrubHeld: false
    property bool scrubbing: false
    property bool scrubSpent: false

    // The anchor, and it is a RATCHET rather than a fixed origin: every fired
    // step advances it by one pitch, so the next boundary is a whole pitch
    // away in EITHER direction. Zones cut across a fixed origin would leave a
    // boundary one pixel behind every step just fired, and a hand resting on
    // one would flap the desktop between two workspaces at tremor rate; the
    // ratchet is a full pitch of hysteresis without inventing a second
    // threshold.
    property real scrubFromX: 0
    property real scrubFromY: 0

    // Where the count started and how far it has run: the workspace that was
    // active at the press, and the net boundaries crossed since. The step is
    // clamped to the column WHILE FIRING, not merely at dispatch: an
    // over-drag past the end must not bank steps, or pulling back from the
    // bottom of the column would spend its first pitches paying off a debt
    // before the desktop moved at all. Clamped, the first pitch of reversal
    // reverses.
    //
    // CLAMPED TO THIS SCREEN'S BAND, which is the same clamp said in the only
    // terms that mean anything now: the ends of the column are `band` and
    // `band + count - 1`, and running off the bottom of the second monitor's
    // column must not scrub into the first monitor's workspaces. A scrub is a
    // gesture on a screen, and it can only reach as far as that screen's run.
    property int scrubBase: 0
    property int scrubStep: 0
    property bool scrubFired: false

    // The velocity, smoothed the same way, with the same constant, as Pull
    // and the bottom edge: the last single event before a finger lifts is
    // noise as often as it is direction.
    property real scrubLastY: 0
    property real scrubVelocity: 0

    // THE PRESS DOORWAY, which is the shared start plus one thing only a
    // press has to do: TAKE THE GESTURE OVER from a scroll stream that is
    // still coasting. `finish` ends that stream by its own rule, so whatever
    // the fingers did is answered before the hand's gesture starts from where
    // it landed, and it is a no-op when nothing is running, which is nearly
    // always.
    //
    // Neither alternative survives being written down. Dropping the stream
    // silently would leave the desktop wherever its last event scrubbed it
    // with no release ever run, so a flick that was on its way to one more
    // workspace simply stops. Leaving it running is worse: its next total
    // arrives measured from zero while `scrubFromY` now holds a window
    // coordinate several hundred pixels down the screen, and that difference
    // is a whole column's worth of pitches in one event, which the clamp
    // would land on workspace one. Then its lapse would call scrubRelease
    // under a hand still holding the press, and the press's own release would
    // find nothing latched and fire a TAP for a gesture that had scrubbed.
    //
    // The one thing the takeover can be caught by is a flick firing on the
    // way out while `scrubBase` below reads the workspace it was flicked
    // FROM, because Hyprland answers a switch over IPC and not within the
    // call. It needs a press landing inside the coast of a thrown scroll,
    // roughly a tenth of a second, and the same staleness already exists for
    // a tap that lands that soon after any other switch. Buying it back would
    // mean re-reading the base after the first step, which is a second source
    // of truth for where the scrub started, and the ratchet is built on there
    // being one.
    function scrubPress(x: real, y: real): void {
        scroll.finish();
        root.scrubBegin(x, y);
    }

    // What both inputs actually start from, and the reason it is not simply
    // the body of scrubPress: a stream cannot take ITSELF over. By the time
    // `began` reaches the handler below, the primitive has already marked the
    // gesture live, so a `finish` from in here would end the stream that is
    // still being started, fire `ended` into a scrub nobody has begun yet,
    // and hand the following event a gesture with no state behind it.
    function scrubBegin(x: real, y: real): void {
        root.scrubHeld = true;
        root.scrubbing = false;
        root.scrubSpent = false;
        root.scrubFromX = x;
        root.scrubFromY = y;
        root.scrubBase = root.active;
        root.scrubStep = 0;
        root.scrubFired = false;
        root.scrubLastY = y;
        root.scrubVelocity = 0;
    }

    function scrubMove(x: real, y: real): void {
        if (!root.scrubHeld || root.scrubSpent)
            return;

        const vstep = y - root.scrubLastY;
        root.scrubLastY = y;
        root.scrubVelocity += (vstep - root.scrubVelocity) * 0.4;

        if (!root.scrubbing) {
            const dx = x - root.scrubFromX;
            const dy = y - root.scrubFromY;

            // Still inside the wobble of a click, so nothing is decided yet.
            // `dragThreshold` rather than Pull's larger slack, because the
            // only competition here is the tap: there is no second gesture on
            // the column for a hair-trigger to steal from, and a scrub that
            // starts tracking early is a scrub that feels attached to the
            // hand.
            if (Math.hypot(dx, dy) < Appearance.sizes.dragThreshold)
                return;

            // Decided ONCE, at the moment the press becomes a gesture, the
            // way Pull decides its direction. More across the column than
            // along it is not this gesture, and it does not get to be a tap
            // either.
            if (Math.abs(dy) <= Math.abs(dx)) {
                root.scrubSpent = true;
                return;
            }

            root.scrubbing = true;
        }

        // Crossing a boundary fires the switch IMMEDIATELY, not at release:
        // the whole point of scrubbing is watching the right workspace arrive
        // under your hand, and a switch saved up for the lift would be
        // operating the column blind, with the desktop as the answer instead
        // of the preview. Math.trunc, toward zero, so the arithmetic is the
        // same drag in both signs.
        const inc = Math.trunc((y - root.scrubFromY) / root.scrubPitch);
        if (inc === 0)
            return;
        root.scrubFromY += inc * root.scrubPitch;

        // `band` and `count` are read at fire time, not saved at the press:
        // window events land whenever they land, and the clamp should hold the
        // scrub to the column as it is, not as it was.
        const next = Math.max(root.band - root.scrubBase, Math.min(root.band + root.count - 1 - root.scrubBase, root.scrubStep + inc));
        if (next === root.scrubStep)
            return;
        root.scrubStep = next;
        root.scrubFired = true;
        Hypr.switchTo(root.scrubBase + next);
    }

    // Returns whether the press was CONSUMED by the gesture: latched or
    // spent, either way the release means nothing more. Callers tap only when
    // this says the press stayed a press, which is Pull's `tapped` contract
    // read from the other end; they must never trust MouseArea's own
    // `clicked`, which still fires for a press that scrubbed and ended back
    // inside its own slot.
    function scrubRelease(): bool {
        const consumed = root.scrubbing || root.scrubSpent;

        // THE FLICK: released still moving past `flickVelocity` with no
        // boundary crossed steps one workspace the way it was thrown. A flick
        // is an intention expressed as speed, and asking it to also cover a
        // full pitch is asking it twice; the notification card's throw
        // learned this first. Only when nothing fired, though: a scrub that
        // already switched has been answered continuously the whole way, and
        // a bonus step at the lift would overshoot the workspace the hand had
        // settled on. Down the screen is down the column: y grows downward
        // and so do the ids, so the velocity's sign is the direction.
        if (root.scrubbing && !root.scrubFired && Math.abs(root.scrubVelocity) >= Appearance.sizes.flickVelocity) {
            const to = root.scrubBase + (root.scrubVelocity > 0 ? 1 : -1);
            if (to >= root.band && to < root.band + root.count)
                Hypr.switchTo(to);
        }

        root.scrubHeld = false;
        root.scrubbing = false;
        root.scrubSpent = false;
        return consumed;
    }

    // A grab torn away mid-gesture: no flick, no tap, just let go of the
    // state. Whatever fired has fired; the scrub never rolls the desktop
    // back, because every switch it made was watched and meant.
    function scrubCancel(): void {
        root.scrubHeld = false;
        root.scrubbing = false;
        root.scrubSpent = false;
    }

    // THE SCROLL DOORWAY, which every surface that already has a press
    // doorway wires itself into with one line of its own onWheel. It lives
    // here beside the other four for the reason the whole scrub does: the
    // column has several surfaces and they must all be the same gesture, and
    // a style that learns to be scrubbed gets the fingers in the same commit
    // it gets the hand. The answer is passed straight back because the
    // primitive has already written it into the event, so a caller that
    // ignores it is still correct and a mouse wheel still falls through to
    // whatever wanted it, which over this column is nothing at all.
    function scrubWheel(wheel: var): bool {
        return scroll.feed(wheel);
    }

    ScrollGesture {
        id: scroll

        // A press owns the column for as long as it is down. `scrubHeld` is
        // true for whichever input is holding the scrub, so the second term
        // is this gesture recognising its own hold: without it the flag its
        // own `began` sets would read as somebody else's. Nothing is lost by
        // the redundancy, because refusing here only ever refuses to START a
        // stream (the primitive's rule) and one already in flight is left
        // alone to finish either way.
        armed: !root.scrubHeld || scroll.active

        // Totals from an origin of zero, straight into the drag's own
        // functions: both report x rightward and y downward in this item's
        // pixels, so fingers down the column step the same way a hand dragged
        // down it does, and every sign below is written once.
        //
        // The velocity the release reads comes out in the same unit on both
        // paths, which is what lets them share `flickVelocity` as well as the
        // arithmetic: Qt compresses pointer moves to about one event a frame,
        // a touchpad sends about a frame's travel per event, so a per-event
        // step means the same thing in each. A conversion here would be a
        // number the drag path does not apply and the two feels would part.
        onBegan: root.scrubBegin(0, 0)
        onMoved: (dx, dy) => root.scrubMove(dx, dy)
        // The release, minus the tap: a scroll never had a press, so there is
        // nothing for it to have stayed. The answer is dropped for that
        // reason rather than overlooked.
        onEnded: root.scrubRelease()
    }

    Timer {
        interval: 16
        repeat: true
        running: root.moving
        onTriggered: root.step(interval / 1000)
    }

    Component.onCompleted: root.snap()
}
