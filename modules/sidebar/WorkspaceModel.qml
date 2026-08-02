pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

// The workspace column's LAYOUT and MOTION, with no opinion about how it looks.
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
    property int maxWindows: Appearance.sizes.wsMaxWindows

    readonly property int count: Hypr.count

    // THE LAYOUT: { id, y, h, windows, rest } per slot, in one pass. Where slot i
    // sits depends on what the slots above it are holding, so nothing knows its
    // own y and adding a workspace or a window changes only the data this runs
    // over (see ~/.claude/rules/math-over-hardcoding.md).
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

            const h = root.base + (rows - 1) * root.pitch;
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
        while (out.length > root.slots.length && out[out.length - 1].h === 0 && out[out.length - 1].y === end)
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

    Timer {
        interval: 16
        repeat: true
        running: root.moving
        onTriggered: root.step(interval / 1000)
    }

    Component.onCompleted: root.snap()
}
