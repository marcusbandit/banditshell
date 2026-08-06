pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// ONE KEY on the drawn board.
//
// It knows nothing about binds, modifiers or the layout: it is given a width in
// UNITS, a place to be, a label and a state, and it draws a keycap. Everything
// that decides which of those it gets is in KeyBoard, which is the only file
// that should ever have an opinion about what a key means.
//
// THREE STATES, and they are a ladder rather than a set of colours, because the
// board's whole job is that you can see the answer without reading it:
//
//   plain     nothing is bound to this key under the modifiers being held. The
//             faintest fill there is and the ghost label tier, so it reads as
//             part of the board's texture rather than as an offer. A board on
//             which everything looks alike teaches nothing, and this is the tier
//             that makes the other two mean something.
//   lit       something IS bound here. A selection-weight fill and the full
//             label tier: the same step the shell uses everywhere else to say
//             "this one".
//   latched   a modifier being held. The accent, as a FILL rather than as a
//             label, which is Appearance's own test for state worth a hue: what
//             you are holding is the one thing about the board you need to know
//             from the corner of your eye while looking somewhere else on it.
//
// A ring is a fourth thing on top of those rather than a fourth state, because
// "which key you asked about" is a different question from "is anything bound
// here" and a key can be both or neither.
Item {
    id: root

    // How wide, as a multiple of the board's unit. The pitch and the seam come
    // from the board, so a key never knows a pixel size of its own and the whole
    // board rescales from one number.
    property real units: 1
    property real pitch: 0
    property real seam: 0

    // THE ISO ENTER, and the only key on the board that is not a rectangle.
    //
    // Zero means an ordinary cap. Anything else is the width, in units, of the
    // LOWER LEG of a key that spans two rows: the enter's top spans 1.5 units of
    // the qwerty row and its foot 1.25 of the row below, right-aligned to the
    // same edge, so the notch is at the bottom left and the key reads as the
    // tall one rather than as the ANSI bar. That silhouette is the whole reason
    // the board is ISO at all.
    //
    // Drawn as TWO G2Rects that abut, with the radius taken off every corner
    // that is interior to the union. That is not a compromise: the pieces share
    // an edge exactly, so the union is a single L with G2 corners everywhere it
    // has a convex one and a sharp step where a real keycap has a sharp step.
    // The alternative was a bespoke L-shaped squircle path, which would be a
    // second rounded primitive in a shell whose rule is that there is exactly
    // one (~/.claude/rules/g2-corners.md).
    property real foot: 0

    // What it says. A `glyph` wins if there is one, because the symbol
    // vocabulary is drawn from another face; see Chord for why that cannot be
    // one string.
    property string label: ""
    property string glyph: ""

    property bool lit: false
    property bool latched: false
    property bool selected: false

    signal tapped

    // The top piece reaches down THROUGH the seam to meet the foot, so the two
    // rows of an ISO enter are one shape rather than two keys a hairline apart.
    // An ordinary cap stops a seam short of the next row, like everything else.
    readonly property real headHeight: root.foot > 0 ? root.pitch : root.pitch - root.seam

    readonly property real radius: Appearance.rounding.small

    readonly property color fill: root.latched ? Appearance.colour.accentFill : root.lit ? Appearance.colour.fillStronger : Appearance.colour.fill
    readonly property color ink: root.latched || root.lit ? Appearance.colour.text : Appearance.colour.textGhost

    width: root.units * root.pitch - root.seam
    height: (root.foot > 0 ? 2 * root.pitch : root.pitch) - root.seam

    // A change of state is a fade, not a jump. Nothing here MOVES when the
    // modifiers change, so the fill is the entire signal, and a whole board
    // changing fill in one frame reads as a flicker rather than as an answer.
    // The fast tier, because it is answering a press.
    G2Rect {
        id: head

        width: parent.width
        height: root.headHeight

        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: root.radius
        // The inside of the L. There is keycap below and to the right of this
        // corner, so rounding it would cut a notch out of the middle of one key.
        bottomRightRadius: root.foot > 0 ? 0 : root.radius

        color: root.fill
        stroke: root.selected ? Appearance.colour.accent : "transparent"
        // A rule beside this type weighs a stem, which is the pixel font's own
        // device pixel; see Appearance.font.stem.
        strokeWidth: root.selected ? Appearance.font.stem : 0

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        // THE LEGEND, in the top piece and not in the item. On a two-row key the
        // item is the whole L, whose middle is in the notch; a real ISO enter
        // carries its legend on the wide part and so does this, and anchoring to
        // the piece rather than to the key is what says so once instead of
        // branching on the shape.
        //
        // DECLARED BEFORE THE AREA that takes the press. Neither of these two
        // accepts a mouse button, so an area declared first would get the press
        // anyway, but that is a fact about Qt's defaults rather than something
        // this file states, and the day one of them grows a handler the key would
        // silently stop answering. Input order is declaration order; putting the
        // area last says the key is pressable everywhere and means it.
        StyledText {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            visible: !root.glyph

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            // The board's pitch is measured off these labels (see KeyBoard.
            // naturalPitch), so at the board's natural size nothing elides. This
            // is for the screen that could not give the board that much room,
            // where a cap must lose characters rather than run over its
            // neighbour.
            elide: Text.ElideRight

            text: root.label
            color: root.ink
        }

        Icon {
            anchors.centerIn: parent
            visible: !!root.glyph

            glyph: root.glyph
            size: Appearance.font.size.small
            color: root.ink
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tapped()
        }
    }

    G2Rect {
        id: leg

        x: parent.width - width
        y: root.pitch
        width: root.foot * root.pitch - root.seam
        height: root.pitch - root.seam
        visible: root.foot > 0

        // Both top corners are interior: the piece above covers the whole of
        // this one's top edge and reaches further left.
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius

        color: root.fill
        stroke: root.selected ? Appearance.colour.accent : "transparent"
        strokeWidth: root.selected ? Appearance.font.stem : 0

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        // ITS OWN, rather than one area over the whole item. The item's bounds
        // are the top piece's rectangle, and the quarter unit of it that hangs
        // below the notch is not part of this key at all: it sits over the right
        // end of the key to the enter's left, and a press there belongs to that
        // key. Two areas that each cover exactly a drawn piece cannot claim
        // anything the key does not occupy.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tapped()
        }
    }
}
