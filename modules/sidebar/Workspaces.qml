pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Vertical workspace indicators: a ruler down the screen's edge, and a tab where
// you are.
//
// A workspace is not a number, it is the windows you left there, so each slot
// stacks one glyph per window (see Apps.iconFor: the mark comes from the desktop
// entry's freedesktop categories, so an app this shell has never seen still gets
// the right one). Nothing here is labelled 1..N: the column IS the order.
//
// THE SHAPE IS THE SCREEN'S EDGE. Every workspace is a PLATE hinged on it, and
// how far the plate reaches in is what the workspace is: a sliver for an empty
// one, most of the bar for one with windows on it, the whole width for the one
// you are on. Index tabs, and a bar chart of how busy the machine is, which are
// the same drawing. Square where they meet the edge, because a rounded corner
// there would curl the plate away and leave a notch of dead space behind it;
// rounded on the free end, because that end is free.
//
// Depth is thickness and layering, never a shadow or a bevel: the plates are one
// sheet of material, the active one is two with the accent in the upper sheet,
// and it is longer than the others, so where you are is literally more glass
// pulled further out of the edge.
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

    // How far a plate reaches in, as a fraction of the bar. The active one is
    // always the whole width; these are the other two states, and the ONLY thing
    // separating them is length.
    readonly property real stubReach: Appearance.sizes.wsStubReach
    readonly property real fullReach: Appearance.sizes.wsFullReach

    function reach(occupied: bool): real {
        return Math.round(root.width * (occupied ? root.fullReach : root.stubReach));
    }

    // THE SCREEN'S EDGE, which is where this item starts: it spans the whole
    // left band of the chassis, and the band is shell material all the way out
    // to the display's own edge. So the ruler is drawn at x = 0 and means it.
    readonly property real edge: 0

    // How far the tab reaches in, and how much taller it is than the slot it
    // marks. The WHOLE band: reach is what separates the other two states from
    // each other, so the one you are on spends the last of it and has nowhere
    // further to go. Nothing else in the column is ever this long.
    readonly property real tabWidth: width
    readonly property real tabPad: Appearance.padding.small / 2

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

    // THE MOTION, for the same reason the layout is one pass: the ticks, the
    // icons and the tab have to agree to the pixel. Two components chasing the
    // same target with the same maths still disagree for a frame at a time, and
    // a tick half a pixel behind its own icons reads as a wobble. So the whole
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

    Component.onCompleted: {
        root.snap();
        slideY.snap();
        slideH.snap();
    }

    readonly property var activeSlot: root.slots[Hypr.activeId - 1]
    readonly property var lastLive: root.live[root.live.length - 1]

    implicitHeight: lastLive ? lastLive.y + lastLive.h : slot

    // The tab slides between slots on its own. Its targets are the RAW layout
    // rather than the smoothed one: when a workspace grows a window, the tab and
    // the slot under it start from the same place at the same rate, so they
    // travel as one thing instead of one chasing the other.
    Follow {
        id: slideY
        target: root.activeSlot?.y ?? 0
    }

    Follow {
        id: slideH
        target: root.activeSlot?.h ?? root.slot
    }

    // THE TAB. Two sheets: a neutral one that makes the material thicker, and
    // the accent over it. A tint alone reads as a coloured stain on the bar; the
    // pair reads as more glass, with colour in it.
    G2Rect {
        id: tab

        x: root.edge
        y: slideY.value - root.tabPad
        width: root.tabWidth
        height: slideH.value + root.tabPad * 2

        // SQUARE where it meets the screen's edge, convex on its free end. A
        // rounded corner there would curl the tab away from the edge and leave a
        // notch of dead space behind it; a concave flare, which is what the
        // chassis uses at this boundary, needs more room than a 28px slot has
        // and pinches the tab's own end off. It is attached to the edge, so it
        // ends flat against it.
        topLeftRadius: 0
        bottomLeftRadius: 0
        topRightRadius: Appearance.rounding.normal
        bottomRightRadius: Appearance.rounding.normal

        color: Appearance.colour.fillStrong

        G2Rect {
            anchors.fill: parent
            topLeftRadius: tab.topLeftRadius
            bottomLeftRadius: tab.bottomLeftRadius
            topRightRadius: tab.topRightRadius
            bottomRightRadius: tab.bottomRightRadius
            color: Appearance.colour.accentFill
        }

        // The one saturated thing in the sidebar, and it is three pixels wide,
        // hard on the screen's edge. The tint says which plate is yours; this
        // says it in the palette's own voice, at the one place in the bar that
        // cannot be mistaken for anything else.
        G2Rect {
            x: 0
            width: root.tick
            height: parent.height
            radius: 0
            color: Appearance.colour.accent
        }
    }

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

            // THE PLATE. Hinged on the screen's edge, reaching in as far as the
            // workspace is worth: a sliver when empty, most of the bar when it
            // holds windows. Hidden under the tab when this is where you are, so
            // the two never stack their translucency into a denser patch.
            G2Rect {
                x: root.edge
                // An empty workspace gets a mark, not a plate: half as tall,
                // centred on the slot it stands for. Length alone did not carry
                // it, a short plate at full height is just a fat nub.
                y: slotItem.isOccupied ? -root.tabPad : (parent.height - root.slot / 2) / 2
                width: root.reach(slotItem.isOccupied)
                height: slotItem.isOccupied ? parent.height + root.tabPad * 2 : root.slot / 2

                topLeftRadius: 0
                bottomLeftRadius: 0
                topRightRadius: tab.topRightRadius
                bottomRightRadius: tab.bottomRightRadius

                color: root.hovered === slotItem.index ? Appearance.colour.fillStrong : Appearance.colour.fill
                opacity: slotItem.isActive ? 0 : 1

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hovered = slotItem.index
                onExited: if (root.hovered === slotItem.index)
                    root.hovered = -1
                onClicked: Hypr.switchTo(slotItem.info.id)
            }

            // One row per window, centred in the bar with everything else in it.
            // The rows are centred in the slot as a group: a slot is `root.slot`
            // tall plus a pitch per extra row, so the group's inset is the same
            // whatever it holds.
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

                    x: (root.width - root.slot) / 2
                    y: (root.slot - root.pitch) / 2 + index * root.pitch
                    width: root.slot
                    height: root.pitch

                    Icon {
                        anchors.centerIn: parent
                        name: Apps.iconFor(Hypr.classOf(row.modelData))

                        // The focused window is the only thing in the column at
                        // full label weight. That is the whole hierarchy: the
                        // tab says which workspace you are on, this says which
                        // window you are in.
                        color: row.focused || winMouse.containsMouse ? Appearance.colour.text : Appearance.colour.textDim

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.fast
                            }
                        }
                    }

                    // Clicking a window goes to THAT window, not merely to its
                    // workspace. Hyprland's focuswindow brings the workspace
                    // along with it, so this is strictly more than the slot's own
                    // click does.
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
                x: (root.width - root.slot) / 2
                y: (root.slot - root.pitch) / 2 + slotItem.info.windows.length * root.pitch
                width: root.slot
                height: root.pitch
                name: "more_horiz"
                color: Appearance.colour.textFaint
            }
        }
    }
}
