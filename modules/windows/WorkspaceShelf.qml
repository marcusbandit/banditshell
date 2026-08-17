pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// WHERE A LIFTED WINDOW CAN BE PUT DOWN: one plate per workspace, across the
// middle of the screen, out only while a finger is holding a window over them.
//
// It is a DROP TARGET and not a menu, which is the whole of why it looks the way
// it does. Nothing here is pressed: the finger is already down and already
// carrying something when the shelf arrives, so there are no buttons, no hover
// states and no way in or out except by letting go. What a plate owes you is an
// answer to "is this the one I am over", and it says that by growing.
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

    // The content area, which is what this centres in. The shelf is a thing you
    // aim at with the hand already holding a window, so it goes where the eye
    // already is rather than hanging off an edge.
    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    // The screen's own proportions, so a plate is a small screen.
    required property real aspect

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
    readonly property var slots: {
        const out = [];
        for (let i = 1; i <= Hypr.count; i++)
            out.push({
                target: i,
                label: `${i}`,
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
    readonly property real rowY: root.holeY + (root.holeHeight - root.plateH) / 2

    function plateX(i: int): real {
        return root.rowX + i * root.pitch;
    }

    // WHICH PLATE THE FINGER IS OVER, or -1 for none.
    //
    // Nearest by PITCH rather than a containment test, so the seams between
    // plates are not dead ground: a finger that lands in a gap is aiming at one
    // of the two plates beside it, not at the background, and a drop that does
    // nothing because it fell between two targets is the worst answer available.
    // Outside the row entirely is still nothing, because releasing away from the
    // shelf is how you change your mind.
    //
    // The vertical catch is a plate's height either side of the row, which makes
    // the band three plates tall. A hand carrying something is aimed loosely,
    // and there is nothing else on this screen to hit by accident.
    readonly property int over: {
        if (!root.active)
            return -1;

        if (root.pointY < root.rowY - root.plateH || root.pointY > root.rowY + root.plateH * 2)
            return -1;
        if (root.pointX < root.rowX - root.gap || root.pointX > root.rowX + root.rowW + root.gap)
            return -1;

        return Math.max(0, Math.min(root.count - 1, Math.floor((root.pointX - root.rowX) / root.pitch)));
    }

    // The shelf RISES into place rather than appearing, and the same value fades
    // it, so one number is the whole arrival.
    Follow {
        id: reveal

        target: root.active ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    visible: reveal.value > 0.01
    opacity: reveal.value

    Repeater {
        model: root.slots

        delegate: Item {
            id: plate

            required property int index
            required property var modelData

            // Whether this is where you already are. A plate is a place, and the
            // one you are standing on is worth saying so that dropping a window
            // back where it came from reads as the no-op it is.
            readonly property bool here: plate.modelData.target === Hypr.activeId
            readonly property bool aimed: root.over === plate.index

            // What is on that workspace already, as marks. Empty for the "new
            // one" plate by construction: nothing is on a workspace that has not
            // been used yet.
            readonly property var windows: typeof plate.modelData.target === "number" ? Hypr.clientsIn(plate.modelData.target).slice(0, Appearance.sizes.wsMaxWindows) : []

            x: root.plateX(plate.index)
            // Up into place: a fifth of a plate of travel, which is enough to
            // read as arriving and not enough to be a journey.
            y: root.rowY + (1 - reveal.value) * root.plateH * 0.2
            width: root.plateW
            height: root.plateH

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
                    spacing: Appearance.padding.small / 2

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
