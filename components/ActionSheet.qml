pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// A ROW'S OTHER ANSWERS, in a small sheet under the pointer.
//
// Opened by a right click or a long press on a row, in any list that has more
// to offer than the one thing a click does. Actions are handed in as
// { icon, label, run }, so nothing here knows what a row IS: the clipboard
// hands it copy/keep/delete and the launcher hands it the desktop entry's own
// actions, and this file cannot tell them apart.
//
// THE POWER MENU'S LOOK AND ITS MOVEMENT, deliberately: one marker that SLIDES
// between the entries rather than a fill that switches on in a new row, hover
// and the keyboard writing the same `selected` rather than one each, and the
// marks fading between weights on the marker's own clock so a row brightens as
// the marker arrives under it. modules/session/SessionMenu.qml is where that is
// argued; this is the same construction with labels beside the glyphs.
//
// Layout:
//   - catcher   the click-anywhere-else that closes it (declared FIRST, so it
//               sits under the sheet: declaration order is input order)
//   - measure   the labels at their natural width, which is where the size comes from
//   - sheet     the card, clipped, unrolling out of the cursor
Item {
    id: root

    // ---- WHAT IT SHOWS -------------------------------------------------

    property var actions: []
    property bool open: false

    // WHICH ONE IS CHOSEN, for the pointer and the keyboard alike. One value,
    // not one per input: hovering and arrowing are the same question, and two
    // answers to it would light two rows the moment you touched the mouse.
    property int selected: 0

    // WHICH ONE IS WORN, and it is not `selected` for the same reason the
    // dropdowns needed it said twice: the marker follows the pointer, but the
    // option that IS the current answer keeps the fill and the bright label
    // and its circle drawn solid whether or not the cursor is somewhere else.
    // -1 is no worn row, which is every sheet the power menu opens.
    property int worn: -1

    // Where it was asked for, in this item's coordinates.
    property real atX: 0
    property real atY: 0

    signal closed

    // ---- OPENING AND CLOSING -------------------------------------------

    // `start` is which entry the marker opens ON -- the dropdowns seed it
    // with the option being worn so the sheet opens where the answer is.
    // Optional by contract rather than by syntax (QML has no default
    // parameter values): a caller that omits it hands an undefined over,
    // and undefined is clamped back to the top the way the old hard zero
    // was.
    function popup(x: real, y: real, list: var, start: int): void {
        root.actions = list ?? [];
        if (!root.actions.length)
            return;
        root.atX = x;
        root.atY = y;
        root.worn = start >= 0 ? start : -1;
        root.selected = Math.max(0, Math.min(root.actions.length - 1, start >= 0 ? start : 0));
        // WHERE IT LEFT OFF IS NOT A "FROM". The marker chases whatever is
        // chosen, so without this it would slide up from the last sheet's
        // choice while this one is still unrolling: two travels at once, and
        // neither of them readable.
        marker.snap();
        root.open = true;
    }

    function close(): void {
        if (!root.open)
            return;
        root.open = false;
        root.closed();
    }

    function choose(index: int): void {
        if (index >= 0 && index < root.actions.length)
            root.selected = index;
    }

    // Clamped rather than wrapped, like the power menu's: a list short enough to
    // see all of at once, where running off the end onto Delete is exactly the
    // press you make when you have stopped looking.
    function move(delta: int): void {
        root.choose(Math.max(0, Math.min(root.actions.length - 1, root.selected + delta)));
    }

    // CLOSED BEFORE THE ACTION RUNS, because half of them (delete, and anything
    // that puts the panel away) destroy the row this sheet was opened over.
    function activate(index: int): void {
        const action = root.actions[index];
        root.close();
        if (action?.run)
            action.run();
    }

    // ---- THE GRID ------------------------------------------------------
    //
    // ONE STEP from one entry to the next, and every position in the sheet is
    // that times an index. Nothing here holds a list of where the rows are.

    // The gap inside the group and the gap around it are the same number, which
    // is what makes it read as a group rather than as a border.
    readonly property real gap: Appearance.padding.small
    readonly property real inset: Appearance.padding.normal

    readonly property real rowHeight: Math.max(Appearance.sizes.rowHeight, Appearance.font.iconSize + root.inset * 2)
    readonly property real step: root.rowHeight + root.gap

    // The mark, the label at its full length, and the three margins between and
    // around them. Capped by the panel the sheet opens in.
    readonly property real rowWidth: Math.min(root.width - root.edge * 2 - root.gap * 2, root.inset * 3 + Appearance.font.iconSize + measure.childrenRect.width)

    // A cell's corner, and the shell's derived from it rather than picked: a
    // shell inset by `gap` around a corner of radius r is concentric with it at
    // r + gap, and any other number visibly diverges in the corners, which is
    // the one place both curves are on screen at once.
    readonly property real cellRadius: Appearance.rounding.normal
    readonly property real groupRadius: root.cellRadius + root.gap

    // ---- WHERE IT LANDS ------------------------------------------------
    //
    // Full size, whatever the unroll is doing: the placement has to be decided
    // against the size the sheet is going to BE, or it would swim into position.

    readonly property real edge: Appearance.padding.normal
    readonly property real fullWidth: root.rowWidth + root.gap * 2
    readonly property real fullHeight: root.actions.length * root.step - root.gap + root.gap * 2

    // Onto whichever side of the cursor has room, then clamped inside the panel.
    readonly property bool flipX: root.atX + root.fullWidth > root.width - root.edge
    readonly property bool flipY: root.atY + root.fullHeight > root.height - root.edge
    readonly property real originX: Math.max(root.edge, Math.min(root.flipX ? root.atX - root.fullWidth : root.atX, root.width - root.edge - root.fullWidth))
    readonly property real originY: Math.max(root.edge, Math.min(root.flipY ? root.atY - root.fullHeight : root.atY, root.height - root.edge - root.fullHeight))

    Follow {
        id: unroll

        target: root.open ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.001
    }

    // WHERE THE MARKER IS, in the group's own coordinates, chasing where it
    // should be. Arithmetic off the chosen index rather than a delegate's
    // position, so it is right before the delegates exist.
    Follow {
        id: marker

        speed: Appearance.anim.trackSpeed
        target: root.selected * root.step
    }

    visible: unroll.value > 0.001

    // ESCAPE CLOSES THE SHEET FIRST, from the sheet itself: while it is open
    // it takes the focus, so the key aimed at "put the menu away" is answered
    // here before whatever panel underneath can spend it on closing more.
    // Closing hands the focus back through `closed`, which the panels that
    // care about such things already catch.
    onOpenChanged: if (root.open)
        root.forceActiveFocus()

    Keys.onEscapePressed: root.close()

    // ---- THE PARTS -----------------------------------------------------

    MouseArea {
        anchors.fill: parent
        enabled: root.open
        // Right as well as left: a second right click somewhere else is a
        // request to move the menu, and it has to close this one first.
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.close()
    }

    // THE LABELS, at their natural width, and free-standing on purpose: a label
    // measured INSIDE a row is measured against the width that row was given,
    // which is the width being computed here, and an eliding Text reports the
    // room it was allowed rather than the room it wants. The two chase each
    // other down to a couple of characters and an ellipsis.
    //
    // A Column's childrenRect is its widest child, and it notifies, which a walk
    // over `children` would not.
    Column {
        id: measure

        visible: false

        Repeater {
            model: root.actions

            StyledText {
                required property var modelData

                text: modelData.label
            }
        }
    }

    Item {
        id: sheet

        // THE WIDTH DOES NOT UNROLL. A sheet caught mid-growth is a sheet
        // with the panel showing through past its right edge, its own cells
        // hanging over card rows with nothing of itself behind them -- the
        // height reveal says "opening" all by itself, and the column's width
        // is a fact, not an entrance.
        width: root.fullWidth
        height: root.fullHeight * unroll.value

        // Out of the corner nearest the cursor, so it grows from the click
        // rather than sliding in from a corner of the panel.
        x: root.originX + (root.flipX ? root.fullWidth - width : 0)
        y: root.originY + (root.flipY ? root.fullHeight - height : 0)

        clip: true

        // THE GROUP. Solid, unlike the power menu's, and that is the one thing
        // about it that could not be copied: this floats over a list rather than
        // over its own panel, so a translucent shell would double the material
        // it is already sitting on (DESIGN.md 8) and let the rows underneath
        // read straight through the labels.
        G2Rect {
            anchors.fill: parent
            radius: root.groupRadius
            color: Appearance.colour.surfaceSolid
            stroke: Appearance.colour.separator
            strokeWidth: Appearance.font.stem
        }

        // THE MARKER, declared before the entries so it sits behind their marks:
        // it is the surface they are on, not a thing in front of them.
        //
        // ONE shape for all of them. The alternative is a fill on whichever row
        // is chosen, and it cannot travel: the old fill has to end somewhere and
        // the new one has to start somewhere, and no amount of fading between
        // the two is movement.
        G2Rect {
            x: root.gap
            y: root.gap + marker.value
            width: root.rowWidth
            height: root.rowHeight
            radius: root.cellRadius
            color: Appearance.colour.fillStronger
        }

        // Placed at the same inset the marker starts from rather than centred,
        // so the two are laid out by one number and cannot drift apart by a
        // rounding.
        Column {
            x: root.gap
            y: root.gap
            spacing: root.gap

            Repeater {
                model: root.actions

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property bool chosen: root.selected === cell.index
                    readonly property bool worn: root.worn === cell.index

                    width: root.rowWidth
                    height: root.rowHeight

                    Icon {
                        id: mark

                        // Faded rather than hidden when the disc wears: the
                        // disc is anchored to this item's centre, so the item
                        // must keep its geometry or the disc loses the slot.
                        opacity: cell.worn ? 0 : 1

                        x: root.inset
                        anchors.verticalCenter: parent.verticalCenter

                        name: cell.modelData.icon
                        size: Appearance.font.iconSize
                        color: cell.chosen ? Appearance.colour.text : Appearance.colour.textDim

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.normal
                            }
                        }
                    }

                    // THE WORN MARK, DRAWN BY THE SHELL BECAUSE THE SYMBOL
                    // FONT CANNOT BE TRUSTED WITH IT. "radio_button_unchecked"
                    // is a stroke circle and its FILL axis does not fill it --
                    // asking produced a ring at every size. And G2Rect could
                    // not draw it either: at half-side radius a squircle is
                    // still a squircle, and a squircle is not a circle. So the
                    // disc is a PLAIN RECTANGLE at half-side radius, which is
                    // the one thing in Qt that actually is a circle, wearing
                    // the accent: the only filled thing on the row.
                    Rectangle {
                        visible: cell.worn

                        // Centred on the ring's own slot, and SIZED TO THE
                        // RING: the glyph draws its circle the full width of
                        // its em, so the disc is that em wide -- the same
                        // outer diameter the hollow ones have, measured, not
                        // guessed. The column of marks reads as one column
                        // of circles where one of them is filled.
                        anchors.centerIn: mark

                        width: mark.width
                        height: width
                        radius: width / 2
                        color: Appearance.colour.accent
                    }

                    StyledText {
                        anchors.left: mark.right
                        anchors.leftMargin: root.inset
                        anchors.verticalCenter: parent.verticalCenter

                        text: cell.modelData.label
                        // Bright when it is the answer or under the marker,
                        // dim when it is neither, on the same clock the
                        // marker moves on.
                        color: cell.worn || cell.chosen ? Appearance.colour.text : Appearance.colour.textDim

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.normal
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: root.choose(cell.index)
                        onClicked: {
                            root.choose(cell.index);
                            root.activate(cell.index);
                        }
                    }
                }
            }
        }
    }
}
