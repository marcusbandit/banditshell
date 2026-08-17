pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// THE BOTTOM EDGE OF A WINDOW, AS A HANDLE ON IT. Push up from there and the
// window comes up with your finger, and where it goes is where you put it down.
//
// This is the phone gesture, and it is the phone gesture because a folded
// convertible has no keyboard to close a window with and no titlebar to aim a
// fingertip at. The whole of it is one motion out of the one place that is
// always reachable, and which of the three things it means is decided by what
// the hand does next rather than by which control it found:
//
//   thrown up            the window is closed
//   dropped on another   the two windows trade places
//   window
//   held, then carried   the workspaces come out along the top, and dropping on
//   to the top           one sends the window there
//   put back down        nothing happened
//
// THE PLACES ARE THERE THE MOMENT THE WINDOW IS IN THE HAND. Rearranging is what
// you do with a window you have just picked up, so it costs no second gesture:
// every other window on the workspace becomes a target where it already stands
// (LayoutSlots), and hovering one shows you the swap by moving it into the space
// you are holding open. The hold is spent on the ONE answer that is not already
// on the screen, which is the other workspaces (WorkspaceShelf), and they hang
// from the top because leaving is a different kind of answer from rearranging:
// down among the windows means "here, differently", up past them means "not
// here at all".
//
// SPEED IS WHAT CLOSES, and it has to be, now that almost every release lands
// over a target. A hand that flings something has stopped choosing where it
// goes; a hand that carries it somewhere and lets go has not. See release().
//
// A FINGER ONLY, and that is not a preference. The press is refused outright
// unless it was synthesised from a touch point, so a mouse falls straight
// through to modules/launcher/LaunchEdge.qml underneath and the bottom edge goes
// on being the launcher's pull exactly as it was. Two gestures can share one
// edge when they cannot both be made by the same hardware, and this machine's
// screen (an i2c Wacom digitizer, which is what a laptop touchscreen usually
// is) is the only thing in the room that can make this one.
//
// A FINGER WITH NO WINDOW UNDER IT IS REFUSED TOO, which is how the launcher
// survives on the touchscreen. Swipe up from a bare workspace and the press
// falls through to the edge below and opens the launcher as before; swipe up
// from under a window and the window is what you get. The rule is legible
// because it is the same rule the gesture already states: this is a handle on
// the window above it, and where there is no window there is no handle.
//
// WHAT IT CLAIMS: nothing, by default. The strip is exactly the band the chassis
// already owns (ShellWindow's mask subtracts only the content area), so no
// window loses a pixel of its own input to this. `windows.grab` will widen it if
// the edge is hard to hit, and Config says plainly what that costs.
//
// THE CARD IS THE WINDOW'S OWN PICTURE. It used to be a proxy with the
// application's mark and title on it, on the argument that a screenshot would be
// a better lie; that was the wrong way round, because what is in the hand IS the
// window and the one thing that says so without a caption is the window itself.
// So the toplevel is captured and the card carries it: at zero travel the
// picture lies exactly on the thing it is a picture of, and the first pixel of
// the swipe peels it off. The mark and the title are still there for the moment
// before the compositor hands over a frame, and for anything that never does.
Item {
    id: root

    required property ShellScreen screen

    // The band's own thickness, which is the whole of the strip when nothing has
    // been added to it.
    required property real border

    // The content area, which the card is sized against and the shelf centres
    // in. Handed down rather than recomputed, like the settings page's.
    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    // WHETHER SOMETHING ELSE ALREADY OWNS THE BOTTOM OF THE SCREEN. Every panel
    // in this shell comes out over the band, and a finger on a panel is aimed at
    // the panel. Fed from ShellWindow, which is the one place that can see them
    // all at once.
    property bool blocked: false

    readonly property Item maskItem: strip

    // WHAT IS IN THE HAND: { addr, mark, title, x, y, w, h }, or null.
    //
    // Set on the press, not on the lift, because the window under the finger is
    // a fact about where the gesture STARTED and windows move: something can
    // open, tile and shove the one you are holding sideways while your finger is
    // still down, and a gesture that re-read its target would then be carrying a
    // different window than the one it picked up.
    property var held: null

    // Past the recognition distance: the card is drawn and the hold is armed.
    property bool lifted: false

    // THE HAND HAS STOPPED THROWING, and the workspace map may come out.
    //
    // This is what keeps the closing swipe clean. The map costs a scrim over the
    // screen and a capture per window, and a flick that is over in a tenth of a
    // second wants none of it: it is one card leaving, and it looked right the
    // day it was written. So the map waits for the gesture to slow below the
    // speed that would have closed the window, which a flick never does before
    // the finger is gone.
    //
    // LATCHING, so a drag that speeds up again mid-flight does not take the
    // places away from under the hand. Nothing turns it off but the end of the
    // gesture.
    property bool mapped: false
    // WHICH TARGET THE REAL LAYOUT IS ALREADY SWAPPED WITH, by address, or "".
    //
    // The swap is dispatched WHILE YOU HOVER rather than when you let go, so
    // what you are looking at underneath is the arrangement you are asking for
    // rather than a picture of it. Held as an ADDRESS and not as an index into
    // the map, because the compositor reorders its own list when windows move
    // and an index would quietly come to mean a different window.
    property string committed: ""

    // A finger is on it right now, as opposed to an outro still playing.
    property bool grabbed: false
    // The shelf is out.
    property bool racked: false

    // HOW IT ENDED, and where the card is flying while it says so: "" while a
    // finger is still driving, then "close", "sent" or "back". One string rather
    // than three flags, because they are three answers to one question.
    property string outro: ""

    // Where the card was when the finger left, and where it is going. Plain
    // rectangles rather than bindings: the whole point of an outro is that it no
    // longer tracks anything.
    property var rest: null
    property var dest: null

    // The gesture's own arithmetic: where it started, where the finger is, and
    // how fast it is going.
    property real originY: 0
    property real pointX: 0
    property real pointY: 0
    property real velocity: 0
    property real lastRise: 0
    property real lastEvent: 0
    // Where the finger last was when it was judged to have MOVED, which is what
    // the hold measures its stillness against.
    property real stillX: 0
    property real stillY: 0

    // How far up it has come. Never negative: dragging back below the start is a
    // gesture going home, not a window being pushed into the floor.
    readonly property real rise: root.held ? Math.max(0, root.originY - root.pointY) : 0

    // A FULL SWIPE, and how far along this one is. The travel is a fraction of
    // the screen rather than a pixel count, for the reason Config gives over
    // `pullTravel`: the same distance is a flick on one panel and a journey on
    // another.
    readonly property real travelFull: Math.max(1, root.height * Appearance.sizes.windowTravel)
    readonly property real progress: root.held ? Math.max(0, Math.min(root.rise / root.travelFull, 1)) : 0

    readonly property bool showing: !!root.held && (root.lifted || root.outro !== "")

    // THE TILE the card is heading toward: a fraction of the content area wide,
    // and the window's own proportions tall, so what you are carrying stays
    // recognisably the shape of what you picked up.
    readonly property real tileW: root.holeWidth * Appearance.sizes.windowCard
    readonly property real tileH: root.held ? root.tileW * root.held.h / root.held.w : root.tileW

    // THE CARD IS ONE SCALE AND ONE CENTRE, never a rectangle with two
    // independently moving sides. This is the whole of what keeps the window's
    // proportions: a size interpolated per side happens to hold the ratio only
    // while both ends of the interpolation share it, and the moment a
    // destination does not (a plate, which is the shape of the SCREEN, or
    // another window's slot, which is the shape of that window) the card is
    // squashed on its way there. A factor cannot squash anything.
    readonly property real tileScale: root.held ? root.tileW / root.held.w : 1

    // ...OR WHATEVER THE MAP COULD ACTUALLY MANAGE. The map takes the tile's
    // scale unless the workspace is too wide to fit at it, and the card follows
    // the map rather than the other way round, so the thing in the hand and the
    // hole it came out of are always the same size.
    readonly property real restScale: Math.min(root.tileScale, layout.mapScale)
    readonly property real liveScale: 1 + (root.restScale - 1) * tuck.value

    // WHERE IT IS WHILE A FINGER IS ON IT. The centre walks from the window's
    // own to under the finger as the lift goes on, and the BOTTOM EDGE simply
    // travels with the hand. That last one is what makes the lift read as one
    // object rather than as a card appearing: the gesture starts at the bottom
    // edge of the window, so at zero travel the card is exactly the window, and
    // every pixel the finger rises the card rises with it.
    readonly property real liveCX: root.held ? root.held.x + root.held.w / 2 + (root.pointX - root.held.x - root.held.w / 2) * tuck.value : 0
    readonly property real liveCY: root.held ? root.held.y + root.held.h - root.rise - root.held.h * root.liveScale / 2 : 0

    // ...and where it is once nobody is holding it. One ternary per term rather
    // than a second item, because it is the same card either way.
    readonly property real cardScale: root.outro ? root.blend(root.rest.k, root.dest.k, gone.value) : root.liveScale
    readonly property real cardCX: root.outro ? root.blend(root.rest.cx, root.dest.cx, gone.value) : root.liveCX
    readonly property real cardCY: root.outro ? root.blend(root.rest.cy, root.dest.cy, gone.value) : root.liveCY

    readonly property real cardW: root.held ? root.held.w * root.cardScale : 0
    readonly property real cardH: root.held ? root.held.h * root.cardScale : 0
    readonly property real cardX: root.cardCX - root.cardW / 2
    readonly property real cardY: root.cardCY - root.cardH / 2

    // The material the card fills with, read once so the alpha below has
    // something to scale.
    readonly property color body: Appearance.colour.surface

    function blend(a: real, b: real, t: real): real {
        return a + (b - a) * t;
    }

    // WHICH WINDOW THE FINGER LANDED UNDER, or null.
    //
    // The touch point is in the band, which is BELOW every window on the screen,
    // so no window contains it and a containment test finds nothing. What the
    // gesture means by "the window above me" is the one whose column the finger
    // is in and whose bottom edge is nearest the strip, which is exactly what a
    // hand aiming at the bottom of a window is pointing at. Ties go to whichever
    // came first out of `clientsOn`, which is front-most first.
    //
    // AND IT HAS TO BE WITHIN REACH of the edge. A workspace holding one small
    // floating window in the middle of the screen has nothing at the bottom of
    // it, and picking that window up out of a gesture made a screen away from it
    // would be the shell guessing. Nothing found means the press is refused, and
    // a refused press is the launcher's.
    function windowAt(x: real): var {
        const reach = root.border + Appearance.sizes.minTarget;
        let best = null;

        for (const client of Hypr.clientsOn(root.screen)) {
            const o = client.lastIpcObject;
            if (!o?.at || !o?.size)
                continue;

            const cx = o.at[0] - root.screen.x;
            const cy = o.at[1] - root.screen.y;
            if (x < cx || x > cx + o.size[0])
                continue;

            const bottom = cy + o.size[1];
            if (root.height - bottom > reach)
                continue;
            if (best && bottom <= best.y + best.h)
                continue;

            const addr = o.address ?? "";
            best = {
                addr: addr.startsWith("0x") ? addr : `0x${addr}`,
                // The model's own object, kept alongside the numbers: the card
                // shows the window's real content, and a capture needs the
                // handle rather than the address.
                client,
                mark: AppIcons.markFor(Hypr.classOf(client)),
                title: o.title ?? "",
                x: cx,
                y: cy,
                w: o.size[0],
                h: o.size[1]
            };
        }

        return best;
    }

    // A NEW GESTURE, with the window it is for already decided.
    function begin(win: var, x: real, y: real): void {
        root.held = win;
        root.lifted = false;
        root.mapped = false;
        root.racked = false;
        root.committed = "";
        layout.landed = false;
        root.grabbed = true;
        root.outro = "";
        root.originY = y;
        root.pointX = x;
        root.pointY = y;
        root.velocity = 0;
        root.lastRise = 0;
        root.lastEvent = Date.now();
        // The card starts exactly ON the window, so the tuck starts at nothing
        // and is not flown in from wherever the last gesture left it.
        tuck.snap();
        gone.snap();
    }

    // One step of it.
    function track(x: real, y: real): void {
        root.pointX = x;
        root.pointY = y;

        // PER MILLISECOND, smoothed, which is the shape every other gesture in
        // this shell measures speed with and the only one that divides the
        // device's event rate back out (see LaunchEdge's advance()). The dt
        // clamp is the same at both ends and for the same reasons.
        const now = Date.now();
        const dt = Math.max(1, Math.min(100, now - root.lastEvent));
        root.lastEvent = now;
        const step = root.rise - root.lastRise;
        root.lastRise = root.rise;
        root.velocity += (step / dt - root.velocity) * 0.4;

        if (!root.lifted) {
            // The same recognition distance as every other pull, so the moment a
            // gesture starts being answered is the same moment everywhere.
            if (root.rise < Appearance.sizes.pullSlack)
                return;

            root.lifted = true;
            root.stillX = x;
            root.stillY = y;
            hold.restart();
            return;
        }

        // STILLNESS IS WHAT SUMMONS THE SHELF, measured as "has not moved
        // recently" rather than as "has not moved at all": a fingertip resting
        // on glass wanders a few pixels, and a hold that any of that cancelled
        // would be a hold nobody can perform. Once the shelf is out it stays
        // out, because the gesture after that is aiming at a plate and aiming
        // is moving.
        if (Math.hypot(x - root.stillX, y - root.stillY) > Appearance.sizes.windowHoldSlop) {
            root.stillX = x;
            root.stillY = y;
            if (!root.racked)
                hold.restart();
        }
    }

    // MAKE THE REAL LAYOUT MATCH THE AIM, whatever the aim has just become.
    //
    // One rule, applied on every change: the arrangement equals "held swapped
    // with whatever is under the finger", and no aim at all means the
    // arrangement you started with. Undo then redo rather than composing, since
    // a swap is its own inverse and composing two of them is not the same as
    // doing the second one on its own.
    //
    // The map is frozen while this runs (see LayoutSlots), so the targets do not
    // move under the finger as the windows underneath do.
    function commitAim(): void {
        if (!root.held || !root.grabbed)
            return;

        const want = layout.over >= 0 ? layout.windows[layout.over].addr : "";
        if (want === root.committed)
            return;

        if (root.committed)
            Hypr.swapWith(root.held.addr, root.committed);
        if (want)
            Hypr.swapWith(root.held.addr, want);

        root.committed = want;
    }

    Connections {
        target: layout

        function onOverChanged(): void {
            root.commitAim();
        }
    }

    // The finger left.
    function release(): void {
        hold.stop();

        if (!root.held || !root.lifted) {
            // A tap on the band, which is not this gesture at all.
            root.clear();
            return;
        }

        // A THROW IS NOT AN AIM, and it is asked first for exactly that reason.
        //
        // The places to put a window down are on screen from the moment it
        // leaves the ground, so almost every release now happens OVER one of
        // them, and a rule that let the thing underneath decide would have made
        // the closing swipe unperformable on a full screen of windows. Speed is
        // the one thing a drop cannot fake: a hand that flings something has
        // stopped choosing where it lands.
        if (root.velocity >= Appearance.sizes.windowFling) {
            // A THROW TAKES BACK ANYTHING IT PASSED OVER. The aim can be sitting
            // on a target at the instant of a flick, and the swap it committed
            // was never asked for: closing is what the hand said.
            if (root.committed) {
                Hypr.swapWith(root.held.addr, root.committed);
                root.committed = "";
            }
            Hypr.closeWindow(root.held.addr);
            root.finish("close", -1);
            return;
        }

        // THE TOP OF THE SCREEN NEXT, because it is the answer that takes the
        // finger away from every other one: while the shelf is armed the layout
        // underneath is not answering, so there is never a moment where both
        // have a claim and an order has to be invented.
        const plate = shelf.over;
        if (plate >= 0) {
            const slot = shelf.slots[plate];

            // Dropping a window back on the workspace it is already on is a
            // change of mind spelled as a drop, so it is answered as one.
            if (slot.target === Hypr.activeId)
                root.finish("back", -1);
            else {
                Hypr.sendToWorkspace(root.held.addr, slot.target, Appearance.sizes.windowFollow);
                root.finish("sent", plate);
            }
            return;
        }

        // ...then the workspace you are on, where dropping on a window is the
        // two of them trading places. No hold is spent on this: it is the thing
        // you do with a window you have just picked up.
        // ...then the workspace you are on. NOTHING IS DISPATCHED HERE: the
        // swap happened the moment you hovered, so letting go is only the shell
        // agreeing with the compositor about a rearrangement they have both
        // already made.
        const other = layout.over;
        if (other >= 0) {
            root.finish("swapped", other);
            return;
        }

        // A SLOW SWIPE THE WHOLE WAY UP, over nothing at all, still closes.
        //
        // "Nothing at all" is the gaps, the band, and the window's own slot,
        // which is the case that matters: a full-screen window covers every
        // pixel of its own workspace, so it has no neighbour to be dropped on
        // and this is the only rule left that can close it without a flick.
        //
        // It asks for more than a panel's pull does, and deliberately. Everything
        // else this shell decides on a release is reversible; a window closed by
        // mistake is somebody's unsaved work.
        if (root.progress >= 1) {
            if (root.committed) {
                Hypr.swapWith(root.held.addr, root.committed);
                root.committed = "";
            }
            Hypr.closeWindow(root.held.addr);
            root.finish("close", -1);
            return;
        }

        // Let go over nothing, having gone nowhere in particular. The window's
        // own slot is the way out, and it has to be somewhere the hand can find
        // without aiming.
        root.finish("back", -1);
    }

    // HOW IT ENDS, wherever it is ending from. The card's current centre and
    // scale are frozen as the "from", because once the finger is gone there is
    // nothing left to track, and the "to" is the whole of what the four endings
    // differ by: off the top of the screen, onto the plate it was dropped on,
    // into the slot of the window it is trading with, or back onto the window it
    // was lifted off.
    //
    // A destination is a CENTRE AND A FACTOR, never a rectangle, so a card
    // flying into a plate shaped like the screen or a slot shaped like somebody
    // else's window arrives at the size that fits inside it rather than being
    // stretched into its shape. `min` of the two ratios is what "fits inside"
    // means for a shape that has to keep its own.
    function finish(how: string, index: int): void {
        root.rest = {
            cx: root.cardCX,
            cy: root.cardCY,
            k: root.cardScale
        };

        if (how === "close")
            root.dest = {
                cx: root.rest.cx,
                cy: -root.held.h * root.rest.k / 2,
                k: root.rest.k
            };
        else if (how === "sent") {
            const centre = shelf.plateCentre(index);
            root.dest = {
                cx: centre.x,
                cy: centre.y,
                k: Math.min(shelf.scaledW / root.held.w, shelf.scaledH / root.held.h)
            };
        } else if (how === "swapped") {
            // THE TARGET'S REAL RECTANGLE, not its place on the map, because the
            // map is about to grow into the real layout underneath it. Both
            // arrive at the compositor's own coordinates and the two pictures
            // meet there.
            const slot = layout.windows[index];
            root.dest = {
                cx: slot.x + slot.w / 2,
                cy: slot.y + slot.h / 2,
                k: Math.min(slot.w / root.held.w, slot.h / root.held.h)
            };
        } else
            root.dest = {
                cx: root.held.x + root.held.w / 2,
                cy: root.held.y + root.held.h / 2,
                k: 1
            };

        root.grabbed = false;
        root.outro = how;
        // ...and the map grows into the windows it was a picture of.
        layout.landed = true;
    }

    // Back to nothing at all, instantly. Called when an outro lands, and by the
    // next press, so a gesture started while the last one is still flying home
    // is not two cards.
    function clear(): void {
        root.outro = "";
        root.held = null;
        root.lifted = false;
        root.mapped = false;
        root.racked = false;
        root.committed = "";
        layout.landed = false;
        root.grabbed = false;
        root.rest = null;
        root.dest = null;
        gone.snap();
        tuck.snap();
    }

    // THE WINDOW DIED WHILE IT WAS IN THE AIR, which is not as rare as it
    // sounds: an application can quit on its own, and a gesture is held for as
    // long as a hand feels like holding it. `held` is a SNAPSHOT taken on the
    // press (it has to be, see the property), so nothing about it goes stale by
    // itself, and a card left carrying a dead address would happily be dropped
    // on a workspace and dispatch a move naming nothing.
    //
    // Cleared outright rather than flown home, because home is gone. The
    // outros are exempt: the close is what killed it.
    Connections {
        target: Hypr

        function onWindowClosed(addr: string): void {
            if (root.held && !root.outro && root.held.addr === addr)
                root.clear();
        }
    }

    // HOW FAR THROUGH THE LIFT THE CARD IS, 0 on the window and 1 as the tile.
    // It tracks the swipe closely enough to feel attached, and it is a Follow
    // rather than the raw fraction so that the shelf coming out (which takes the
    // card the rest of the way at once) is a movement rather than a jump.
    Follow {
        id: tuck

        target: root.racked ? 1 : root.progress
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.005
    }

    // The outro's own clock. `settled` rather than a threshold, because a card
    // cleared at 0.99 leaves a sliver on the screen (see Follow).
    Follow {
        id: gone

        target: root.outro ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005

        // DEFERRED, and it has to be. `clear` puts `outro` back to "", which is
        // this Follow's own target, so clearing straight out of the handler
        // rewrites the value being evaluated and Qt calls it a binding loop on
        // `settled`. Qt.callLater runs it once the current pass is over, and
        // dedupes by function, so a handful of settle signals in one frame is
        // still one clear.
        onSettledChanged: if (gone.settled && root.outro)
            Qt.callLater(root.clear)
    }

    // THE SCRIM ARRIVES WITH THE MAP AND DEEPENS WITH THE SHELF, and arrives
    // with neither during a throw. Two steps because they are two statements:
    // the first is "these are places", the second is "and now somewhere else
    // entirely".
    readonly property real dim: mapDim.value * 0.7 + rackDim.value * 0.3

    Follow {
        id: mapDim

        target: root.mapped && !root.outro ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    Follow {
        id: rackDim

        target: root.racked ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // HAS THE THROW ENDED. Beats from the lift until the hand is going slower
    // than a close would need, then latches the map and stops. Repeating rather
    // than one-shot, because "not yet" has to be asked again: a swipe can be
    // fast at a tenth of a second and deliberate at a quarter.
    Timer {
        id: settle

        interval: Appearance.sizes.windowSettle
        repeat: true
        running: root.grabbed && root.lifted && !root.mapped
        onTriggered: if (root.velocity < Appearance.sizes.windowFling)
            root.mapped = true
    }

    // HOW LONG STILL IS STILL. Armed at the lift and restarted by movement, so
    // it can only fire while a window is genuinely being held somewhere.
    Timer {
        id: hold

        interval: Appearance.sizes.windowHold
        onTriggered: if (root.grabbed && root.lifted)
            root.racked = true
    }

    // The screen behind it all, dimmed. It has no mask entry and no handler:
    // this shell gates input with the mask and visuals with opacity, and putting
    // a catcher here would swallow clicks for a mode that only a finger already
    // on the glass can be in.
    Rectangle {
        anchors.fill: parent

        visible: root.dim > 0.01
        color: Appearance.colour.scrim
        opacity: root.dim
    }

    // THE WORKSPACE YOU ARE ON, as places to put the window down. Declared
    // before the shelf so the shelf hangs over it, which is also the order they
    // are asked in.
    LayoutSlots {
        id: layout

        anchors.fill: parent

        screen: root.screen
        heldAddr: root.held?.addr ?? ""

        // THE CONTENT AREA, LESS THE SHELF'S OWN BAND at the top. Reserved
        // whether or not the shelf is out, so the map does not jump down the
        // screen the moment somebody holds still.
        holeX: root.holeX
        holeY: root.holeY + shelf.dockedHeight
        holeWidth: root.holeWidth
        holeHeight: root.holeHeight - shelf.dockedHeight

        // What the card is heading for. The map answers with what it could
        // actually manage, and the card reads that back.
        preferred: root.tileScale

        pointX: root.pointX
        pointY: root.pointY

        // LIVE FROM THE LIFT, not from the hold. Rearranging is the thing you do
        // with a window you have just picked up, so it must not cost a second
        // gesture: the places are simply there the moment there is something in
        // the hand. The hold is spent on the ONE answer that is not already on
        // the screen, which is the workspaces.
        //
        // NOT WHILE THE SHELF IS ARMED. Two sets of targets lighting up under
        // one finger would be two answers to one drop, and the hand has already
        // said which it meant by going up to the top of the screen.
        active: root.mapped && !shelf.armed
    }

    WorkspaceShelf {
        id: shelf

        anchors.fill: parent

        holeX: root.holeX
        holeY: root.holeY
        holeWidth: root.holeWidth
        holeHeight: root.holeHeight
        aspect: root.height / root.width

        pointX: root.pointX
        pointY: root.pointY
        // Held out for the whole of a drop's outro, so the card is seen landing
        // on the plate rather than flying at a shelf that has already gone.
        active: root.racked
    }

    // THE CARD. One shape for the whole gesture: the window's outline, the thing
    // in your hand, and the thing flying away are the same object at three
    // moments, and drawing them as three would be three things to keep in step.
    G2Rect {
        id: card

        visible: root.showing
        x: root.cardX
        y: root.cardY
        width: Math.max(0, root.cardW)
        height: Math.max(0, root.cardH)
        // FADED ONLY WHEN IT IS LEAVING. A card flying home or into a swapped
        // slot lands exactly on the real window it is a picture of, so fading it
        // would be dissolving something into itself; one that is being thrown
        // off the screen or into a workspace plate has nowhere real to land.
        opacity: root.outro === "close" || root.outro === "sent" ? 1 - gone.value : 1

        // The window's own corner, SCALED WITH THE CARD. At full size this is
        // the real window's radius, which it has to be while the two are lying
        // on top of each other; shrinking it with everything else is what keeps
        // the card the same object at the far end, and what makes it match the
        // slots on the map, which are drawn at the same scale.
        radius: Appearance.sizes.windowRadius * root.cardScale

        // The material FADES IN with the lift. At rest the card is a hairline
        // around a window you can still see; by the time it is a tile it is a
        // solid object. Painting the shell's surface over the window from the
        // first pixel would black out what you were reading in order to tell you
        // that you had touched it.
        color: Qt.rgba(root.body.r, root.body.g, root.body.b, root.body.a * tuck.value)
        stroke: Appearance.colour.fillStronger
        strokeWidth: Appearance.font.stem

        // THE WINDOW'S OWN CONTENT, which is the whole reason the lift reads as
        // picking something up rather than as a card appearing over it. At zero
        // travel this sits exactly on the real window and is indistinguishable
        // from it; the first pixel of the swipe peels the picture off the thing
        // it is a picture of.
        //
        // ONE FRAME, like the targets on the map. A live capture is a stream
        // negotiated in the middle of a gesture, and the gesture it lands in the
        // middle of is a flick; a still is also what every phone shows in its
        // own switcher, so nothing is lost but the cost.
        WindowView {
            id: shot

            anchors.fill: parent

            window: root.held?.client ?? null
            radius: card.radius
            live: false
        }

        // WHAT IT IS, for the moment before the compositor has handed over a
        // frame and for anything that can never give one. Never drawn over the
        // picture: once there is content, the window says which window it is
        // better than a mark and a title can.
        Column {
            anchors.centerIn: parent
            spacing: Appearance.padding.small

            // Only once there is a card to put them on: at the start this space
            // is the window's own content, and a title floating in the middle of
            // it belongs to nothing.
            opacity: tuck.value
            visible: opacity > 0.01 && !shot.ready

            AppMark {
                anchors.horizontalCenter: parent.horizontalCenter

                spec: root.held?.mark ?? ""
                size: Appearance.sizes.launcherIcon
                color: Appearance.colour.text
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                // Capped to the card it sits on rather than to a number: the
                // card is sized from the screen, so anything written here is
                // measured against whatever that came out as.
                width: Math.min(implicitWidth, card.width - Appearance.padding.normal * 2)
                text: root.held?.title ?? ""
                color: Appearance.colour.textDim
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
    }

    // THE STRIP ITSELF, and every refusal it makes.
    //
    // DECLARED LAST so it is above the launcher's own zone: declaration order is
    // input order in QML, and this has to be offered the press first in order to
    // be able to hand it back.
    MouseArea {
        id: strip

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.border + Appearance.sizes.windowGrab

        preventStealing: true

        // NOT `enabled: false` while blocked, and not disabled mid-gesture
        // either: tearing a MouseArea's grab down while a finger is on it means
        // the release never arrives, and the panel this shell would be leaving
        // half-open is a window left floating in the air. Every refusal below is
        // made on the PRESS, which is the one moment nothing is being held.
        onPressed: mouse => {
            // A MOUSE IS NOT A FINGER. Qt synthesises mouse events from touch
            // points nothing else claimed, so a real pointer says
            // NotSynthesized and a finger does not; refusing the press outright
            // is what leaves the mouse's bottom edge exactly as it was.
            if (!Appearance.sizes.windowEdge || mouse.source === Qt.MouseEventNotSynthesized || root.blocked) {
                mouse.accepted = false;
                return;
            }

            // A gesture still flying home does not own the next one.
            root.clear();

            const at = strip.mapToItem(root, mouse.x, mouse.y);
            const win = root.windowAt(at.x);

            // No window above this finger, so no handle: the press goes back to
            // the edge underneath, which is the launcher's.
            if (!win) {
                mouse.accepted = false;
                return;
            }

            root.begin(win, at.x, at.y);
        }

        onPositionChanged: mouse => {
            if (!strip.pressed || !root.held)
                return;
            const at = strip.mapToItem(root, mouse.x, mouse.y);
            root.track(at.x, at.y);
        }

        onReleased: root.release()

        // A grab taken away (by the compositor, by a screen lock, by the finger
        // being counted as a second touch point) is not a decision, so it puts
        // the window back rather than closing it.
        onCanceled: {
            hold.stop();
            if (root.held && root.lifted)
                root.finish("back", -1);
            else
                root.clear();
        }
    }
}


