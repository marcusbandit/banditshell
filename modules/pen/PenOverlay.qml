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
    // Declared FIRST so that everything drawn below it is above it: the aspect
    // pill has a press of its own, and a sibling later in the file is the one the
    // event reaches.
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
            if (!pen.containsMouse || win.mode !== "")
                return -1;
            return win.cornerUnder(pen.mouseX + win.originX, pen.mouseY + win.originY);
        }

        readonly property bool over: pen.containsMouse && win.inside(pen.mouseX + win.originX, pen.mouseY + win.originY)

        // The diagonal comes out of the fractions rather than out of a lookup:
        // top-left and bottom-right are the corners whose two fractions AGREE,
        // and they are the pair that lies along the falling diagonal.
        cursorShape: {
            if (pen.hot >= 0)
                return win.corners[pen.hot][0] === win.corners[pen.hot][1] ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor;
            if (win.mode === "move")
                return Qt.ClosedHandCursor;
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

            // THE BARREL BUTTON RESIZES FROM WHEREVER THE PEN IS. It is the one
            // gesture that does not need aiming, which is the point of it: the
            // hand that is holding a pad button down with its other fingers is
            // not in a good position to hit a 24px corner, and the nearest corner
            // is almost always the one meant anyway.
            if (event.button === Qt.RightButton)
                return pen.beginResize(win.nearestCorner(gx, gy));

            const corner = win.cornerUnder(gx, gy);
            if (corner >= 0)
                return pen.beginResize(corner);

            if (win.inside(gx, gy)) {
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
            if (win.mode === "")
                return;

            const gx = event.x + win.originX;
            const gy = event.y + win.originY;

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
        stroke: Appearance.colour.accent
        strokeWidth: Appearance.sizes.pickerOutline
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

            visible: win.mine
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

    // WHAT YOU ARE DECIDING WITH, next to the thing being decided.
    //
    // It rides the region rather than sitting in a corner of the screen, for the
    // picker's reason: a readout you have to go and find is not a readout. Below
    // when there is room below and above when there is not, and clamped into the
    // screen either way, so it is never half off the edge at exactly the moment
    // the region is being pushed against that edge.
    Item {
        id: readout

        visible: win.mine
        x: Math.min(win.width - width, Math.max(0, outline.x + outline.width / 2 - width / 2))
        y: outline.y + outline.height + Appearance.padding.normal + height > win.height ? outline.y - height - Appearance.padding.normal : outline.y + outline.height + Appearance.padding.normal

        implicitWidth: row.implicitWidth + Appearance.padding.large * 2
        implicitHeight: row.implicitHeight + Appearance.padding.normal * 2
        width: implicitWidth
        height: implicitHeight

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
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(PenMap.region.width)} x ${Math.round(PenMap.region.height)}`
                font.pixelSize: Appearance.font.size.normal
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: PenMap.monitorName
                color: Appearance.colour.textDim
            }

            // THE SECOND WAY TO THE SAME SWITCH. `pen.aspectButton` on the pad
            // toggles this too, and that is the route a hand already holding the
            // tablet will use; this one exists because a setting with no visible
            // state is a setting you have to remember, and the pill is the state
            // as much as it is the control.
            Pill {
                anchors.verticalCenter: parent.verticalCenter
                text: PenMap.aspectLocked ? `aspect ${PenMap.surfaceAspect.toFixed(2)}` : "aspect free"
                icon: PenMap.aspectLocked ? "lock" : "lock_open"
                // Material Symbols treats FILL as a state axis, so the locked
                // mark is the same mark, solid. See components/Icon.qml.
                iconFill: PenMap.aspectLocked ? 1 : 0
                colour: PenMap.aspectLocked ? Appearance.colour.accentFill : Appearance.colour.fillStrong
                onClicked: PenMap.toggleAspect()
            }
        }
    }
}
