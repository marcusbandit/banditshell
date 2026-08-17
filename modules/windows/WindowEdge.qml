pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// THE BOTTOM EDGE OF A WINDOW, AS A HANDLE ON IT. Push up from there and the
// window comes up with your finger: let go and it is gone, hold and the
// workspaces come out to put it on.
//
// This is the phone gesture, and it is the phone gesture because a folded
// convertible has no keyboard to close a window with and no titlebar to aim a
// fingertip at. The whole of it is one motion out of the one place that is
// always reachable, and which of the three things it means is decided by what
// the hand does next rather than by which control it found:
//
//   up and away          the window is closed
//   up and held          the shelf comes out, and where you let go is where the
//                        window goes
//   up and back down     nothing happened
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
// THE CARD IS NOT THE WINDOW and never pretends to be. The compositor goes on
// drawing the real window underneath, exactly where it was, so what this draws
// is a proxy: it starts as a hairline exactly around the window (the one moment
// the two agree), fills with the shell's own material as it comes up, and ends
// as a small card wearing the application's mark and title. A screenshot would
// be a better lie and this shell does not tell it.
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

    // WHERE THE CARD IS WHILE A FINGER IS ON IT.
    //
    // Width and height interpolate from the window's own to the tile's by
    // `tuck`; the horizontal position walks from the window's left edge to
    // centred under the finger by the same number; and the BOTTOM EDGE simply
    // travels with the hand. That last one is what makes the lift read as one
    // object rather than as a card appearing: the gesture starts at the bottom
    // edge of the window, so at zero travel the card is exactly the window, and
    // every pixel the finger rises the card rises with it.
    readonly property real liveW: root.held ? root.held.w + (root.tileW - root.held.w) * tuck.value : 0
    readonly property real liveH: root.held ? root.held.h + (root.tileH - root.held.h) * tuck.value : 0
    readonly property real liveX: root.held ? root.held.x + (root.pointX - root.liveW / 2 - root.held.x) * tuck.value : 0
    readonly property real liveY: root.held ? root.held.y + root.held.h - root.rise - root.liveH : 0

    // ...and where it is once nobody is holding it. One ternary per side rather
    // than a second item, because it is the same card either way.
    readonly property real cardX: root.outro ? root.blend(root.rest.x, root.dest.x, gone.value) : root.liveX
    readonly property real cardY: root.outro ? root.blend(root.rest.y, root.dest.y, gone.value) : root.liveY
    readonly property real cardW: root.outro ? root.blend(root.rest.w, root.dest.w, gone.value) : root.liveW
    readonly property real cardH: root.outro ? root.blend(root.rest.h, root.dest.h, gone.value) : root.liveH

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
        root.racked = false;
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

    // The finger left.
    function release(): void {
        hold.stop();

        if (!root.held || !root.lifted) {
            // A tap on the band, which is not this gesture at all.
            root.clear();
            return;
        }

        if (root.racked) {
            const i = shelf.over;
            const slot = i >= 0 ? shelf.slots[i] : null;

            // Dropping a window back on the workspace it is already on is a
            // change of mind spelled as a drop, so it is answered as one.
            if (slot && slot.target !== Hypr.activeId) {
                Hypr.sendToWorkspace(root.held.addr, slot.target, Appearance.sizes.windowFollow);
                root.finish("sent", i);
            } else {
                root.finish("back", -1);
            }
            return;
        }

        // THE CLOSE ASKS FOR MORE THAN A PANEL'S PULL DOES, and deliberately.
        // Everything else this shell decides on a release is reversible: a panel
        // opened by mistake is one Escape from being gone. A window closed by
        // mistake is somebody's unsaved work. So the commit clause is "took it
        // the whole way, OR threw it", where a panel's is "a quarter of the way,
        // or drifting upward at all" - and a swipe that merely ran out of
        // conviction lands in neither and goes home.
        if (root.progress >= 1 || root.velocity >= Appearance.sizes.windowFling) {
            Hypr.closeWindow(root.held.addr);
            root.finish("close", -1);
        } else {
            root.finish("back", -1);
        }
    }

    // HOW IT ENDS, wherever it is ending from. The card's current rectangle is
    // frozen as the "from", because once the finger is gone there is nothing
    // left to track, and the "to" is the whole of what the three endings differ
    // by: off the top of the screen, onto the plate it was dropped on, or back
    // onto the window it was lifted off.
    function finish(how: string, plate: int): void {
        root.rest = {
            x: root.cardX,
            y: root.cardY,
            w: root.cardW,
            h: root.cardH
        };

        if (how === "close")
            root.dest = {
                x: root.rest.x,
                y: -root.rest.h,
                w: root.rest.w,
                h: root.rest.h
            };
        else if (how === "sent")
            root.dest = {
                x: shelf.plateX(plate),
                y: shelf.rowY,
                w: shelf.plateW,
                h: shelf.plateH
            };
        else
            root.dest = {
                x: root.held.x,
                y: root.held.y,
                w: root.held.w,
                h: root.held.h
            };

        root.grabbed = false;
        root.outro = how;
    }

    // Back to nothing at all, instantly. Called when an outro lands, and by the
    // next press, so a gesture started while the last one is still flying home
    // is not two cards.
    function clear(): void {
        root.outro = "";
        root.held = null;
        root.lifted = false;
        root.racked = false;
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

        onSettledChanged: if (gone.settled && root.outro && gone.value === 1)
            root.clear()
    }

    Follow {
        id: dim

        target: root.racked ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // HOW LONG STILL IS STILL. Armed at the lift and restarted by movement, so
    // it can only fire while a window is genuinely being held somewhere.
    Timer {
        id: hold

        interval: Appearance.sizes.windowHold
        onTriggered: if (root.grabbed && root.lifted)
            root.racked = true
    }

    // The screen behind the shelf, dimmed. It has no mask entry and no handler:
    // this shell gates input with the mask and visuals with opacity, and putting
    // a catcher here would swallow clicks for a mode that only a finger already
    // on the glass can be in.
    Rectangle {
        anchors.fill: parent

        visible: dim.value > 0.01
        color: Appearance.colour.scrim
        opacity: dim.value
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
        opacity: root.outro ? 1 - gone.value : 1

        // The window's own corner, because at the start of the gesture this IS
        // the window's outline and any other radius would show as a mismatch
        // against the real one underneath.
        radius: Appearance.sizes.windowRadius

        // The material FADES IN with the lift. At rest the card is a hairline
        // around a window you can still see; by the time it is a tile it is a
        // solid object. Painting the shell's surface over the window from the
        // first pixel would black out what you were reading in order to tell you
        // that you had touched it.
        color: Qt.rgba(root.body.r, root.body.g, root.body.b, root.body.a * tuck.value)
        stroke: Appearance.colour.fillStronger
        strokeWidth: Appearance.font.stem

        Column {
            anchors.centerIn: parent
            spacing: Appearance.padding.small

            // Only once there is a card to put them on: at the start this space
            // is the window's own content, and a title floating in the middle of
            // it belongs to nothing.
            opacity: tuck.value
            visible: opacity > 0.01

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
