pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// THE WHOLE WORKSPACE, DRAWN SMALL, as places to put the window in your hand.
// Every window on it becomes a target where it stands in the layout, and
// dropping on one makes the two trade places.
//
// A MAP, NOT AN OVERLAY, and that is forced by the layout rather than chosen.
// The first version drew each target at life size over the window it stood for,
// which is the most honest thing possible right up until the workspace is wider
// than the screen. A scrolling layout keeps windows off both sides of the
// viewport, and a target you cannot see is a window you cannot reach: the map
// exists so that "everything on this workspace" means everything, including what
// is scrolled away.
//
// SO IT IS THE WORKSPACE'S OWN BOUNDING BOX, scaled down and centred. Positions
// and sizes are the layout's, divided by one number, so the picture is the
// arrangement rather than a diagram of it: what is beside what, what is twice as
// wide as what, and how far off the edge the thing you were looking for is.
//
// EVERYTHING ON THE WORKSPACE, AND IT SCROLLS. This is the phone's app switcher:
// the cards sit side by side in the order they are actually in, at a size worth
// looking at, and the ones that do not fit are reached by moving toward them
// rather than by being shrunk until they do. Squeezing twenty columns into the
// content area makes twenty postage stamps, and the ones that shuffle when you
// aim are then too small to read as anything moving at all.
//
// THE STRIP IS SIZED BY HEIGHT, never by width. A workspace is one row however
// long it is, so the height is what has to fit and the width is what is allowed
// to overflow; `windows.scale` caps it so a workspace holding one window does
// not draw it across the whole screen. The card in the hand takes the same
// scale, so the thing you are carrying and the hole it came out of are the same
// size and dropping reads as slotting in.
//
// IT FOLLOWS THE HAND. It opens centred on the window you picked up, and pushing
// the finger toward either edge scrolls it, faster the further in you push. That
// is the only way a target that starts off the strip can ever be reached, and it
// is the same thing the compositor's own scrolling layout does when you walk off
// the end of it.
//
// The held window is in the map but is not a target: its slot is drawn empty,
// because that is the space the swap is going to fill and the one place on
// screen that means "put it back".
Item {
    id: root

    required property ShellScreen screen

    // The area to draw the map in.
    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    // The window in the hand.
    property string heldAddr: ""


    // WHAT DROPPING MEANS: "move" or "swap". See WindowEdge's mode pill.
    property string mode: "move"

    property real pointX: 0
    property real pointY: 0
    property bool active: false

    // EVERY WINDOW ON THE WORKSPACE, in the compositor's own coordinates, held
    // one included. Off-screen ones too: `clientsOn` filters by workspace and
    // not by what happens to be inside the viewport, which is the whole reason
    // this works on a scrolling layout.
    //
    // FROZEN THE MOMENT THE MAP COMES UP, and that is load-bearing rather than a
    // saving. The swap is dispatched for real while you are still hovering, so
    // the windows underneath ARE moving; a map that re-read them would move the
    // target out from under the finger, which un-aims it, which undoes the swap,
    // which moves it back, at whatever rate the compositor animates. The map is
    // the arrangement you started with, and the preview on top of it is what the
    // arrangement is becoming.
    property var all: []

    onActiveChanged: if (root.active)
        root.snapshot()

    function snapshot(): void {
        // THE LANDING IS RESET HERE AND NOWHERE ELSE. It has to outlive the
        // gesture that caused it: see `landed`. The one moment it can safely go
        // back to zero is the moment a new map is being built, which is this
        // one, and it goes back instantly rather than by animating, because
        // there is nothing on screen yet to animate.
        root.landed = false;
        land.snap();

        const out = [];

        for (const client of Hypr.clientsOn(root.screen)) {
            const o = client.lastIpcObject;
            if (!o?.at || !o?.size)
                continue;

            const raw = o.address ?? "";
            const addr = raw.startsWith("0x") ? raw : `0x${raw}`;
            if (!addr)
                continue;

            out.push({
                addr,
                client,
                held: addr === root.heldAddr,
                mark: AppIcons.markFor(Hypr.classOf(client)),
                x: o.at[0] - root.screen.x,
                y: o.at[1] - root.screen.y,
                w: o.size[0],
                h: o.size[1]
            });
        }

        root.all = out;
        root.centre();
    }

    // OPEN ON THE WINDOW IN THE HAND. The strip can be several screens long and
    // the one thing certain about where you want to be looking is that it is
    // near what you just picked up.
    function centre(): void {
        for (const w of root.all) {
            if (!w.held)
                continue;
            const mid = (w.x + w.w / 2 - root.box.x) * root.fitted;
            root.pan = Math.max(0, Math.min(mid - root.holeWidth / 2, root.maxPan));
            return;
        }
        root.pan = 0;
    }

    // PUSHING AT AN EDGE SCROLLS IT, faster the further past the margin the
    // finger goes. A rate rather than a position, because the finger has to be
    // free to keep aiming while the strip moves under it: a strip that mapped
    // the finger straight onto a scroll offset would slide every target away
    // from the hand that was reaching for it.
    Timer {
        interval: 16
        repeat: true
        running: root.active && !root.landed && root.maxPan > 0

        onTriggered: {
            const margin = root.holeWidth * 0.18;
            const left = root.holeX + margin - root.pointX;
            const right = root.pointX - (root.holeX + root.holeWidth - margin);
            const push = left > 0 ? -left : right > 0 ? right : 0;
            if (push === 0)
                return;

            // A whole content area a second at the very edge, which is fast
            // enough to cross a long workspace without being a flick.
            const step = root.holeWidth * (interval / 1000) * Math.min(1, Math.abs(push) / margin) * Math.sign(push);
            root.pan = Math.max(0, Math.min(root.pan + step, root.maxPan));
        }
    }

    // What the strip has to cover: the union of every window's rectangle, which
    // on a scrolling layout is routinely several screens wide and starts left of
    // zero.
    readonly property rect box: {
        if (root.all.length === 0)
            return Qt.rect(0, 0, root.width, root.height);

        let x0 = Infinity;
        let y0 = Infinity;
        let x1 = -Infinity;
        let y1 = -Infinity;

        for (const w of root.all) {
            x0 = Math.min(x0, w.x);
            y0 = Math.min(y0, w.y);
            x1 = Math.max(x1, w.x + w.w);
            y1 = Math.max(y1, w.y + w.h);
        }

        return Qt.rect(x0, y0, Math.max(1, x1 - x0), Math.max(1, y1 - y0));
    }

    // As tall as the area allows, and never bigger than the cap. The width is
    // deliberately not consulted: it is what scrolls.
    readonly property real fitted: Math.min(root.holeHeight / root.box.height, Appearance.sizes.windowScale)

    // HOW FAR ALONG THE STRIP IS, in drawn pixels, and how far it may go. Zero
    // when the whole thing fits, in which case it is centred instead.
    property real pan: 0

    readonly property real stripW: root.box.width * root.fitted
    readonly property real maxPan: Math.max(0, root.stripW - root.holeWidth)

    // THE MAP LANDS ON THE REAL WINDOWS WHEN THE FINGER LEAVES.
    //
    // Set once the gesture is over, and the whole transform then walks to the
    // identity: scale 1, origin 0, which is the compositor's own coordinates. So
    // every card on the map grows into the exact rectangle of the window it is a
    // picture of, the dimming comes off as it goes, and what is left at the end
    // is a set of captures lying pixel for pixel on the windows they were taken
    // from. Clearing them is then invisible.
    //
    // The swap it is landing on has ALREADY HAPPENED, dispatched while the
    // finger was still hovering, so there is nothing to wait for and nothing to
    // catch up with: the compositor and the map arrive at the same picture from
    // opposite directions.
    //
    // AND IT IS NEVER TAKEN BACK WHILE THE MAP IS ON SCREEN, which is the whole
    // of why the finish used to look wrong. Clearing the gesture used to release
    // this at the same moment it started the fade, so every card turned round
    // and flew back to the small arrangement it had come from while going
    // transparent: the cards had arrived, and then visibly zoomed away from the
    // windows they had just landed on. A landing is a place, not a phase of a
    // gesture. It is reset when the next map is built, so what the fade does is
    // exactly nothing except take the opacity off things that are already lying
    // where they belong.
    property bool landed: false

    Follow {
        id: land

        target: root.landed ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.002
    }

    // The strip's own scale, which is what the card in the hand matches.
    readonly property real mapScale: root.fitted

    // ...and the scale things are DRAWN at, which walks to 1 as the strip lands
    // on the windows. Only corner radii read it: everything else lands by
    // chasing its own window's real rectangle, one delegate at a time.
    readonly property real drawScale: root.fitted + (1 - root.fitted) * land.value

    // Where the box's origin lands once the map is centred, so a window's place
    // is one multiply and one add away. It walks to zero with the landing,
    // because zero is where the compositor's own coordinates start.
    readonly property real mapX: root.holeX + Math.max(0, root.holeWidth - root.stripW) / 2 - root.pan - root.box.x * root.fitted
    readonly property real mapY: root.holeY + (root.holeHeight - root.box.height * root.fitted) / 2 - root.box.y * root.fitted
    readonly property real originX: root.mapX
    readonly property real originY: root.mapY

    function place(w: var): rect {
        return Qt.rect(root.originX + w.x * root.mapScale, root.originY + w.y * root.mapScale, w.w * root.mapScale, w.h * root.mapScale);
    }

    // The targets: everything drawn except the one in the hand.
    readonly property var windows: root.all.filter(w => !w.held)

    // THE LAYOUT'S OWN UNIT IS THE COLUMN, not the window. The scrolling layout
    // can stack more than one window at the same x, and a move shuffles COLUMNS
    // along; grouping by x is how a plan about places stays a plan about places
    // even when one of them holds two windows.
    readonly property var columns: {
        const by = {};
        for (const w of root.all) {
            const k = `${w.x}`;
            if (!by[k])
                by[k] = {
                    x: w.x,
                    items: []
                };
            by[k].items.push(w);
        }
        return Object.keys(by).map(k => by[k]).sort((a, b) => a.x - b.x);
    }

    function columnOf(w: var): int {
        for (let i = 0; i < root.columns.length; i++)
            if (root.columns[i].x === w.x)
                return i;
        return -1;
    }

    readonly property int heldColumn: {
        for (const w of root.all)
            if (w.held)
                return root.columnOf(w);
        return -1;
    }

    readonly property int aimColumn: root.over >= 0 ? root.columnOf(root.windows[root.over]) : -1

    // HOW FAR THE HELD COLUMN HAS TO WALK, signed. The whole of what a move is,
    // handed to Hypr.walkColumn as one number.
    readonly property int steps: root.aimColumn >= 0 && root.heldColumn >= 0 ? root.aimColumn - root.heldColumn : 0

    // The address a swap would be made with, or "".
    readonly property string aimAddr: root.over >= 0 ? root.windows[root.over].addr : ""

    // WHERE EVERY COLUMN ENDS UP under the current aim, as an x per column.
    //
    // A move takes the held column out of the list and puts it back at the aim,
    // and then the whole list is laid out at the x positions the columns already
    // occupy: what shuffles is the OCCUPANTS, not the places, which is exactly
    // what the layout does when it walks a column past its neighbours.
    readonly property var planX: {
        const xs = root.columns.map(c => c.x);
        if (root.aimColumn < 0 || root.heldColumn < 0 || root.mode === "swap")
            return xs;

        const idx = root.columns.map((c, k) => k);
        idx.splice(root.heldColumn, 1);
        idx.splice(root.aimColumn, 0, root.heldColumn);

        const out = new Array(xs.length);
        for (let p = 0; p < idx.length; p++)
            out[idx[p]] = xs[p];
        return out;
    }

    // WHERE ONE WINDOW WOULD END UP, in the compositor's coordinates.
    //
    // A swap exchanges two whole rectangles, sizes and all, because that is what
    // the compositor does with them; a move only ever changes an x, because the
    // columns keep their own widths and only their order changes.
    function planned(w: var): var {
        if (root.aimColumn < 0 || root.heldColumn < 0)
            return w;

        if (root.mode === "swap") {
            const aim = root.windows[root.over];
            if (w.held)
                return aim;
            if (w.addr === aim.addr) {
                for (const h of root.all)
                    if (h.held)
                        return h;
            }
            return w;
        }

        const col = root.columnOf(w);
        return {
            x: root.planX[col],
            y: w.y,
            w: w.w,
            h: w.h
        };
    }

    // WHERE A WINDOW ACTUALLY IS, RIGHT NOW, read from the model rather than
    // from the snapshot the map is frozen at.
    //
    // This is what the landing chases, and it has to be live. Everything the
    // drop set in motion happens after it: the columns walk, and focusing the
    // window you carried scrolls the whole viewport to bring it into view, which
    // moves every other window on the workspace with it. A strip that landed on
    // the geometry it was opened with would put its cards down where the windows
    // USED to be, and on a scrolling layout that is frequently off the side of
    // the screen entirely, which is exactly what it looked like.
    //
    // Falls back to the frozen rectangle for a window that has since died, so a
    // card always has somewhere to go.
    function liveRect(addr: string, fallback: var): rect {
        for (const client of Hypr.clientsOn(root.screen)) {
            const o = client.lastIpcObject;
            if (!o?.at || !o?.size)
                continue;

            const raw = o.address ?? "";
            if ((raw.startsWith("0x") ? raw : `0x${raw}`) !== addr)
                continue;

            return Qt.rect(o.at[0] - root.screen.x, o.at[1] - root.screen.y, o.size[0], o.size[1]);
        }

        return Qt.rect(fallback.x, fallback.y, fallback.w, fallback.h);
    }

    // Where a target sits when nothing is being previewed, which is what the hit
    // test is made against.
    function slotRect(i: int): rect {
        return root.place(root.windows[i]);
    }

    // WHICH ONE THE FINGER IS OVER, or -1. Containment against the map, since
    // the map is the only thing on screen the finger can be pointing at.
    //
    // TESTED AGAINST WHERE THE TARGET RESTS, not against where its preview has
    // moved to, and that is load-bearing rather than a shortcut. The delegate
    // travels when it is aimed; a hit test that followed it would move the
    // target out from under the finger, un-aim it, move it back, and aim it
    // again, forever, at whatever rate the animation runs.
    readonly property int over: {
        if (!root.active || root.landed)
            return -1;

        for (let i = 0; i < root.windows.length; i++) {
            const s = root.slotRect(i);
            if (root.pointX >= s.x && root.pointX <= s.x + s.width && root.pointY >= s.y && root.pointY <= s.y + s.height)
                return i;
        }

        return -1;
    }

    Follow {
        id: reveal

        target: root.active ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // How present the map is, for anything drawn outside it that has to leave at
    // the same time. The card in the hand is the only such thing.
    readonly property real fade: reveal.value

    visible: reveal.value > 0.01
    opacity: reveal.value

    // EVERY WINDOW ON THE MAP, the held one included: it is drawn as an empty
    // outline, because it is the hole the swap is going to fill and the one
    // place on screen that means "put it back".
    //
    // BUILT ONLY WHILE THE MAP IS UP. Every delegate holds a capture, and a
    // capture is a live request to the compositor for somebody else's window
    // buffer: kept alive by an idle shell it would be a permanent screen-reading
    // subscription per window, taken for a gesture nobody is making. The lists
    // themselves stay ungated, because the drop's outro reads them after the map
    // has already begun fading.
    // CLIPPED TO THE CONTENT AREA, because the strip is longer than the screen
    // and its ends have to stop somewhere. The chassis is that somewhere: a card
    // scrolled off the end must not be drawn over the sidebar or the band, which
    // are the shell's own body and not part of the workspace.
    //
    // The inner item cancels the outer one's offset, so everything below goes on
    // working in the surface's coordinates and no geometry in this file has to
    // know the clip exists.
    Item {
        x: root.holeX
        y: root.holeY
        width: root.holeWidth
        height: root.holeHeight
        clip: true

        Item {
            x: -root.holeX
            y: -root.holeY
            width: root.width
            height: root.height

            Repeater {
                model: root.visible ? root.all : []

                delegate: Item {
                    id: slot

                    required property int index
                    required property var modelData

                    readonly property bool aimed: !slot.modelData.held && root.over >= 0 && root.windows[root.over].addr === slot.modelData.addr

                    // WHERE IT IS, AND WHERE IT WOULD GO. The plan is the whole answer:
                    // under a swap two windows exchange rectangles, under a move the
                    // held column walks to the aim and everything it passes shuffles up
                    // by one. Move the finger away and the plan is the identity again,
                    // so the preview is a question rather than a change.
                    readonly property rect spot: root.place(root.planned(slot.modelData))

                    // ...AND WHERE IT ENDS UP, which is wherever the compositor has
                    // actually put it by the time the finger is gone. Chased per card
                    // rather than by scaling the whole strip, because the strip's own
                    // arrangement is a frozen picture and the windows have moved since.
                    readonly property rect home: root.liveRect(slot.modelData.addr, slot.modelData)

                    x: slot.spot.x + (slot.home.x - slot.spot.x) * land.value
                    y: slot.spot.y + (slot.home.y - slot.spot.y) * land.value
                    width: slot.spot.width + (slot.home.width - slot.spot.width) * land.value
                    height: slot.spot.height + (slot.home.height - slot.spot.height) * land.value

                    Behavior on x {
                        // OFF WHILE LANDING. These smooth a target jumping from one
                        // place to another; the landing moves every one of them every
                        // frame, and a smoother over that is just lag.
                        enabled: !root.landed

                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on y {
                        enabled: !root.landed

                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on width {
                        enabled: !root.landed

                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on height {
                        enabled: !root.landed

                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    // The hole. It is a statement about a gesture in progress, so it
                    // goes as soon as the gesture is over rather than landing with
                    // everything else.
                    G2Rect {
                        anchors.fill: parent
                        visible: slot.modelData.held

                        radius: Appearance.sizes.windowRadius * root.drawScale
                        color: "transparent"
                        stroke: Appearance.colour.separator
                        strokeWidth: Appearance.font.stem
                        opacity: 1 - land.value
                    }

                    G2Rect {
                        anchors.fill: parent
                        visible: !slot.modelData.held

                        radius: Appearance.sizes.windowRadius * root.drawScale
                        color: Appearance.colour.fill
                        stroke: slot.aimed ? Appearance.colour.accent : "transparent"
                        strokeWidth: Appearance.font.stem
                    }

                    // THE WINDOW ITSELF, which is what makes these places rather than
                    // labels: you are aiming at the thing you can see. A single frame,
                    // because a target standing still has nothing to say frame by frame.
                    WindowView {
                        id: shot

                        anchors.fill: parent
                        visible: !slot.modelData.held

                        window: slot.modelData.held ? null : slot.modelData.client
                        radius: Appearance.sizes.windowRadius * root.drawScale
                        live: false
                    }

                    // DIMMED UNTIL AIMED. The scrim behind everything says the shell has
                    // taken the screen over, and lifting it off one card is the whole of
                    // what "this one" looks like: the window's own picture brightens
                    // rather than a fill being added to it. It comes off entirely as the
                    // map lands, so what is left lying on the real windows is the
                    // windows.
                    G2Rect {
                        anchors.fill: parent
                        visible: !slot.modelData.held

                        radius: Appearance.sizes.windowRadius * root.drawScale
                        color: Appearance.colour.scrim
                        opacity: (slot.aimed ? 0 : 0.45) * (1 - land.value)

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Appearance.padding.small
                        visible: !slot.modelData.held

                        // The mark stands in until there is a frame, and stays for a
                        // window that can never give one. It is not drawn over a live
                        // capture: the picture already says which window this is, and a
                        // glyph on top of it would be the caption arguing with it.
                        AppMark {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !shot.ready

                            spec: slot.modelData.mark
                            size: Appearance.sizes.launcherIcon
                            color: slot.aimed ? Appearance.colour.text : Appearance.colour.textDim
                        }

                        // WHAT WILL HAPPEN, and only under the finger. The picture says
                        // which window this is; the mark says what dropping here does to
                        // it, which is the half a target cannot carry on its own, and it
                        // is the mode's own mark so the answer is never in doubt.
                        // Nothing is written on the others, because a screen full of the
                        // same glyph says nothing at all.
                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter

                            name: root.mode === "swap" ? "swap_horiz" : "low_priority"
                            size: Appearance.font.iconSize
                            color: Appearance.colour.accent
                            opacity: slot.aimed ? 1 - land.value : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
