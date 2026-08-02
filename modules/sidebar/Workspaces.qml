pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Vertical workspace indicators: a stack of plates, and the one you are on is
// pulled out.
//
// A workspace is not a number, it is the windows you left there, so each plate
// carries one glyph per window (see Apps.iconFor: the mark comes from the desktop
// entry's freedesktop categories, so an app this shell has never seen still gets
// the right one). Nothing here is labelled 1..N: the column IS the order.
//
// LENGTH IS THE STATE, and it is the only thing that says it: a short mark for a
// workspace with nothing on it, further in when it holds windows, all the way out
// for the one you are on. Index tabs, and a bar chart of how busy the machine is,
// which turn out to be the same drawing. There is no separate indicator sliding
// around on top: the plate you go to IS the indicator, and it grows.
//
// THE PLATES ARE HINGED INSIDE THE FRAME, not on the screen's edge. The first
// `band` pixels of this item are the chassis's frame, which runs around the whole
// display; a plate reaching into it makes the frame bulge green in one place and
// reads as a defect rather than as a tab. So the plates start where the frame
// ends, and stop a band short of the bar's inner edge, which leaves the same gap
// at both ends and puts a full-length plate exactly under the icon column.
//
// Depth is thickness and layering, never a shadow or a bevel: an inactive plate
// is one sheet of material, the active one is two with the accent in the upper
// sheet, and it is longer than the rest. Where you are is literally more glass,
// pulled further out.
//
// Every position comes from one pass down the column (see
// ~/.claude/rules/math-over-hardcoding.md). A slot is as tall as the windows it
// holds, so where slot i sits depends on what the slots above it are holding;
// nothing knows its own y, and adding a workspace or a window changes only the
// data the pass runs over.
Item {
    id: root

    readonly property int count: Hypr.count
    readonly property int slot: Appearance.sizes.wsSlot
    readonly property int gap: Appearance.sizes.wsGap
    readonly property int pitch: Appearance.sizes.wsWindowPitch
    readonly property int maxWindows: Appearance.sizes.wsMaxWindows
    readonly property int tick: Appearance.sizes.wsTick

    // WHERE A PLATE STARTS AND HOW FAR IT CAN GO. Both are the chassis's own
    // band, so a full-length plate is inset by the same amount at each end and
    // lands centred on the icon column without either being told about the
    // other. Nothing here is a number chosen to look right.
    readonly property real hinge: Appearance.sizes.band
    readonly property real span: width - hinge * 2

    // The other two states, as fractions of that span. The active one is the
    // whole span by definition: it is what "pulled all the way out" means.
    readonly property real emptyReach: Appearance.sizes.wsEmptyReach
    readonly property real busyReach: Appearance.sizes.wsBusyReach

    // Which slot the cursor is on, or -1.
    property int hovered: -1

    // THE LAYOUT: { id, y, h, windows, rest } per slot, in one pass.
    readonly property var slots: {
        const out = [];
        let y = 0;
        for (let i = 0; i < root.count; i++) {
            const id = i + 1;
            const clients = Hypr.clientsIn(id);
            // The overflow mark is a ROW like any other, so a workspace with
            // twenty windows on it is exactly as tall as one at the cap and the
            // column can never run off the screen.
            const over = clients.length > root.maxWindows;
            const windows = over ? clients.slice(0, root.maxWindows - 1) : clients;
            const rows = Math.max(1, windows.length + (over ? 1 : 0));

            const h = root.slot + (rows - 1) * root.pitch;
            out.push({
                id,
                y,
                h,
                windows,
                rest: clients.length - windows.length
            });
            y += h + root.gap;
        }
        return out;
    }

    // THE MOTION, for the same reason the layout is one pass: the plates and the
    // icons on them have to agree to the pixel. Two components chasing the same
    // target with the same maths still disagree for a frame at a time, and a
    // plate half a pixel behind its own icons reads as a wobble. So the whole
    // column is smoothed HERE, once, and everything reads the result.
    //
    // Exponential smoothing, as everywhere else in this shell: fast when far,
    // gentle when close, correct at any frame time (see
    // ~/.claude/rules/animation-smoothing.md).
    property var live: []

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
        const out = [];
        for (let i = 0; i < root.slots.length; i++) {
            const t = root.slots[i];
            const l = root.live[i];
            // A slot that did not exist a moment ago has no "from" to travel out
            // of, so it starts where it belongs.
            if (!l) {
                out.push({
                    y: t.y,
                    h: t.h
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
        root.live = out;
    }

    function snap(): void {
        root.live = root.slots.map(s => ({
                    y: s.y,
                    h: s.h
                }));
    }

    Timer {
        interval: 16
        repeat: true
        running: root.moving
        onTriggered: root.step(interval / 1000)
    }

    Component.onCompleted: root.snap()

    readonly property var lastLive: root.live[root.live.length - 1]

    implicitHeight: lastLive ? lastLive.y + lastLive.h : slot

    Repeater {
        // Modelled by the COUNT, not by `slots`: a Repeater over a JS array
        // rebuilds every delegate whenever the array is reassigned, and this one
        // is reassigned on every window event. Keyed by an int, the slots persist
        // and only their bindings update.
        model: root.count

        delegate: Item {
            id: slotItem

            required property int index
            readonly property var info: root.slots[index] ?? ({
                    id: index + 1,
                    y: 0,
                    h: root.slot,
                    windows: [],
                    rest: 0
                })
            readonly property var geom: root.live[index] ?? slotItem.info
            readonly property bool isActive: Hypr.activeId === slotItem.info.id
            readonly property bool isOccupied: slotItem.info.windows.length > 0 || slotItem.info.rest > 0

            y: slotItem.geom.y
            width: root.width
            height: slotItem.geom.h

            // The click target is the whole width, plate or no plate: a 12px mark
            // is a mark, not a button, and reaching for a workspace should not
            // mean hitting it.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hovered = slotItem.index
                onExited: if (root.hovered === slotItem.index)
                    root.hovered = -1
                onClicked: Hypr.switchTo(slotItem.info.id)
            }

            // THE PLATE.
            G2Rect {
                id: plate

                // An EMPTY workspace gets a mark, not a plate: half as tall,
                // centred on the slot it stands for. Length alone did not carry
                // it, a short plate at full height is just a fat nub. Going there
                // makes it a plate like any other.
                readonly property bool solid: slotItem.isOccupied || slotItem.isActive

                // THE STATE IS ANIMATED, NOT THE PIXELS. Both of these resolve
                // through the slot's live height, which is already being smoothed
                // frame by frame; a Behavior on the resulting height would
                // restart a 220ms animation on every one of those frames and the
                // plate would rubber-band behind its own column. Animating the
                // fractions instead keeps the two motions independent: the reflow
                // stays exponential, the state change eases, neither fights the
                // other.
                readonly property real reachTarget: slotItem.isActive ? 1 : slotItem.isOccupied ? root.busyReach : root.emptyReach
                readonly property real tallTarget: solid ? 1 : 0.5

                property real reach: reachTarget
                property real tall: tallTarget

                x: root.hinge
                width: Math.round(root.span * reach)
                height: Math.round(parent.height * tall)
                y: (parent.height - height) / 2

                // SQUARE at the hinge, convex on the free end. A rounded corner
                // at the hinge would curl the plate away from the frame and leave
                // a notch of dead space behind it; the chassis's concave flare,
                // which is the right answer where a panel meets the screen's own
                // edge, needs more room than a 28px slot has and pinches the
                // plate's end off. Attached means flat against.
                topLeftRadius: 0
                bottomLeftRadius: 0
                topRightRadius: Appearance.rounding.normal
                bottomRightRadius: Appearance.rounding.normal

                color: root.hovered === slotItem.index || slotItem.isActive ? Appearance.colour.fillStrong : Appearance.colour.fill

                Behavior on reach {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on tall {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                // The second sheet: the accent, over the neutral one rather than
                // instead of it, so the active plate reads as thicker glass with
                // colour in it and not as a stain on the bar.
                G2Rect {
                    anchors.fill: parent
                    topLeftRadius: plate.topLeftRadius
                    bottomLeftRadius: plate.bottomLeftRadius
                    topRightRadius: plate.topRightRadius
                    bottomRightRadius: plate.bottomRightRadius
                    color: Appearance.colour.accentFill
                    opacity: slotItem.isActive ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                // The one saturated thing in the sidebar, and it is three pixels
                // wide, on the plate's hinge. The tint says which plate is yours;
                // this says it in the palette's own voice.
                G2Rect {
                    x: 0
                    width: root.tick
                    height: parent.height
                    radius: 0
                    color: Appearance.colour.accent
                    opacity: slotItem.isActive ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }
                }

                // One row per window, CENTRED IN THE PLATE, which is why they are
                // children of it: the icons ride the plate out as it grows rather
                // than sitting at a fixed place it happens to cover. A plate long
                // enough to hold them is then not a constraint on how short the
                // others can be. At full length the plate is centred in the bar,
                // so the icons of the workspace you are on land exactly on the
                // line the clock and the status icons keep.
                Repeater {
                    // A ScriptModel, NOT the array: the array is rebuilt on every
                    // Hyprland event, and a plain-array Repeater would tear down
                    // and rebuild every icon each time. This diffs it, so a
                    // window opening touches only its own row.
                    model: ScriptModel {
                        values: slotItem.info.windows
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool focused: Hypr.isFocused(modelData)

                        x: (plate.width - root.slot) / 2
                        y: (root.slot - root.pitch) / 2 + index * root.pitch
                        width: root.slot
                        height: root.pitch

                        Icon {
                            anchors.centerIn: parent
                            name: Apps.iconFor(Hypr.classOf(row.modelData))

                            // The focused window is the only thing in the column
                            // at full label weight. That is the whole hierarchy:
                            // the plate says which workspace you are on, this
                            // says which window you are in.
                            color: row.focused || winMouse.containsMouse ? Appearance.colour.text : Appearance.colour.textDim

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.fast
                                }
                            }
                        }

                        // Clicking a window goes to THAT window, not merely to
                        // its workspace. Hyprland's focuswindow brings the
                        // workspace along with it, so this is strictly more than
                        // the plate's own click does.
                        MouseArea {
                            id: winMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.hovered = slotItem.index
                            onExited: if (root.hovered === slotItem.index)
                                root.hovered = -1
                            onClicked: Hypr.focusClient(row.modelData)
                        }
                    }
                }

                // "and more". Sits in the row after the last icon, so an
                // overflowing workspace is capped rather than truncated silently.
                Icon {
                    visible: slotItem.info.rest > 0
                    x: (plate.width - root.slot) / 2
                    y: (root.slot - root.pitch) / 2 + slotItem.info.windows.length * root.pitch
                    width: root.slot
                    height: root.pitch
                    name: "more_horiz"
                    color: Appearance.colour.textFaint
                }
            }
        }
    }
}
