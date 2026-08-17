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
// AT THE SCALE OF THE CARD IN THE HAND. `preferred` is the size the lift is
// heading for, and the map takes it unless the workspace is too wide to fit, in
// which case everything shrinks together and the card follows the map rather
// than the other way round. The point is that the thing you are carrying and the
// hole it came out of are the same size, so dropping reads as slotting in.
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

    // The scale the card is heading for, which the map takes when it can.
    property real preferred: 1

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
    }

    // What the map has to cover: the union of every window's rectangle. Computed
    // rather than assumed to be the screen, because on a scrolling layout it is
    // routinely several screens wide and starts left of zero.
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

    // The biggest the map may be drawn, and then the size it actually is: the
    // card's own scale, unless the workspace will not fit at it.
    readonly property real fit: Math.min(root.holeWidth / root.box.width, root.holeHeight / root.box.height)
    readonly property real fitted: Math.min(root.preferred, root.fit)

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
    property bool landed: false

    Follow {
        id: land

        target: root.landed ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.002
    }

    readonly property real mapScale: root.fitted + (1 - root.fitted) * land.value

    // Where the box's origin lands once the map is centred, so a window's place
    // is one multiply and one add away. It walks to zero with the landing,
    // because zero is where the compositor's own coordinates start.
    readonly property real mapX: root.holeX + (root.holeWidth - root.box.width * root.fitted) / 2 - root.box.x * root.fitted
    readonly property real mapY: root.holeY + (root.holeHeight - root.box.height * root.fitted) / 2 - root.box.y * root.fitted
    readonly property real originX: root.mapX * (1 - land.value)
    readonly property real originY: root.mapY * (1 - land.value)

    function place(w: var): rect {
        return Qt.rect(root.originX + w.x * root.mapScale, root.originY + w.y * root.mapScale, w.w * root.mapScale, w.h * root.mapScale);
    }

    // The targets, and the hole. Two lists off one, so the delegates below can
    // be a repeater over everything while the aim only ever lands on a window
    // that is not the one being carried.
    readonly property var windows: root.all.filter(w => !w.held)
    readonly property rect heldPlace: {
        for (const w of root.all)
            if (w.held)
                return root.place(w);
        return Qt.rect(0, 0, 0, 0);
    }

    // Where a target sits when nothing is being previewed, which is also what
    // the card flies into when the swap is made: the two windows trade
    // rectangles, so the one the card is going to is the one the target left.
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

    visible: reveal.value > 0.01
    opacity: reveal.value

    // THE HOLE THE WINDOW CAME OUT OF, drawn as an outline and nothing else. It
    // is what the map would look like with a piece missing, which is what the
    // workspace currently is.
    G2Rect {
        x: root.heldPlace.x
        y: root.heldPlace.y
        width: root.heldPlace.width
        height: root.heldPlace.height

        radius: Appearance.sizes.windowRadius * root.mapScale
        color: "transparent"
        stroke: Appearance.colour.separator
        strokeWidth: Appearance.font.stem
        // The hole is a statement about a gesture in progress, so it goes as
        // soon as the gesture is over rather than landing with everything else.
        opacity: 1 - land.value
    }

    // BUILT ONLY WHILE THE MAP IS UP. Every delegate holds a capture, and a
    // capture is a live request to the compositor for somebody else's window
    // buffer: kept alive by an idle shell it would be a permanent screen-reading
    // subscription per window, taken for a gesture nobody is making. The lists
    // themselves stay ungated, because the drop's outro reads them after the map
    // has already begun fading.
    Repeater {
        model: root.visible ? root.windows : []

        delegate: Item {
            id: slot

            required property int index
            required property var modelData

            readonly property bool aimed: root.over === slot.index
            readonly property rect rest: root.place(slot.modelData)

            // WHERE IT IS, AND WHERE IT WOULD GO. Hovering a target moves it
            // into the space the held window left, which is exactly what
            // dropping would do to it: a swap is two windows trading places, and
            // the half you can be shown before committing is the other one's
            // half. Move away and it goes back, so the preview is a question
            // rather than a change.
            //
            // It takes the held window's SHAPE as well as its place, aspect and
            // all, because that is what the compositor will do to it. A preview
            // that kept its own proportions would be a nicer picture of a
            // different outcome.
            x: slot.aimed ? root.heldPlace.x : slot.rest.x
            y: slot.aimed ? root.heldPlace.y : slot.rest.y
            width: slot.aimed ? root.heldPlace.width : slot.rest.width
            height: slot.aimed ? root.heldPlace.height : slot.rest.height

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

            G2Rect {
                anchors.fill: parent

                radius: Appearance.sizes.windowRadius * root.mapScale
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

                window: slot.modelData.client
                radius: Appearance.sizes.windowRadius * root.mapScale
                live: false
            }

            // DIMMED UNTIL AIMED. The scrim behind everything says the shell has
            // taken the screen over, and lifting it off one card is the whole of
            // what "this one" looks like: the window's own picture brightens
            // rather than a fill being added to it.
            G2Rect {
                anchors.fill: parent

                radius: Appearance.sizes.windowRadius * root.mapScale
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
                // which window this is; the arrows say what dropping here does
                // to it, which is the half a target cannot carry on its own.
                // Nothing is written on the others, because a screen full of the
                // same glyph says nothing at all.
                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter

                    name: "swap_horiz"
                    size: Appearance.font.iconSize
                    color: Appearance.colour.accent
                    opacity: slot.aimed ? 1 : 0

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
