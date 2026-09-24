pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

// Where the drawing tablet maps, drawn on the screen it maps to.
//
// One of these per screen, and every one of them is up at once while the pad
// button is held, because the pen can be anywhere. services/PenMap.qml unbinds
// the tablet to the WHOLE LAYOUT for the duration of an edit, so the pen reaches
// a monitor the region is not currently on; a surface that only existed on the
// homed monitor would leave the pen with nowhere to land the moment it tried to
// take the region somewhere else.
//
// THE ONE THING THIS FILE MUST NEVER GET WRONG is input. The rest of the time
// the user is DRAWING through this patch of screen, into whatever application is
// under it, and a layer surface that quietly claims the pointer would eat every
// stroke with no visible cause at all. So the surface is unmapped outright while
// the editor is closed (`visible`), and its input region is collapsed to nothing
// on top of that (`mask`). Either alone is sufficient; both are here because the
// failure is silent and expensive and the second line costs nothing.
//
// It owns no geometry. `PenMap.region` is the single source of truth, in GLOBAL
// layout coordinates; this file subtracts the screen's own origin to draw it and
// adds it back to report a drag. Clamping, aspect correction and re-homing to
// another monitor all live in the service, so a region that can be dragged off
// the edge of the world is a bug there and not something to patch over here.
//
// AND IN FOLLOW WINDOW MODE IT STOPS BEING AN EDITOR AT ALL. The service has a
// mode in which the pad button's second press BINDS the mapping to the window
// under the pen instead of committing the rectangle the pen dragged, and this
// file's whole job in it is to aim: publish where the pen is, draw the window
// the service says is under it, and refuse every gesture that would edit the
// rectangle in the meantime. The pointer it publishes is what the service
// hit-tests, so the highlight and the press are answering the same question
// from the same number.
//
// THE MODE HAS THREE STATES AND THEY MUST NOT LOOK ALIKE, which is most of what
// this surface has to get right beyond input. On with nothing bound, a press
// binds: the outline is quiet because it is about to be replaced, and the wash
// under the pen is the only thing wearing the accent. On with a window bound,
// the region is that window's own rectangle and the outline says so, in the
// accent and at twice the weight, while the wash goes on marking whatever a
// press would REBIND to; the two are a filled rounded wash and an open square
// ring, so they stay separable even on the frames where they coincide. And a
// window bound while the editor was SHUT, which draws nothing at all, because
// there is nothing up to draw on: the follow pill reads the service's own
// persisted binding, so it is already naming the window the next time the pad
// button opens this.
PanelWindow {
    id: win

    // Read once into a name rather than reaching through `screen?.name` at every
    // call: `screen` is null for a frame while the surface is being built, and
    // WallpaperWindow makes the same move for the same reason.
    readonly property string output: win.screen?.name ?? ""

    // THIS SCREEN'S ORIGIN IN THE LAYOUT, which is the whole of the coordinate
    // conversion. Global minus origin is local, local plus origin is global, and
    // those two lines are the only places either direction happens.
    readonly property real originX: win.screen?.x ?? 0
    readonly property real originY: win.screen?.y ?? 0

    // WHETHER THE REGION IS HERE. The service says which output it homed the
    // region to, and that is the answer rather than an overlap test of our own:
    // two files each deciding which monitor a rectangle is on is two files that
    // will eventually disagree at a monitor boundary, and the one that re-homes
    // is the one that gets to say.
    readonly property bool mine: PenMap.monitorName === win.output

    // WHETHER A GESTURE CAN CHANGE ANYTHING AT ALL.
    //
    // Follow Window is a mode in which the second press of the pad button binds
    // the mapping to the window under the pen instead of committing the
    // rectangle under the pen, and a rectangle that is one press from being
    // replaced wholesale has no business letting anybody nudge it four pixels
    // first. So while the mode is on this surface refuses the lot: no move, no
    // corner resize, no barrel resize, and no handles drawn either, because a
    // grip that is drawn is a promise that it can be dragged.
    //
    // AND IT REFUSES THEM HARDER ONCE SOMETHING IS BOUND, without a second test
    // being written. A bound region is not the user's rectangle at all, it is
    // the service's arithmetic on a window that moves by itself, so a drag would
    // be undone by the next thing the compositor did to that window. One
    // boolean covers both, because the mode is the thing that takes the
    // rectangle away and the binding is only what it does with it afterwards.
    //
    // THE CONTROLS ARE THE EXCEPTION, and they have to be. The pill that turns
    // the mode off is on this surface, so a mode that suppressed presses on its
    // own way out would be a trap rather than a mode.
    readonly property bool editable: !PenMap.followWindow

    // THE FOUR CORNERS, AS FRACTIONS OF THE RECT, and the only place the number
    // four appears in this file. Everything a corner needs is derived from this:
    // where its handle is drawn, which corner a press grabbed, which corner a
    // barrel drag is nearest to, which corner is held still while the opposite
    // one moves, and which diagonal the cursor points down. Four anchored blocks
    // would state each of those five times and get one of them wrong.
    // See ~/.claude/rules/math-over-hardcoding.md.
    readonly property var corners: [[0, 0], [1, 0], [1, 1], [0, 1]]

    // A corner's position in GLOBAL coordinates, from the live region rather
    // than the smoothed one: a hit test has to answer where the thing IS, not
    // where it is still finishing arriving.
    function cornerAt(i: int): var {
        const f = win.corners[i];
        const r = PenMap.region;
        return [r.x + f[0] * r.width, r.y + f[1] * r.height];
    }

    // The corner OPPOSITE i, which is the one a resize pivots about. The
    // fractions are complements, so this is one subtraction rather than a table.
    function oppositeAt(i: int): var {
        const f = win.corners[i];
        const r = PenMap.region;
        return [r.x + (1 - f[0]) * r.width, r.y + (1 - f[1]) * r.height];
    }

    function nearestCorner(gx: real, gy: real): int {
        let best = 0;
        let bestDist = Infinity;
        for (let i = 0; i < win.corners.length; i++) {
            const c = win.cornerAt(i);
            // Squared distance, because nothing here wants the actual length and
            // a square root per corner per pointer event is a cost with no reader.
            const d = (c[0] - gx) * (c[0] - gx) + (c[1] - gy) * (c[1] - gy);
            if (d < bestDist) {
                bestDist = d;
                best = i;
            }
        }
        return best;
    }

    // IS THIS POINT ON A CORNER, and which one. Its own function because the
    // press and the hover both have to ask it and they must not each keep their
    // own opinion: the picker learned that the expensive way, where a hover-fed
    // cache answered a press that had never been preceded by a hover. A stylus
    // is exactly that case, since a pen lifted out of proximity and put straight
    // down sends a press with no hover in front of it.
    function cornerUnder(gx: real, gy: real): int {
        const i = win.nearestCorner(gx, gy);
        const c = win.cornerAt(i);
        return Math.abs(c[0] - gx) <= win.grab && Math.abs(c[1] - gy) <= win.grab ? i : -1;
    }

    function inside(gx: real, gy: real): bool {
        const r = PenMap.region;
        return gx >= r.x && gy >= r.y && gx <= r.x + r.width && gy <= r.y + r.height;
    }

    // DOES THE FIRST RECTANGLE HOLD THE SECOND, to within the width of the line
    // that draws them.
    //
    // The slack is half a stroke because two edges that agree to closer than the
    // stroke lying between them are the same edge on screen, and because the
    // region is derived from a window by arithmetic that has no reason to land
    // anywhere else: it is there for that arithmetic's own dust and not as a
    // tolerance anybody is meant to tune.
    function holds(outer: rect, inner: rect): bool {
        const slack = Appearance.sizes.pickerOutline / 2;
        return inner.x >= outer.x - slack && inner.y >= outer.y - slack && inner.x + inner.width <= outer.x + outer.width + slack && inner.y + inner.height <= outer.y + outer.height + slack;
    }

    // IS THIS POINT ON ONE OF THE CONTROLS, and which one. They live INSIDE the
    // region now, so they sit on the surface that drags the region and the two
    // have to be told apart somewhere. Here, next to the other two hit tests, so
    // that what a press means is one ordered list in one handler rather than a
    // consequence of which item happened to be declared last.
    //
    // IT HANDS BACK THE CONTROL ITSELF rather than a name, and the press then
    // fires that control's own `clicked`. The version of this that answered a
    // bool and left the handler to call `toggleAspect` was fine while there was
    // one pill and would have become one test per pill the moment there were
    // two, each of them a place to wire the wrong switch to the wrong rectangle.
    // What a control does is written on the control.
    function controlUnder(gx: real, gy: real): var {
        if (!readout.visible)
            return null;
        for (const item of readout.controls) {
            const b = readout.boxOf(item);
            if (gx >= b.x && gy >= b.y && gx <= b.x + b.width && gy <= b.y + b.height)
                return item;
        }
        return null;
    }

    // HOW CLOSE COUNTS AS ON A CORNER. The WCAG floor the rest of the shell is
    // built to, used here as a radius rather than as a box side, so the grab area
    // is the same generous size the shell's other targets are and is not a number
    // invented for this one widget.
    readonly property real grab: Appearance.sizes.minTarget

    // The drawn handle is deliberately SMALLER than the area that answers it. A
    // mark big enough to be hit comfortably is a mark big enough to cover the
    // corner it is supposed to be showing you.
    readonly property real handle: Appearance.sizes.minTarget / 2

    // WHAT THE PEN IS CURRENTLY DOING: "" for nothing, "move", or "resize".
    // A string rather than an enum because there are three of them and the
    // string is what the reader wants to see at the comparison site.
    property string mode: ""
    property int grabbed: -1

    // For a resize: the corner that stays put, in global coordinates, latched at
    // the press. Read continuously off the region instead and the pivot would
    // chase the service's own clamping, which is a rectangle that walks away
    // under the pen.
    property real anchorX: 0
    property real anchorY: 0

    // For a move: where in the region the pen went down, so the region travels
    // with the pen rather than jumping its origin to the pointer.
    property real grabX: 0
    property real grabY: 0

    // THE WINDOW THE PEN IS AIMED AT, kept after the pen has left it.
    //
    // The highlight draws from here rather than straight off the service, and
    // the difference is exactly the length of the fade out. `hoveredWindow` says
    // "nothing under the pen" with an empty rect, and an empty rect bound to a
    // shape collapses it into a dot at this screen's origin: the highlight would
    // spend its last hundred milliseconds sliding to a corner no window has ever
    // been in. Held, it fades where it stands. The name is held with it so the
    // plate does not reflow to nothing halfway through going away.
    property rect aimed
    property string aimedName: ""

    // IS THE MAPPING ALREADY INSIDE THE WINDOW THE PEN IS AIMED AT.
    //
    // A press in this mode means one of three things, bind, rebind, or nothing,
    // and the only difference between the last two is whether the window under
    // the pen is the one the mapping is already welded to. The service publishes
    // the binding as an ADDRESS and publishes no address for the window under
    // the pen, so there is no identity here to compare. What there is instead is
    // a question about RECTANGLES, which this file is entitled to ask and which
    // has a true answer of its own: is the region already sitting inside this
    // window. While a binding is live the region IS that window, aspect
    // corrected and centred in it, so it is inside that window and usually
    // inside nothing else.
    //
    // THE NAME IS THE SECOND HALF, because containment on its own is not enough.
    // Bind to a small floating terminal, then aim at the maximised editor behind
    // it: the editor's rectangle contains the region too. The classes differ, so
    // the name catches that one. What neither catches is two windows of the SAME
    // application stacked so that the back one also holds the front one's
    // mapping, and there the word on the plate is wrong while the press it
    // describes is still perfectly sensible, which is the right way round for a
    // claim this cheap to be wrong.
    //
    // OFF THE HELD RECTANGLE, like the name beside it and for the same reason:
    // the word must not change under a highlight that is halfway through fading
    // out.
    readonly property bool aimedBound: PenMap.tracking && win.aimedName === PenMap.boundWindowName && win.holds(win.aimed, PenMap.region)

    // WHAT A PRESS ON THAT WINDOW WOULD DO, in one word. The whole of this mode
    // is a press whose meaning depends on where the pen is, and the pen is
    // already pointing at the one place where saying so costs nothing.
    readonly property string aimedWord: {
        if (!PenMap.tracking)
            return "bind";
        return win.aimedBound ? "bound" : "rebind";
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // OVERLAY, not Top. The shell's own surface deliberately gives way to a
    // fullscreen window, and a tablet mapping you cannot see while a fullscreen
    // canvas is open is a tablet mapping you cannot set for the one application
    // most likely to want it. The picker made the same call for the same reason.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "banditshell-pen"

    // Never. The pad button is the only control this has, the pen is the only
    // pointer, and an exclusive grab on a surface that merely exists takes the
    // keyboard away from the desktop.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // UNMAPPED WHILE CLOSED. Not merely transparent, not merely masked: the
    // surface is not on screen at all, which is the only state that is provably
    // incapable of intercepting a stroke.
    visible: PenMap.active

    // AND EMPTY WHILE CLOSED, on top of that. A zero-sized region accepts
    // nothing; the full window accepts everything, which is what an editor
    // reached by holding a button on the tablet needs, since the pen may be
    // anywhere on any monitor when the button goes down.
    mask: Region {
        width: PenMap.active ? win.width : 0
        height: PenMap.active ? win.height : 0
    }

    // THE EDITOR CAN END WHILE THE PEN IS STILL DOWN, because what ends it is the
    // pad button coming up, not the tip lifting. The surface unmaps under a live
    // drag and `onReleased` never arrives, so without this the next session would
    // open already holding a stale grab and the first pen movement would fling
    // the region somewhere nobody asked for.
    Connections {
        target: PenMap

        function onActiveChanged(): void {
            if (!PenMap.active)
                win.release();
        }

        // BOTH HALVES OF THE ANSWER, FROM EITHER HALF CHANGING. The rectangle
        // and the name are two properties, so they land as two notifications in
        // an order this file does not get to know; latching on whichever arrives
        // means the plate never shows one window's name over another's outline.
        function onHoveredWindowChanged(): void {
            win.hold();
        }

        function onHoveredWindowNameChanged(): void {
            win.hold();
        }
    }

    // A WINDOW, AND ONLY EVER A WINDOW. The empty rect is the service saying
    // there is nothing under the pen, which is a reason to stop drawing the
    // highlight and never a place to move it to. Imperative rather than a
    // binding for that one reason: a binding cannot decline an update.
    function hold(): void {
        const r = PenMap.hoveredWindow;
        if (r.width <= 0 || r.height <= 0)
            return;
        win.aimed = r;
        win.aimedName = PenMap.hoveredWindowName;
    }

    function release(): void {
        win.mode = "";
        win.grabbed = -1;
    }

    // THE PEN ARRIVES AS AN ORDINARY POINTER. Hyprland forwards the stylus to
    // surfaces as pointer input, so the tip is LeftButton and the lower barrel
    // button is RightButton, and a plain MouseArea is the whole of what is needed
    // here. Only the PAD needs evdev, and that is scripts/pen-pad.py's job.
    //
    // AND IT IS THE ONLY THING IN HERE THAT TAKES ONE. The controls sit inside
    // the region now, on top of the very surface that drags it, so a tip landing
    // on them could mean three different things and something has to choose. It
    // is this handler, in an order that is written down: a corner, then the
    // controls, then a move. The alternative is what was here before, a pill
    // keeping the MouseArea it came with and winning because it is declared
    // later, which is a stacking accident rather than a decision, and one that
    // would quietly take the bottom two corner handles away wherever the panel
    // covers them.
    MouseArea {
        id: pen

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true

        // WHICH CORNER THE POINTER IS ON, or -1. While a resize is running it is
        // the corner being dragged, so the cursor does not flicker back to an
        // arrow the instant the pen outruns the handle it grabbed.
        readonly property int hot: {
            if (win.mode === "resize")
                return win.grabbed;
            // Nothing is hot while the mode is on, and that is the same answer
            // the drawn handles give: there is no corner to be near because
            // there is no corner being offered.
            if (!pen.containsMouse || win.mode !== "" || !win.editable)
                return -1;
            return win.cornerUnder(pen.mouseX + win.originX, pen.mouseY + win.originY);
        }

        readonly property bool over: pen.containsMouse && win.inside(pen.mouseX + win.originX, pen.mouseY + win.originY)

        // WHICH CONTROL THE POINTER IS ON, or null, which is that control's
        // hover paint and half of the cursor. A corner beats them here for the
        // same reason a corner beats them in the press below, so a highlight
        // never offers a switch that a press would not actually throw.
        readonly property var overControl: pen.containsMouse && win.mode === "" && pen.hot < 0 ? win.controlUnder(pen.mouseX + win.originX, pen.mouseY + win.originY) : null

        // The diagonal comes out of the fractions rather than out of a lookup:
        // top-left and bottom-right are the corners whose two fractions AGREE,
        // and they are the pair that lies along the falling diagonal.
        cursorShape: {
            if (pen.hot >= 0)
                return win.corners[pen.hot][0] === win.corners[pen.hot][1] ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor;
            if (win.mode === "move")
                return Qt.ClosedHandCursor;
            // The pills are the only buttons on this surface, and the cursor is
            // what says so now that they have no MouseArea of their own to say
            // it.
            if (pen.overControl)
                return Qt.PointingHandCursor;
            // FOLLOWING: a crosshair, which is the picker's mark for "this is
            // the thing you are about to take" and is the true one here. The
            // four-way arrow would be offering a drag that this mode has just
            // finished refusing.
            //
            // EXCEPT OVER THE WINDOW THAT IS ALREADY BOUND, where there is
            // nothing to take: the mapping is on that window, and a press would
            // put it back exactly where it is. Aiming at a thing already held is
            // not aiming, so the mark drops to the plain arrow, which is what
            // the rest of this surface says wherever a press changes nothing.
            // Over bare desktop it stays a crosshair, because there the mode is
            // still looking even though this particular spot has no answer.
            if (!win.editable)
                return highlight.shown && win.aimedBound ? Qt.ArrowCursor : Qt.CrossCursor;
            return pen.over ? Qt.SizeAllCursor : Qt.ArrowCursor;
        }

        function beginResize(i: int): void {
            win.mode = "resize";
            win.grabbed = i;
            const o = win.oppositeAt(i);
            win.anchorX = o[0];
            win.anchorY = o[1];
        }

        onPressed: event => {
            const gx = event.x + win.originX;
            const gy = event.y + win.originY;

            // A PRESS IS A POSITION TOO, and a stylus is the device that proves
            // it: a pen lifted out of proximity and put straight back down sends
            // a press with no hover in front of it, so a service fed only by
            // movement would be hit-testing wherever the pen last was. The same
            // lesson `cornerUnder` above is written for.
            PenMap.setPointer(gx, gy);

            // THE BARREL BUTTON RESIZES FROM WHEREVER THE PEN IS. It is the one
            // gesture that does not need aiming, which is the point of it: the
            // hand that is holding a pad button down with its other fingers is
            // not in a good position to hit a 24px corner, and the nearest corner
            // is almost always the one meant anyway.
            //
            // AND IT IS SUPPRESSED WHILE FOLLOWING, by the same test that
            // suppresses the corners and the move below, because the three of
            // them are one decision rather than three: see `win.editable`.
            if (win.editable && event.button === Qt.RightButton)
                return pen.beginResize(win.nearestCorner(gx, gy));

            const corner = win.editable ? win.cornerUnder(gx, gy) : -1;
            if (corner >= 0)
                return pen.beginResize(corner);

            // THE CONTROLS, WHICH ARE A PRESS AND NEVER A DRAG. They are inside
            // the region, so without this branch a tap on one would throw its
            // switch AND walk the whole mapping off with the pen.
            //
            // They sit BELOW the corner test on purpose. The drawn handles clear
            // the panel, because the inset that holds the panel off the bottom
            // edge is larger than half a handle, but the GRAB radius is a WCAG
            // target and reaches well into it, so the bottom two corners and this
            // panel really do overlap. A corner you cannot grab because a button
            // is sitting on it is the worse of the two failures: the aspect pill
            // has a second route, the pad's aspect button, and the corner has
            // none.
            //
            // NOT below it while following, and nothing had to be written for
            // that: with no corners on offer the test above cannot match, so the
            // controls are simply what is left, which is the whole of what the
            // mode means for input.
            //
            // On the press rather than on a click, like everything else here. The
            // hand is already holding a pad button down, and a control that waits
            // for the tip to come up again is a control that argues with that.
            const control = win.controlUnder(gx, gy);
            if (control) {
                win.mode = "";
                return control.clicked();
            }

            if (win.editable && win.inside(gx, gy)) {
                win.mode = "move";
                win.grabX = gx - PenMap.region.x;
                win.grabY = gy - PenMap.region.y;
                return;
            }

            // A TIP DOWN ON EMPTY SCREEN DOES NOTHING, deliberately. Teleporting
            // the region to wherever the pen last touched would make every
            // mis-aimed tap a change, and this editor is held open by a finger on
            // the tablet: a mis-aim is the likeliest thing to happen in it.
            win.mode = "";
        }

        onPositionChanged: event => {
            const gx = event.x + win.originX;
            const gy = event.y + win.originY;

            // WHERE THE PEN IS, PUBLISHED, whatever the pen is doing with it.
            //
            // The service owns which window is under a point and cannot answer
            // that without being told the point, and this surface is the only
            // thing that hears the pen at all: the editor is the reason the
            // surface takes input in the first place, and while it is open the
            // tablet is unbound to the whole layout, so the instance the pen is
            // over is whichever monitor the hand is pointing at. GLOBAL, like
            // every other number that crosses this boundary, converted by the
            // one addition at the top of this handler rather than by a second
            // idea of where this screen starts.
            //
            // Sent whether or not the mode is on, so that what a pointer MEANS
            // stays the service's decision rather than becoming a thing this
            // file gates and the service has to trust.
            PenMap.setPointer(gx, gy);

            if (win.mode === "")
                return;

            // The size is passed straight back through unchanged. A move must not
            // have an opinion about how big the region is, and the service will
            // shrink it by itself if the monitor it lands on cannot hold it.
            if (win.mode === "move")
                return PenMap.proposeRegion(gx - win.grabX, gy - win.grabY, PenMap.region.width, PenMap.region.height);

            // A resize pivots about the corner opposite the one grabbed, and the
            // min/abs pair is what lets the pen drag straight through that pivot
            // and out the other side without the rectangle inverting.
            PenMap.proposeRegion(Math.min(win.anchorX, gx), Math.min(win.anchorY, gy), Math.abs(gx - win.anchorX), Math.abs(gy - win.anchorY));
        }

        onReleased: win.release()
        // A grab taken away by the compositor is a grab that ends, and it ends
        // here rather than staying latched until the next press notices.
        onCanceled: win.release()
    }

    // NOT THIS SCREEN: dimmed, and still there.
    //
    // The obvious thing is to draw nothing on the monitors the region is not on,
    // and it is wrong in exactly the moment this feature exists for. Drag the
    // region off the left monitor and the left monitor goes black-and-normal
    // while the right one lights up, and if you were looking at the left one the
    // outline did not move, it VANISHED. A dim says "the editor is open, it is
    // not here", which is a different sentence and the true one.
    Rectangle {
        anchors.fill: parent
        visible: !win.mine
        color: Appearance.colour.scrim
    }

    // AND SAY WHERE IT WENT, because a dim on its own is only half the sentence.
    StyledText {
        anchors.centerIn: parent
        visible: !win.mine
        text: `tablet mapped to ${PenMap.monitorName}`
        color: Appearance.colour.textFaint
    }

    // HOW MUCH OF THE HIGHLIGHT THERE IS, 0 to 1.
    //
    // The only thing about the highlight that is smoothed, and the geometry
    // deliberately is not. See the shape below for why. A reveal runs 0 to 1, so
    // the default quarter-unit epsilon would be a quarter of the whole journey;
    // 0.005 is the tier the shell's other reveals use. See components/Follow.qml.
    Follow {
        id: aim

        target: highlight.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // THE WINDOW A PRESS WOULD TAKE, washed over the window itself.
    //
    // A DIFFERENT SHAPE FROM THE REGION OUTLINE ON PURPOSE, because the two are
    // different things and will usually overlap: one press after a snap they are
    // very nearly the same rectangle. The region is a square-cornered ring round
    // nothing, which is what a MAPPING is, and it goes quiet while the mode is
    // on. This is a filled, window-cornered wash, which is what a WINDOW is. The
    // corner is the compositor's own window radius, the same token the picker
    // snaps a crop to, so the wash lands on the window's real edge rather than a
    // hair outside it.
    //
    // AND IT IS DRAWN ON EVERY SCREEN WITHOUT ASKING WHICH ONE THE WINDOW IS ON.
    // `mine` exists for the region because the service HOMES the region to one
    // output and somebody has to be told which; a window belongs to whatever it
    // overlaps and can lie across two monitors at once. Subtracting this screen's
    // origin is the whole of the conversion: a window on the next monitor lands
    // outside this surface and is never painted, and one straddling the boundary
    // is drawn whole, half by each instance, with nothing having to decide
    // anything.
    G2Rect {
        id: highlight

        // OFF THE LIVE SERVICE VALUE rather than off the held one, because the
        // question here is "is there a window under the pen right now" and the
        // held rectangle is deliberately the answer to the previous one.
        readonly property bool shown: PenMap.followWindow && PenMap.hoveredWindow.width > 0 && PenMap.hoveredWindow.height > 0

        // THE GEOMETRY SNAPS AND ONLY THE FADE IS SMOOTHED, which is the reverse
        // of what the outline below does and is the same reasoning arriving at
        // the other answer. The outline lags the pen because the pen is what is
        // MOVING it, and watching it arrive is watching your own hand. This is
        // not a thing being moved at all, it is a claim about what the next press
        // will take, and a claim that needs a tenth of a second to catch up is a
        // claim that is wrong for a tenth of a second, over a window the press
        // would not have taken.
        visible: aim.value > 0
        opacity: aim.value
        x: win.aimed.x - win.originX
        y: win.aimed.y - win.originY
        width: win.aimed.width
        height: win.aimed.height
        radius: Appearance.sizes.windowRadius

        // AND IT GOES NEUTRAL OVER THE WINDOW IT IS ALREADY BOUND TO.
        //
        // The accent is spent on what a press would CHANGE, and over the bound
        // window a press changes nothing. Left in the accent this wash would be
        // inviting a press with no work to do, and it would be wearing the same
        // colour as the ring nested inside it, which is the one thing on screen
        // that actually IS the binding.
        //
        // NOT HIDDEN, though, because that window is the one there is most to
        // say about. Aim at it and what you get is a quiet wash with the bright
        // ring of the mapping sitting inside it, which is the whole state drawn
        // rather than written: this window is taken, and that is the part of it
        // the pen reaches. A highlight that vanished instead would be saying
        // "nothing here" over the only window that is already yours.
        color: win.aimedBound ? Appearance.colour.fill : Appearance.colour.accentFill
        stroke: win.aimedBound ? Appearance.colour.textDim : Appearance.colour.accent
        strokeWidth: Appearance.sizes.pickerOutline

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.normal
            }
        }

        Behavior on stroke {
            ColorAnimation {
                duration: Appearance.anim.normal
            }
        }

        // WHAT IT IS, said the way the region says what it is: the size at the
        // tier above, the name beside it in the quiet colour, on the same plate
        // with the same corner. Two rectangles are on screen in this mode and
        // each one carries its own numbers, so neither has to be read as a
        // description of the other. That is also the answer to whether the
        // region's readout should switch to describing this window while the
        // mode is on: it should not, because the region is still exactly what
        // the tablet maps to until the press lands, and a number that silently
        // changes its subject depending on where the pen is hovering is a number
        // nobody can trust twice.
        Item {
            id: label

            // Centred, where the region's plate is against the bottom edge, so
            // the two can be over the same rectangle and still be told apart.
            anchors.centerIn: parent

            // A WINDOW CAN BE SMALLER THAN ITS OWN NAME PLATE, and a plate
            // hanging out of the wash would be labelling the desktop instead.
            // The wash says which window on its own; the words are what is
            // affordable on top of that.
            visible: label.implicitWidth <= highlight.width && label.implicitHeight <= highlight.height

            implicitWidth: named.implicitWidth + Appearance.padding.large * 2
            implicitHeight: named.implicitHeight + Appearance.padding.normal * 2
            width: implicitWidth
            height: implicitHeight

            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.surface
            }

            Row {
                id: named

                anchors.centerIn: parent
                spacing: Appearance.padding.large

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Math.round(win.aimed.width)} x ${Math.round(win.aimed.height)}`
                    font.pixelSize: Appearance.font.size.normal
                }

                // WHAT IT IS, AND WHAT WOULD HAPPEN TO IT, as one phrase rather
                // than as two items with a gap between them. "rebind
                // qBittorrent" is read in one go where a word and a name set
                // apart are read as two facts, and it costs the plate a word
                // instead of a word plus a gap, which is worth having: a plate
                // wider than the window under it is not drawn at all, so every
                // pixel added here is a band of window sizes that lose the
                // whole label rather than part of it.
                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${win.aimedWord} ${win.aimedName}`
                    color: Appearance.colour.textDim
                }
            }
        }
    }

    // THE SMOOTHED RECTANGLE, in this screen's own coordinates.
    //
    // Four channels rather than one, because there is no smoothing a rect as a
    // rect: a resize moves an edge and an origin at once and the two have to
    // arrive together. Exponential smoothing, so the outline is fast when the pen
    // has thrown it a long way and gentle as it lands, at whatever frame time the
    // compositor happens to be handing out. See ~/.claude/rules/animation-smoothing.md.
    //
    // THE SPEED IS THE ARRIVAL. On a screen the region is not on, smoothing is
    // turned off, so the value sits exactly on target: the moment the region is
    // dragged onto this monitor the outline is already in the right place and
    // starts tracking from there, instead of sweeping in from wherever the
    // rectangle was the last time this screen owned it. Nothing has to notice the
    // handover and snap; the handover simply has nothing to catch up on.
    Follow {
        id: fx

        target: PenMap.region.x - win.originX
        speed: win.mine ? Appearance.anim.trackSpeed : 0
    }

    Follow {
        id: fy

        target: PenMap.region.y - win.originY
        speed: win.mine ? Appearance.anim.trackSpeed : 0
    }

    Follow {
        id: fw

        target: PenMap.region.width
        speed: win.mine ? Appearance.anim.trackSpeed : 0
    }

    Follow {
        id: fh

        target: PenMap.region.height
        speed: win.mine ? Appearance.anim.trackSpeed : 0
    }

    // THE MAPPING ITSELF: an outline, over the live desktop, undimmed.
    //
    // Undimmed because the question being answered is "what will the pen reach",
    // and the honest way to answer it is to leave what is under the rectangle
    // visible and put a boundary round it. The dim is spent on the OTHER screens,
    // where it means something.
    //
    // SQUARE CORNERS, and this is the one shape in the shell that gets them. The
    // corners of the tablet map to the corners of this rectangle, exactly, and a
    // rounded outline would be a claim about the mapping that the mapping does
    // not make. It is the picker's argument about a crop, which is the same
    // argument: G2Rect is still the primitive drawing it, at radius 0, because
    // the shell has one rounded-rectangle primitive and "not rounded" is a value
    // it takes rather than a reason to reach for Rectangle.
    G2Rect {
        id: outline

        visible: win.mine
        x: fx.value
        y: fy.value
        width: fw.value
        height: fh.value
        radius: 0
        color: "transparent"

        // AND IT GOES QUIET WHILE FOLLOWING WITH NOTHING BOUND YET. Still drawn,
        // because it is still exactly where the tablet points and will go on
        // being that until the press lands. Not in the accent, because it is one
        // press from being thrown away and replaced by the window under the pen,
        // and the loud colour belongs on the thing about to happen rather than
        // on the thing about to end. It is also what keeps the two rectangles
        // apart on the frames where they nearly coincide.
        //
        // AND IT COMES BACK, HEAVIER, THE MOMENT A WINDOW IS BOUND. That is the
        // one place this rectangle changes what it MEANS. It is no longer a
        // rectangle anybody placed: it is the largest tablet-shaped rectangle
        // that fits inside the window the mapping is welded to, worked out again
        // every time that window moves or resizes, and the first instinct is to
        // stop drawing it for exactly that reason, since nobody put it there.
        //
        // THAT INSTINCT IS WRONG TWICE. The window and the region are not the
        // same rectangle once the shape is locked, and a tall window keeps a
        // wide tablet well inside itself, so this outline is the only thing on
        // screen that says where the pen actually LANDS as opposed to which
        // window it lands in. And the panel carrying the only way out of this
        // mode rides inside it, so an outline that went away would leave its own
        // controls floating over open desktop.
        //
        // WEIGHT IS WHAT SAYS WELDED, because every other channel is already
        // spent: the colour says whether the mapping is live, the square corners
        // say the tablet's corners land on these, and the four handles say
        // whether it can be dragged. A doubled line needs no new vocabulary, and
        // it is the difference that survives the frames where this ring and the
        // wash over the window it is bound to lie exactly on top of each other.
        stroke: win.editable || PenMap.tracking ? Appearance.colour.accent : Appearance.colour.textFaint
        strokeWidth: Appearance.sizes.pickerOutline * (PenMap.tracking ? 2 : 1)

        Behavior on stroke {
            ColorAnimation {
                duration: Appearance.anim.normal
            }
        }

        Behavior on strokeWidth {
            NumberAnimation {
                duration: Appearance.anim.normal
                easing.type: Easing.OutCubic
            }
        }
    }

    // THE CORNERS, PLACED BY ARITHMETIC. One delegate, four fractions, and the
    // position falls out of the rectangle. Add a fifth grip somewhere later and
    // it is a fifth entry in `corners`, not a fifth anchored block that has to be
    // kept in step with the other four.
    Repeater {
        model: win.corners.length

        delegate: G2Rect {
            id: grip

            required property int index
            readonly property var frac: win.corners[grip.index]
            readonly property bool live: pen.hot === grip.index

            // GONE WHILE FOLLOWING, not merely inert. A handle that is drawn is
            // a claim that the corner under it can be dragged, and in this mode
            // it cannot; leaving four of them on a rectangle that only ever
            // changes in one jump would be the surface lying about what it does.
            visible: win.mine && win.editable
            // Centred ON the corner rather than tucked inside it: the handle is
            // the corner, so it has to sit on the point it moves.
            x: outline.x + grip.frac[0] * outline.width - grip.width / 2
            y: outline.y + grip.frac[1] * outline.height - grip.height / 2
            width: win.handle
            height: win.handle
            radius: Appearance.rounding.small
            // A handle IS a control, so it is filled rather than outlined, and it
            // brightens under the pen. That is the whole of what says it can be
            // grabbed, and it is cheaper than any label would be.
            color: grip.live ? Appearance.colour.paper : Appearance.colour.accent

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
    }

    // WHAT YOU ARE DECIDING WITH, INSIDE the thing being decided.
    //
    // It rides the region rather than sitting in a corner of the screen, for the
    // picker's reason: a readout you have to go and find is not a readout. It
    // used to ride BELOW the region, flipping above when there was no room below
    // and clamped into the screen either way, and that arrangement was wrong in
    // the case this editor exists for most. Map the tablet to a whole monitor,
    // which is the default and the shape most mappings are left in, and "below
    // the region" is off the bottom of the screen: the flip then threw the
    // controls above a rectangle whose top edge they had nothing to do with, and
    // the clamp slid them along an edge to a place with no relationship to the
    // region at all. Either way the thing you were adjusting and the thing you
    // were adjusting it with had come apart.
    //
    // Tucked against the inside of the bottom edge there is nothing to flip and
    // nothing to clamp, and both are DELETED rather than left as a fallback. The
    // service guarantees the region is on a monitor, so anything drawn within the
    // region is on screen by construction, and a second opinion about where these
    // go would only be waiting for its turn to be the one on screen.
    Item {
        id: readout

        // Each pill's words and each pill's mark, said once and read twice: by
        // the pill that is drawn, and by the pill that is only ever measured.
        // Both pairs say the STATE rather than the control, which is why the
        // aspect pill can read "free" and this one can read "off": what a switch
        // is currently doing is the more useful of the two things to write on it.
        readonly property string words: PenMap.aspectLocked ? `aspect ${PenMap.surfaceAspect.toFixed(2)}` : "aspect free"
        readonly property string mark: PenMap.aspectLocked ? "lock" : "lock_open"

        // AND THE FOLLOW PILL NAMES WHAT IT CAUGHT, by the same rule: once a
        // window is bound the state is not "follow window" any more, it is
        // "follow qBittorrent". This is the only place in the shell where a live
        // binding is written in words, and it is also the whole of the answer to
        // a binding made while the editor was SHUT. Nothing has to be carried
        // across the close and nothing has to be replayed on the open, because
        // this reads the service's own persisted state and simply says it the
        // next time this surface is up.
        //
        // A BOUND WINDOW WITH NO NAME falls back to the mode's own word rather
        // than leaving "follow " with a space hanging off the end of it. That is
        // not a lie about the state either: the mark's fill below is what says
        // something is caught, and these words are saying no more than they
        // know.
        readonly property string followWords: {
            if (!PenMap.followWindow)
                return "follow off";
            return PenMap.tracking ? `follow ${PenMap.boundWindowName || "window"}` : "follow window";
        }

        // STILL A PAIR, and deliberately not a trio. The mark is the SWITCH, and
        // a switch has two positions; what the mode has caught is a different
        // question and gets a different channel, the FILL axis on the pill
        // below. That is precisely what Material Symbols means by FILL, so an
        // empty frame filling in as it takes hold of a window is the mark saying
        // it in its own vocabulary rather than in a third drawing nobody in this
        // shell has seen before.
        readonly property string followMark: PenMap.followWindow ? "select_window" : "select_window_off"

        // AND THE THIRD ONE NEVER CHANGES ITS WORD, because it is not a switch.
        // The two pills beside it say what state the editor is in and change
        // their own label to say it; this one performs a rectangle and has no
        // state to report, so its label is the same six letters whatever the
        // mapping is doing. That also makes it the one control on the plate
        // whose width is a constant, which is why it needs no budget of its own
        // the way the follow pill does.
        readonly property string centreWords: "centre"

        // `fit_screen` rather than a crosshair or a target: what the press does
        // is not "mark the middle", it is "make this the size of that screen and
        // put it in the middle", and the mark that already means a rectangle
        // taking the shape of a display is the honest one. No FILL axis on it,
        // because fill is how the other two say which way they are thrown and
        // this one is never thrown either way.
        readonly property string centreMark: "fit_screen"

        // HOW MANY CHARACTERS OF A WINDOW'S NAME THE PILL WILL EVER SHOW.
        //
        // A BUDGET RATHER THAN A MEASUREMENT, and that is the entire point of
        // it. The ladder below is a set of thresholds compared against pill
        // widths, and a pill whose width came from a window name would move
        // every one of them each time the pen crossed a window: the plate would
        // gain and lose its words as a consequence of what happened to be under
        // the pen, which is the same strobing the hidden twins were introduced
        // to stop, driven this time by the hand instead of by a binding loop. So
        // the twin that feeds the ladder is a FIXED string this many characters
        // long, and the drawn pill is capped to it, which turns a name too long
        // to fit into an elision inside a control that did not move.
        //
        // ELEVEN, because that is what the longest window class on this machine
        // needs: qBittorrent, with thunderbird and libreoffice the same length
        // behind it. Each character past it costs one glyph of the body size on
        // two of the three rungs, 12px on the words rung and 12px on the numbers
        // rung, for a name that almost nothing has. Setting it too SMALL breaks
        // nothing either, because the cap is a width and not a slice: the pill
        // just elides sooner, and even "follow window" would lose its tail
        // rather than overflow the plate.
        readonly property int followBudget: 11

        // THE CONTROLS, IN ROW ORDER. One list, walked by the press test and
        // counted by the ladder below, so the fourth control is one entry here
        // rather than an edit in each of the places that would otherwise be
        // counting to three by hand.
        readonly property var controls: [aspect, follow, centre]

        // A CONTROL'S BOX IN GLOBAL COORDINATES, for the press test upstairs,
        // which is written in global coordinates like every other test in this
        // file. Read off the items that were actually laid out rather than summed
        // again from the paddings: the Row is what places them, and a second sum
        // of the same numbers is a second thing to keep in step.
        function boxOf(item: Item): rect {
            return Qt.rect(win.originX + readout.x + row.x + item.x, win.originY + readout.y + row.y + item.y, item.width, item.height);
        }

        // WHAT A ROW OF THINGS COSTS: the widths, plus a gap between each pair
        // of them. N items have N-1 gaps, and a third control is exactly the
        // change that leaves a hand-written `spacing * 2` behind, still reading
        // as correct and short by one whole gap at every threshold below.
        // See ~/.claude/rules/math-over-hardcoding.md.
        function span(widths: var): real {
            return widths.reduce((a, b) => a + b, 0) + Math.max(0, widths.length - 1) * row.spacing;
        }

        // ONE COAT OF PAINT FOR EVERY CONTROL. Two pills doing the same kind of
        // job, each carrying its own copy of a four-way ternary, is two copies
        // that drift; this is that rule written once. The hover step is
        // TabletKey's: whatever the resting fill is, one rung brighter, so a
        // highlight never reads as the state having changed under the pen.
        function paint(on: bool, hot: bool): color {
            if (hot)
                return on ? Appearance.colour.accent : Appearance.colour.fillStronger;
            return on ? Appearance.colour.accentFill : Appearance.colour.fillStrong;
        }

        // HOW MUCH ROOM THERE IS INSIDE, off the SMOOTHED rectangle rather than
        // the live one. The panel is placed against the outline as drawn, so it
        // has to be sized against the outline as drawn; measured against the live
        // region it would change form several frames before the rectangle it was
        // measured against had finished arriving, and shed its numbers in mid
        // air over a rectangle that still had room for them.
        readonly property real roomX: outline.width - Appearance.padding.normal * 2
        readonly property real roomY: outline.height - Appearance.padding.normal * 2

        // What the plate itself costs, which every form pays.
        readonly property real chrome: Appearance.padding.large * 2

        // A PILL WITH NOTHING BUT A MARK IN IT IS A CIRCLE, and a circle is as
        // wide as it is tall, so the narrowest this panel can be is one pill's
        // own height per control plus the gaps and the plate. That is Pill's
        // construction and not a guess made out here, and it is one number for
        // both pills because both are set at the same size and a Pill's height
        // comes from its label. See components/Pill.qml.
        readonly property real markWidth: measure.implicitHeight

        // WHAT TO DROP WHEN THE RECTANGLE IS SMALLER THAN THE CONTROLS.
        //
        // The region may be taken down to `pen.minSize`, 160px today, and a plate
        // carrying a size, a monitor name and two pills with words on them is far
        // wider than that. Left alone it would hang out of both sides of the very
        // rectangle it describes and cover the desktop the mapping is being aimed
        // at, which is the failure this whole arrangement is here to fix, so the
        // panel sheds instead, in the order of what is least missed. The numbers
        // go first: they describe a rectangle that is right there being its own
        // description. Then the pills' words, leaving the marks, which say locked
        // or not and following or not by themselves and are the reason a mark has
        // a fill axis at all.
        //
        // ONE LADDER, THREE RUNGS, AND A THIRD CONTROL RAISED EVERY ONE OF THEM.
        // The mark rung went from one circle to two circles and the gap between
        // them, 84px of room to 144px, which is a region 168px wide against the
        // 108px it used to want. That is above the 160px an unlocked region can
        // be taken down to, so at the very bottom of the size range this plate is
        // now gone where it used to show a single mark. Deliberate, and cheaper
        // than the alternatives: a rung that drops a control rather than its
        // words would hide a switch while implying the other one is all there is.
        //
        // AND NAMING THE BOUND WINDOW RAISED THE TWO WORDY RUNGS, once, by a
        // fixed amount. The follow twin went from "follow window" at thirteen
        // characters to a permanent eighteen, seven for the word and the space
        // and eleven for the budget, which at the body size is 59.92px of extra
        // pill. The words rung moves from 479.63px of region, or 443.67px with
        // the mode off, to a flat 539.55px; the numbers rung moves from 773.56px
        // to 833.48px for a monitor named like DP-1 and a size string of eleven
        // characters. The mark rung does not move at all, because no text
        // reaches it: it is still 168px wide by 84px tall.
        //
        // THE FLATNESS IS THE PART WORTH HAVING. Those two rungs used to sit at
        // different heights depending on which way the follow switch was thrown,
        // 35.95px apart, because "follow window" is three characters longer than
        // "follow off", so a region parked between them lost its words as a side
        // effect of turning the mode on. They are one number now, and no window
        // name can move them.
        //
        // Below even the marks, nothing is drawn. A control narrower than the
        // WCAG target is a control the pen cannot hit, and a plate wider than its
        // region is worse than no plate. What is lost at that size is the sight
        // of the state, not the ability to change it: the pad's aspect button
        // throws the aspect switch without this panel, and locking the shape of a
        // 160px region makes it 242px wide, which is over the threshold and puts
        // the whole plate, follow pill included, back on screen. That is the way
        // out of the one corner this can paint you into, which is snapping to a
        // window narrower than 168px while the mode is on.
        readonly property bool full: readout.span([pixels.implicitWidth, monitor.implicitWidth, measure.implicitWidth, followMeasure.implicitWidth, centreMeasure.implicitWidth]) + readout.chrome <= readout.roomX
        readonly property bool wordy: readout.span([measure.implicitWidth, followMeasure.implicitWidth, centreMeasure.implicitWidth]) + readout.chrome <= readout.roomX
        // One circle per control, counted from the controls rather than from a
        // literal two, so the arithmetic is right for however many there are.
        readonly property bool fits: readout.span(readout.controls.map(() => readout.markWidth)) + readout.chrome <= readout.roomX && readout.implicitHeight <= readout.roomY

        visible: win.mine && readout.fits

        // AGAINST THE INSIDE OF THE BOTTOM EDGE, centred across it. Both lines
        // are the rectangle's own arithmetic and nothing else: no screen in them,
        // no clamp, no branch on which side there is room, because inside a
        // rectangle that is already on a monitor there is only one answer.
        x: outline.x + (outline.width - readout.width) / 2
        y: outline.y + outline.height - readout.height - Appearance.padding.normal

        implicitWidth: row.implicitWidth + readout.chrome
        implicitHeight: row.implicitHeight + Appearance.padding.normal * 2
        width: implicitWidth
        height: implicitHeight

        // THE PILLS NOBODY SEES, and the reason each control has two.
        //
        // Ask the pill that is drawn how wide it is and the answer depends on the
        // form it is in, which depends on the answer: drop the words, the pill
        // shrinks, the words fit again, put them back. That is a binding loop
        // with a symptom you can watch, a control strobing between two forms at
        // one exact region width. These are always wordy and never drawn, so
        // every threshold above is a fixed number that the choice it feeds cannot
        // move.
        //
        // ONE EACH, rather than one measured pill standing in for both. The
        // ladder weighs a ROW of controls now, and a row measured twice from the
        // same twin is a threshold that is right for whichever of the two happens
        // to carry the longer word and wrong by the difference for the other.
        Button {
            id: measure

            visible: false
            interactive: false
            text: readout.words
            icon: readout.mark
        }

        Button {
            id: followMeasure

            visible: false
            interactive: false

            // PERMANENTLY WORDY IN THE STRONGEST SENSE, which the aspect twin
            // above is not and did not need to be. This one's text depends on
            // nothing: not on the mode, not on the binding, not on the name of
            // whatever window the pen last crossed. It is the widest thing the
            // drawn pill is ALLOWED to be, so every threshold it feeds is a
            // constant that the state it is measuring cannot reach back and
            // move.
            //
            // A RUN OF THE WIDEST GLYPH rather than a phrase, because what is
            // wanted here is a width and not a sentence. The shell's face is
            // monospaced, so a run of any glyph is exact; in a proportional face
            // this would come out a little too wide, which is the safe direction
            // for a measurement whose whole job is deciding whether something
            // fits.
            text: `follow ${"M".repeat(readout.followBudget)}`
            icon: readout.followMark
        }

        Button {
            id: centreMeasure

            visible: false
            interactive: false

            // Constant by construction, unlike either twin above: this pill's
            // drawn text is the same string in every state the editor has, so
            // the twin is not standing in for a worst case, it IS the case.
            text: readout.centreWords
            icon: readout.centreMark
        }

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.surface
        }

        Row {
            id: row

            anchors.centerIn: parent
            spacing: Appearance.padding.large

            // THE NUMBER THE VIEW IS ABOUT, at the tier above the labels. That is
            // the whole of the hierarchy here: two of the three sizes, and colour
            // doing the rest. See ~/.claude/rules/type-scale.md.
            //
            // Off the LIVE region, not the smoothed one. The smoothed value is
            // where the outline has got to; this is the number that will actually
            // be committed, and a readout that lags it would be showing a size
            // the tablet is never going to have.
            StyledText {
                id: pixels

                anchors.verticalCenter: parent.verticalCenter
                visible: readout.full
                text: `${Math.round(PenMap.region.width)} x ${Math.round(PenMap.region.height)}`
                font.pixelSize: Appearance.font.size.normal
            }

            StyledText {
                id: monitor

                anchors.verticalCenter: parent.verticalCenter
                visible: readout.full
                text: PenMap.monitorName
                color: Appearance.colour.textDim
            }

            // THE SECOND WAY TO THE SAME SWITCH. `pen.aspectButton` on the pad
            // toggles this too, and that is the route a hand already holding the
            // tablet will use; this one exists because a setting with no visible
            // state is a setting you have to remember, and the pill is the state
            // as much as it is the control.
            //
            // WITH ITS OWN MOUSEAREA TURNED OFF, which is the input half of
            // bringing the controls inside the region. A pill that took its own
            // presses would take them from the two corner handles it now sits
            // among, and it would win by being declared later rather than because
            // anyone decided it should. The press comes from `pen` instead, where
            // the corner is tried first.
            Button {
                id: aspect

                anchors.verticalCenter: parent.verticalCenter
                interactive: false
                text: readout.wordy ? readout.words : ""
                icon: readout.mark
                // Material Symbols treats FILL as a state axis, so the locked
                // mark is the same mark, solid. See components/Icon.qml.
                iconFill: PenMap.aspectLocked ? 1 : 0
                // A pill that does not take its own presses cannot paint its own
                // hover either, so both arrive from where the press does: the
                // hover through `overControl`, and the press as this signal,
                // emitted by the handler that decided the press was on this pill.
                paint: readout.paint(PenMap.aspectLocked, pen.overControl === aspect)
                onClicked: PenMap.toggleAspect()
            }

            // WHAT THE NEXT PRESS OF THE PAD BUTTON MEANS, which is the only
            // thing this mode changes. On, the button stops committing the
            // rectangle the pen has been pushing about and commits the window
            // under the pen instead; the rectangle is not being edited in the
            // meantime, which is why so much of this surface goes still while it
            // is lit.
            //
            // BUILT LIKE THE ASPECT PILL BESIDE IT, down to the mark carrying the
            // state on its fill axis, because it is the same kind of thing: a
            // standing decision about how the editor behaves, which persists, and
            // which is worth being able to see without pressing anything. The
            // marks are a Material pair like lock and lock_open, so on and off
            // are the same drawing with and without its slash.
            //
            // AND IT IS THE ONLY WAY OUT OF THE MODE from the pen, which is why
            // the press handler keeps the controls live when it is refusing
            // everything else.
            Button {
                id: follow

                anchors.verticalCenter: parent.verticalCenter
                interactive: false
                text: readout.wordy ? readout.followWords : ""

                // CAPPED AT THE TWIN, which is the other half of the budget
                // above. A Pill elides a label it has been given too little room
                // for, so a window name longer than the budget loses its tail
                // instead of pushing this control wider than the ladder was told
                // it could be. Every state shorter than the cap keeps its own
                // width, so the pill is not padded out to the worst case for the
                // sake of a name it is not currently showing.
                width: Math.min(follow.implicitWidth, followMeasure.implicitWidth)
                icon: readout.followMark

                // THE FILL SAYS WHAT IT CAUGHT, not whether it is on. The mark
                // already carries the switch, with and without its slash, and
                // the pill's fill carries the same boolean a second time in
                // colour; spending the FILL axis on it a third time would leave
                // the one thing this mode is actually about with nowhere to
                // show. So an outlined frame is the mode looking for a window
                // and a solid one is the mode holding one, and that is what
                // tells the two apart at the bottom rung of the ladder, where
                // the words are gone and the mark is the whole of the control.
                iconFill: PenMap.tracking ? 1 : 0
                paint: readout.paint(PenMap.followWindow, pen.overControl === follow)
                onClicked: PenMap.toggleFollowWindow()
            }

            // THE RECTANGLE NEARLY EVERY SESSION WANTS BACK: the tablet's own
            // shape, as big as this screen allows, in the middle of it. The two
            // pills to its left change what the editor means and leave the
            // rectangle to the hand; this one states the rectangle, which is why
            // it sits at the end of the row rather than among them.
            //
            // A BUTTON AND NOT A SWITCH, and the paint is where that is said.
            // Both of its neighbours pass their own state to `paint` and come up
            // lit when they are on, because being on is a thing that lasts. This
            // has nothing that lasts: the press happens, the region moves, and
            // there is no "centred" for a pill to go on claiming afterwards,
            // least of all one the next drag would quietly make false. So it is
            // always painted resting, and the only thing that ever lifts it is
            // the pen being over it.
            Button {
                id: centre

                anchors.verticalCenter: parent.verticalCenter
                interactive: false
                text: readout.wordy ? readout.centreWords : ""
                icon: readout.centreMark
                paint: readout.paint(false, pen.overControl === centre)
                onClicked: PenMap.fitAndCentre()
            }
        }
    }
}
