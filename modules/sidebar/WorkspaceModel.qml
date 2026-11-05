pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "workspaces.js" as Workspaces

Item {
    id: root

    property int base: Appearance.sizes.workspaceSlot
    property int pitch: Appearance.sizes.workspaceWindowPitch
    property int gap: Appearance.sizes.workspaceGap

    readonly property real stride: Workspaces.stride(root.base, root.gap, Workspaces.HIT_REACH)

    property bool stack: false

    property int perRow: 1

    required property string screen

    readonly property int count: Hypr.countFor(root.screen)

    readonly property int band: Hypr.bandFor(root.screen)

    function idAt(i: int): int {
        return root.band + i;
    }

    readonly property int active: Hypr.activeOn(root.screen)

    readonly property string special: Hypr.specialOn(root.screen)
    readonly property bool eclipsed: special !== ""

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

            for (let m = 0; m < marks.length; m++) {

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
            y += h + root.stride;
        }
        return out;
    }

    readonly property real total: root.live.length ? root.live[root.live.length - 1].y + root.live[root.live.length - 1].h : root.base

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
        const f = Appearance.still ? 1 : 1 - Math.exp(-Appearance.animation.trackSpeed * dt);
        const n = Math.max(root.live.length, root.slots.length);

        const last = root.slots[root.slots.length - 1];
        const end = last ? last.y + last.h : 0;

        const out = [];
        for (let i = 0; i < n; i++) {
            const t = root.slots[i] ?? ({
                    y: end,
                    h: 0
                });
            const l = root.live[i];

            if (!l) {
                out.push({
                    y: t.y,
                    h: 0
                });
                continue;
            }

            out.push({
                y: Math.abs(t.y - l.y) < 0.25 ? t.y : l.y + (t.y - l.y) * f,
                h: Math.abs(t.h - l.h) < 0.25 ? t.h : l.h + (t.h - l.h) * f
            });
        }

        while (!root.scrubHeld && out.length > root.slots.length && out[out.length - 1].h === 0 && out[out.length - 1].y === end)
            out.pop();

        root.live = out;
    }

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

    readonly property real scrubPitch: root.base + root.stride

    property bool scrubHeld: false
    property bool scrubbing: false
    property bool scrubSpent: false

    property real scrubFromX: 0
    property real scrubFromY: 0

    property int scrubBase: 0
    property int scrubStep: 0
    property bool scrubFired: false

    property real scrubLastY: 0
    property real scrubLastAt: 0
    property real scrubVelocity: 0

    property int wheelPending: 0
    property real wheelRest: 0
    property real wheelSeen: 0
    property real wheelAt: 0
    property bool wheelHeld: false

    function scrubPress(x: real, y: real): void {
        scroll.finish();
        root.scrubBegin(x, y);
    }

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
        root.scrubLastAt = Date.now();
        root.scrubVelocity = 0;
    }

    function scrubMove(x: real, y: real): void {
        if (!root.scrubHeld || root.scrubSpent)
            return;

        const now = Date.now();
        root.scrubVelocity = Workspaces.eased(root.scrubVelocity, y - root.scrubLastY, now - root.scrubLastAt);
        root.scrubLastY = y;
        root.scrubLastAt = now;

        if (!root.scrubbing) {
            const dx = x - root.scrubFromX;
            const dy = y - root.scrubFromY;

            if (Math.hypot(dx, dy) < Config.values.control.pullSlack)
                return;

            if (Math.abs(dy) <= Math.abs(dx)) {
                root.scrubSpent = true;
                return;
            }

            root.scrubbing = true;
        }

        const inc = Math.trunc((y - root.scrubFromY) / root.scrubPitch);
        if (inc === 0)
            return;
        root.scrubFromY += inc * root.scrubPitch;

        const next = Math.max(root.band - root.scrubBase, Math.min(root.band + root.count - 1 - root.scrubBase, root.scrubStep + inc));
        if (next === root.scrubStep)
            return;
        root.scrubStep = next;
        root.scrubFired = true;
        Hypr.switchTo(root.scrubBase + next);
    }

    function scrubRelease(): bool {
        let consumed = root.scrubFired;

        if (root.scrubbing && !root.scrubFired) {
            const to = root.scrubBase + Workspaces.flickDirection(Workspaces.settled(root.scrubVelocity, Date.now() - root.scrubLastAt));
            if (to !== root.scrubBase && to >= root.band && to < root.band + root.count) {
                Hypr.switchTo(to);
                consumed = true;
            }
        }

        root.scrubHeld = false;
        root.scrubbing = false;
        root.scrubSpent = false;
        return consumed;
    }

    function scrubCancel(): void {
        root.scrubHeld = false;
        root.scrubbing = false;
        root.scrubSpent = false;
    }

    function scrubWheel(wheel: var): bool {
        const notch = wheel.phase === 0 && wheel.pixelDelta.x === 0 && wheel.pixelDelta.y === 0 && wheel.angleDelta.y !== 0;
        if (!notch || root.scrubHeld || scroll.active)
            return scroll.feed(wheel);

        const now = Date.now();
        const counted = Workspaces.accumulate(root.wheelRest, wheel.angleDelta.y, now - root.wheelSeen);
        root.wheelSeen = now;
        root.wheelRest = counted.rest;
        wheel.accepted = true;
        if (counted.whole === 0)
            return true;

        const natural = wheel.inverted || Compositor.naturalScrollMouse;
        const notches = counted.whole * (natural ? 1 : -1);
        const to = Workspaces.notchTarget(root.active, root.wheelHeld ? root.wheelPending : null, root.wheelAt, now, notches, root.band, root.band + root.count - 1);
        root.wheelPending = to;
        root.wheelAt = now;
        root.wheelHeld = true;
        if (to !== root.active)
            Hypr.switchTo(to);
        return true;
    }

    ScrollGesture {
        id: scroll

        armed: !root.scrubHeld || scroll.active

        onBegan: root.scrubBegin(0, 0)
        onMoved: (dx, dy) => root.scrubMove(dx, dy)

        onEnded: root.scrubRelease()
    }

    FrameAnimation {
        running: root.moving
        onTriggered: root.step(frameTime)
    }

    Component.onCompleted: root.snap()
}
