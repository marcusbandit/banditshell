pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// WHERE A LIFTED WINDOW CAN BE SENT: one plate per workspace, across the TOP of
// the screen, out while a finger is holding a window and reached by carrying it
// up there.
//
// AT THE TOP, AND NOT IN THE MIDDLE, because the middle is spoken for. Lifting a
// window turns the workspace you are on into a map of places to put it (see
// LayoutSlots), and that map is centred in the content area. Leaving is a
// different KIND of answer from rearranging, so it gets a different part of the
// screen rather than another plate in the same row: down among the windows means
// "here, differently", up past them means "not here at all".
//
// IT ARRIVES IN TWO STAGES. Docked, it is a small dim row that says the top of
// the screen does something. Reached for, it grows to full size, brightens, and
// starts answering: `armed` is the whole difference, and it is a band around the
// row rather than a line, so the plates are alive slightly before the finger is
// on them. Without the docked stage the workspaces would be invisible until
// somebody guessed they were there.
//
// A plate is the SHAPE OF THE SCREEN, not a square and not a row: the thing
// being aimed at is a place windows live, and drawn at the screen's own aspect a
// column of marks inside it reads as a small picture of that workspace rather
// than as a list item.
//
// THE COUNT DECIDES THE LAYOUT, never the other way round. The persistent set is
// whatever `sidebar.workspaces.persistent` says, plus one for a workspace that
// does not exist yet, and every position is that count times a pitch. Nothing in
// here knows the number five (see ~/.claude/rules/math-over-hardcoding.md).
Item {
    id: root

    // The content area, which the row hangs from the top of. The shelf is aimed
    // at with a hand already carrying a window, so it sits inside the space
    // windows live in rather than over the band.
    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    // The screen's own proportions, so a plate is a small screen.
    required property real aspect

    // WHICH SCREEN THIS SHELF IS HUNG ON, by output name, because the places a
    // window can go are that screen's own band and not the desktop's whole
    // supply of numbers. Carrying a window up on the second monitor offers 6-10
    // and not 1-5, which is the same rule the sidebar's column follows and for
    // the same reason: a workspace belongs to a screen (services/Hypr.qml,
    // bandFor).
    //
    // DEFAULTED rather than required, and to the focused screen, which is the
    // answer this file gave implicitly before bands existed. The shelf is also
    // stood up outside a shell window by the dev harness, where there is no
    // surface to ask and the focused screen is exactly what it means.
    property string screen: Hypr.focusedScreen

    // The first workspace of that screen's run, and where the screen currently
    // is within it. Read from Hypr once each rather than in the delegate, so
    // the row and anything asking the row about itself (WindowEdge's drop)
    // agree by construction.
    readonly property int band: Hypr.bandFor(root.screen)
    // activeId, not `active`: the bool below already owns that name and means
    // something else entirely (whether the shelf is out at all). This is the
    // per-screen spelling of Hypr.activeId, so it wears that name.
    readonly property int activeId: Hypr.activeOn(root.screen)

    // Where the finger is, in the surface's coordinates, and whether the shelf
    // is out at all.
    property real pointX: 0
    property real pointY: 0
    property bool active: false

    // THE PLACES A WINDOW CAN GO.
    //
    // The numbered set the sidebar draws, and then one more. "empty" is the
    // compositor's own selector for the first workspace with nothing on it,
    // which is the honest spelling of "a new one": Hyprland does not create
    // workspaces, it numbers them, so a new workspace is an unused number.
    //
    // THE SET THE SIDEBAR ON THIS SCREEN DRAWS, which is `count` places
    // starting at the band rather than `count` places starting at one. The
    // plates are labelled with the id they send to, because that id is what the
    // rest of the desktop calls the place, and a shelf that numbered its own
    // slots 1..5 on every monitor would be offering two different workspaces
    // under the same label.
    readonly property var slots: {
        const out = [];
        for (let i = 0; i < Hypr.count; i++)
            out.push({
                target: root.band + i,
                label: `${root.band + i}`,
                glyph: ""
            });
        out.push({
            target: "empty",
            label: "",
            glyph: "add"
        });
        return out;
    }

    readonly property int count: root.slots.length

    // LAYOUT KNOBS: a gap, and how much of the content area the whole row is
    // allowed to spend.
    readonly property real gap: Appearance.padding.normal
    readonly property real span: root.holeWidth * 0.8

    // A plate is its preferred width, or whatever is left over once the row has
    // been divided by the count, whichever is smaller. That is what keeps a long
    // persistent set on the screen instead of running off it.
    readonly property real plateW: Math.min(root.holeWidth * Appearance.sizes.windowPlate, (root.span - (root.count - 1) * root.gap) / root.count)
    readonly property real plateH: root.plateW * root.aspect

    readonly property real pitch: root.plateW + root.gap
    readonly property real rowW: root.count * root.pitch - root.gap
    readonly property real rowX: root.holeX + (root.holeWidth - root.rowW) / 2
    readonly property real rowY: root.holeY + root.gap

    // HOW MUCH OF THE TOP THE SHELF OWNS while it is merely docked, for
    // whatever is drawn underneath to keep clear of. Published rather than
    // recomputed out there, so the map does not have to know how a plate is
    // built in order to stay out of its way.
    readonly property real dockedHeight: root.gap * 2 + root.plateH * root.docked

    // HOW BIG THE ROW ACTUALLY IS, which is not how big it was laid out. Docked
    // it is drawn small; reached for it grows to full size about its own top
    // edge, so it stays hung from the top of the screen while it opens.
    //
    // The hit test below reads THIS and not the layout, because a plate you can
    // see and a plate you can hit have to be the same rectangle, including
    // during the growth.
    readonly property real docked: 0.72
    readonly property real rowScale: root.docked + (1 - root.docked) * arm.value

    // HOW MANY MARKS A PLATE CAN HOLD, which is arithmetic and not a setting: a
    // plate is this wide, a mark is this wide, and the row of them is centred in
    // it. This used to read the sidebar's `maxWindows`, which was a cap on how
    // many windows the SIDEBAR drew and is gone with it; borrowing it here was
    // always a number from another drawing that happened to look right.
    readonly property int marksFit: Math.max(1, Math.floor((root.scaledW - root.markGap) / (Appearance.sizes.wsIcon + root.markGap)))
    readonly property real markGap: Math.round(Appearance.padding.small / 2)

    readonly property real scaledPitch: root.pitch * root.rowScale
    readonly property real scaledW: root.plateW * root.rowScale
    readonly property real scaledH: root.plateH * root.rowScale
    readonly property real scaledRowW: root.rowW * root.rowScale
    readonly property real scaledRowX: root.rowX + (root.rowW - root.scaledRowW) / 2

    function plateCentre(i: int): point {
        return Qt.point(root.scaledRowX + i * root.scaledPitch + root.scaledW / 2, root.rowY + root.scaledH / 2);
    }

    // HAS THE HAND COME UP HERE. A band rather than a line, and generous below
    // the plates: a hand carrying something is aimed loosely, and the whole
    // instruction is "go to the top", not "hit this row".
    //
    // This is also what takes the aim AWAY from the layout underneath, so the
    // two answers can never both be live: whoever owns the finger owns it alone.
    readonly property bool armed: root.active && root.pointY < root.rowY + root.scaledH * 2

    // WHICH PLATE THE FINGER IS OVER, or -1 for none.
    //
    // Nearest by PITCH rather than a containment test, so the seams between
    // plates are not dead ground: a finger that lands in a gap is aiming at one
    // of the two plates beside it, not at the background, and a drop that does
    // nothing because it fell between two targets is the worst answer available.
    // Past either end of the row by more than half a plate there is no aim at
    // all, which is what leaves the top corners meaning "I have changed my mind".
    readonly property int over: {
        if (!root.armed)
            return -1;

        if (root.pointX < root.scaledRowX - root.scaledW / 2 || root.pointX > root.scaledRowX + root.scaledRowW + root.scaledW / 2)
            return -1;

        return Math.max(0, Math.min(root.count - 1, Math.floor((root.pointX - root.scaledRowX) / root.scaledPitch)));
    }

    // The shelf DROPS into place rather than appearing, and the same value fades
    // it, so one number is the whole arrival.
    Follow {
        id: reveal

        target: root.active ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // ...and a second one for the reach, which is a different motion for a
    // different reason and must not share the first's clock.
    Follow {
        id: arm

        target: root.armed ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    visible: reveal.value > 0.01
    // Docked, it is present rather than proposed: enough to be seen and not
    // enough to compete with the layout it is hanging over.
    opacity: reveal.value * (0.55 + 0.45 * arm.value)

    Repeater {
        model: root.slots

        delegate: Item {
            id: plate

            required property int index
            required property var modelData

            // Whether this is where you already are. A plate is a place, and the
            // one you are standing on is worth saying so that dropping a window
            // back where it came from reads as the no-op it is.
            readonly property bool here: plate.modelData.target === root.activeId
            readonly property bool aimed: root.over === plate.index

            // What is on that workspace already, as marks. Empty for the "new
            // one" plate by construction: nothing is on a workspace that has not
            // been used yet.
            readonly property var windows: typeof plate.modelData.target === "number" ? Hypr.clientsIn(plate.modelData.target).slice(0, root.marksFit) : []

            readonly property point centre: root.plateCentre(plate.index)

            x: plate.centre.x - width / 2
            // Up out of the top edge while it arrives, so the row is seen coming
            // down from the edge it belongs to.
            y: plate.centre.y - height / 2 - (1 - reveal.value) * root.plateH * 0.3
            width: root.scaledW
            height: root.scaledH

            // THE ONLY FEEDBACK A DROP TARGET OWES YOU. It grows under the
            // finger, which is the one signal that survives having a hand over
            // the plate you are asking about.
            scale: plate.aimed ? 1.08 : 1

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.fast
                    easing.type: Easing.OutCubic
                }
            }

            G2Rect {
                anchors.fill: parent

                radius: Appearance.rounding.normal
                color: plate.aimed ? Appearance.colour.fillStrong : Appearance.colour.fill
                // Where you are, as a ring rather than a fill: the fill is
                // spoken for by the aim, and the two facts are independent.
                stroke: plate.here ? Appearance.colour.accent : "transparent"
                strokeWidth: Appearance.font.stem

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: Appearance.padding.small

                // The number, or the mark for the workspace that does not exist
                // yet. Only one of the two is ever drawn.
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !!plate.modelData.label

                    text: plate.modelData.label
                    font.pixelSize: Appearance.font.size.normal
                    color: plate.here ? Appearance.colour.accent : plate.aimed ? Appearance.colour.text : Appearance.colour.textDim
                }

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !!plate.modelData.glyph

                    name: plate.modelData.glyph
                    size: Appearance.font.iconSize
                    color: plate.aimed ? Appearance.colour.text : Appearance.colour.textDim
                }

                // WHAT IS ALREADY THERE. The plate is a picture of a workspace,
                // and this is the whole of what it can honestly show without a
                // screenshot: which applications are living on it.
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.markGap

                    Repeater {
                        model: plate.windows

                        delegate: AppMark {
                            required property var modelData

                            spec: AppIcons.markFor(Hypr.classOf(modelData))
                            size: Appearance.sizes.wsIcon
                            color: Appearance.colour.textDim
                        }
                    }
                }
            }
        }
    }
}
