pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Vertical workspace indicators, drawn as what is ON them.
//
// A workspace is not a number, it is the windows you left there, so each slot
// stacks one glyph per window (see Apps.iconFor: the mark comes from the
// desktop entry's freedesktop categories, so an app this shell has never seen
// still gets the right one). An empty workspace is a hollow dot. Nothing here
// is labelled 1..N any more: the column IS the order, and the icons say more
// than the ordinal did.
//
// Every position comes from one pass down the column (see
// ~/.claude/rules/math-over-hardcoding.md). A slot is as tall as the windows it
// holds, so where slot i sits depends on what slots above it are holding;
// nothing knows its own y, and adding a workspace or a window changes only the
// data the pass runs over.
Item {
    id: root

    readonly property int count: Hypr.count
    readonly property int slot: Appearance.sizes.wsSlot
    readonly property int gap: Appearance.sizes.wsGap
    readonly property int pitch: Appearance.sizes.wsWindowPitch
    readonly property int maxWindows: Appearance.sizes.wsMaxWindows

    // The whole layout: { id, y, h, windows, rest } per slot.
    readonly property var slots: {
        const out = [];
        let y = 0;
        for (let i = 0; i < root.count; i++) {
            const id = i + 1;
            const clients = Hypr.clientsIn(id);
            // The overflow mark is a ROW like any other, so a workspace with
            // twenty windows on it is exactly as tall as one at the cap and
            // the column can never run off the screen.
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

    readonly property var activeSlot: root.slots[Hypr.activeId - 1]
    readonly property real total: root.slots.length ? root.slots[root.slots.length - 1].y + root.slots[root.slots.length - 1].h : 0

    implicitWidth: slot
    // Follows rather than jumps, because the sidebar CENTRES this: a window
    // opening changes the column's height, and an instant change would shunt
    // every slot half a row while the slots themselves were still gliding.
    // Same rate as everything else here, so the whole group moves as one.
    implicitHeight: grow.value

    Follow {
        id: grow
        target: root.total
    }

    Component.onCompleted: {
        grow.snap();
        slideY.snap();
        slideH.snap();
    }

    // A quiet container, so the indicators read as one control rather than a
    // column of loose marks. No bevel, no channel: just a fill a shade above
    // the panel, which is all "these belong together" needs.
    G2Rect {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
    }

    // The "you are here" marker. Drawn before the icons so they sit on top of
    // it, and it slides and grows between slots rather than jumping, so
    // switching workspaces reads as one thing moving.
    Follow {
        id: slideY
        target: root.activeSlot?.y ?? 0
    }

    Follow {
        id: slideH
        target: root.activeSlot?.h ?? root.slot
    }

    G2Rect {
        y: slideY.value
        width: root.slot
        height: slideH.value
        radius: Appearance.rounding.normal
        color: Appearance.colour.fillStronger
    }

    Repeater {
        // Modelled by the COUNT, not by `slots`: a Repeater over a JS array
        // rebuilds every delegate whenever the array is reassigned, and this
        // one is reassigned on every window event. Keyed by an int, the slots
        // persist and their Follows survive to animate the reflow.
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
            readonly property bool isActive: Hypr.activeId === info.id

            // Same smoothing as the active marker, from the same starting
            // point, so a slot and the marker sitting on it move as one shape
            // rather than as two things that happen to end up in the same
            // place.
            y: rowY.value
            width: root.slot
            height: rowH.value

            Follow {
                id: rowY
                target: slotItem.info.y
            }

            Follow {
                id: rowH
                target: slotItem.info.h
            }

            Component.onCompleted: {
                rowY.snap();
                rowH.snap();
            }

            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                // A step above the group's own container fill, or hovering
                // inside the container would not read as anything.
                color: Appearance.colour.fillStrong
                opacity: mouse.containsMouse && !slotItem.isActive ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.switchTo(slotItem.info.id)
            }

            // One row per window. The rows are centred in the slot as a group:
            // a slot is `root.slot` tall plus a pitch per extra row, so the
            // group's inset is the same whatever it holds.
            Repeater {
                // A ScriptModel, NOT the array: the array is rebuilt on every
                // Hyprland event, and a plain-array Repeater would tear down
                // and rebuild every icon each time. This diffs it, so a window
                // opening touches only its own row.
                model: ScriptModel {
                    values: slotItem.info.windows
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool focused: Hypr.activeClient === modelData

                    y: (root.slot - root.pitch) / 2 + index * root.pitch
                    width: root.slot
                    height: root.pitch

                    Icon {
                        anchors.centerIn: parent
                        name: Apps.iconFor(Hypr.classOf(row.modelData))

                        // The focused window is the only thing in the column
                        // at full label weight. That is the whole hierarchy:
                        // the fill says which workspace you are on, this says
                        // which window you are in.
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
                        onClicked: Hypr.focusClient(row.modelData)
                    }
                }
            }

            // "and more". Sits in the row after the last icon, so an
            // overflowing workspace is capped rather than truncated silently.
            Icon {
                visible: slotItem.info.rest > 0
                x: 0
                y: (root.slot - root.pitch) / 2 + slotItem.info.windows.length * root.pitch
                width: root.slot
                height: root.pitch
                name: "more_horiz"
                color: Appearance.colour.textFaint
            }

            // An empty workspace: a hollow dot, at half icon size so it reads
            // as a marker rather than as a glyph that failed to load.
            Icon {
                visible: slotItem.info.windows.length === 0
                anchors.centerIn: parent
                name: "circle"
                font.pixelSize: Math.round(Appearance.font.iconSize / 2)
                color: Appearance.colour.textFaint
            }
        }
    }
}
