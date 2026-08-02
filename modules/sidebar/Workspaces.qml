pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.components.blob
import qs.services

// Vertical workspace indicators: a chain of beads, and what is on them.
//
// A workspace is not a number, it is the windows you left there, so each bead
// stacks one glyph per window (see Apps.iconFor: the mark comes from the desktop
// entry's freedesktop categories, so an app this shell has never seen still gets
// the right one). An empty workspace is a small bead with nothing in it. Nothing
// here is labelled 1..N: the column IS the order.
//
// The beads are not shapes drawn next to each other. They are one signed
// distance field (see components/blob/beads.frag): a thin rail with a bead grown
// out of it per workspace, smooth-unioned, so the joins are fillets the field
// works out for itself and a bead that swells pushes the rail out around it. The
// accent is washed out of the active bead by DISTANCE rather than painted onto
// it, so the colour bleeds down the chain and fades.
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
    readonly property int dot: Appearance.sizes.wsDot
    readonly property int bump: Appearance.sizes.wsBump

    // Room around the column for the swell and the light coming off it. The
    // field is drawn into this margin, the layout is not: slots still sit in
    // root's own coordinates and the field offsets by it.
    readonly property int bleed: Appearance.padding.normal

    // Which slot the cursor is on, or -1. A hovered bead swells too, by less.
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

    // THE MOTION, for the same reason the layout is one pass: the icons and the
    // liquid behind them have to agree to the pixel. Two components chasing the
    // same target with the same maths still disagree for a frame at a time, and
    // a bead half a pixel behind its own icons reads as a wobble. So the whole
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
            // A slot that did not exist a moment ago has no "from" to travel
            // out of, so it starts where it belongs.
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

    Component.onCompleted: {
        root.snap();
        slideY.snap();
        slideH.snap();
        trailY.snap();
        trailH.snap();
    }

    readonly property var activeSlot: root.slots[Hypr.activeId - 1]
    readonly property var lastLive: root.live[root.live.length - 1]

    implicitWidth: slot
    implicitHeight: lastLive ? lastLive.y + lastLive.h : slot

    // The active bead slides between slots on its own. Its targets are the RAW
    // layout rather than the smoothed one: when a workspace grows a window, the
    // bead and the slot under it start from the same place with the same rate,
    // so they travel as one shape instead of one chasing the other.
    Follow {
        id: slideY
        target: root.activeSlot?.y ?? 0
    }

    Follow {
        id: slideH
        target: root.activeSlot?.h ?? root.slot
    }

    // The same chase, slower. At rest it sits exactly under the active bead and
    // costs nothing; in motion it is behind, and because the field melts the two
    // together the bead STRETCHES between where it is going and where it was.
    // A rigid shape sliding down a rail is a slider; this is a liquid.
    Follow {
        id: trailY
        target: slideY.target
        speed: Appearance.anim.trackSpeed * Appearance.anim.trail
    }

    Follow {
        id: trailH
        target: slideH.target
        speed: Appearance.anim.trackSpeed * Appearance.anim.trail
    }

    BeadField {
        anchors.fill: parent
        anchors.margins: -root.bleed

        // The rail: as long as the column, plus the padding that used to be the
        // container's. Thin enough that it reads as what the beads are ON.
        rail: Qt.vector4d((width - Appearance.sizes.wsSpine) / 2, root.bleed - Appearance.padding.small, Appearance.sizes.wsSpine, root.implicitHeight + Appearance.padding.small * 2)

        beads: root.live.map((l, i) => {
            const info = root.slots[i];
            const busy = info && (info.windows.length > 0 || info.rest > 0);
            const swell = root.hovered === i ? root.bump : 0;
            // An empty workspace is a dot, centred in the slot it stands for,
            // rather than a capsule with nothing in it.
            return busy ? {
                y: l.y + root.bleed,
                h: l.h,
                w: root.slot + swell,
                occupied: true
            } : {
                y: l.y + root.bleed + (l.h - root.dot) / 2,
                h: root.dot + swell,
                w: root.dot + swell,
                occupied: false
            };
        })

        activeBead: Qt.vector4d(slideY.value + root.bleed, slideH.value, root.slot + root.bump * 2, 1)
        // Narrower than the bead it follows, so the stretch tapers off behind
        // rather than dragging a second bead of the same size around.
        trailBead: Qt.vector4d(trailY.value + root.bleed, trailH.value, root.slot, 1)
    }

    Repeater {
        // Modelled by the COUNT, not by `slots`: a Repeater over a JS array
        // rebuilds every delegate whenever the array is reassigned, and this one
        // is reassigned on every window event. Keyed by an int, the slots
        // persist and only their bindings update.
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

            y: slotItem.geom.y
            width: root.slot
            height: slotItem.geom.h

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hovered = slotItem.index
                onExited: if (root.hovered === slotItem.index)
                    root.hovered = -1
                onClicked: Hypr.switchTo(slotItem.info.id)
            }

            // One row per window. The rows are centred in the slot as a group: a
            // slot is `root.slot` tall plus a pitch per extra row, so the
            // group's inset is the same whatever it holds.
            Repeater {
                // A ScriptModel, NOT the array: the array is rebuilt on every
                // Hyprland event, and a plain-array Repeater would tear down and
                // rebuild every icon each time. This diffs it, so a window
                // opening touches only its own row.
                model: ScriptModel {
                    values: slotItem.info.windows
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool focused: Hypr.isFocused(modelData)

                    y: (root.slot - root.pitch) / 2 + index * root.pitch
                    width: root.slot
                    height: root.pitch

                    Icon {
                        anchors.centerIn: parent
                        name: Apps.iconFor(Hypr.classOf(row.modelData))

                        // The focused window is the only thing in the column at
                        // full label weight. That is the whole hierarchy: the
                        // colour under it says which workspace you are on, this
                        // says which window you are in.
                        color: row.focused || winMouse.containsMouse ? Appearance.colour.text : Appearance.colour.textDim

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    // Clicking a window goes to THAT window, not merely to its
                    // workspace. Hyprland's focuswindow brings the workspace
                    // along with it, so this is strictly more than the slot's
                    // own click does.
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

            // "and more". Sits in the row after the last icon, so an overflowing
            // workspace is capped rather than truncated silently.
            Icon {
                visible: slotItem.info.rest > 0
                x: 0
                y: (root.slot - root.pitch) / 2 + slotItem.info.windows.length * root.pitch
                width: root.slot
                height: root.pitch
                name: "more_horiz"
                color: Appearance.colour.textFaint
            }
        }
    }
}
