import QtQuick
import qs.config
import qs.components

// The one tooltip, drawn wherever the thing that asked for it happens to be.
//
// ONE, not one per widget: there is a single cursor, so a second tooltip could
// only ever be a leftover. It lives at the top of the shell's contents so it can
// be drawn over a menu, and it has no input of its own, so being on top costs
// nothing to anything underneath.
//
// It arrives SOFTLY, which is the whole brief: it grows rather than appears, and
// when it moves from one thing to the next it travels rather than teleports, so
// a column of icons reads as one label being carried down it.
//
// IT DIES WHERE IT STOOD. The position used to be computed from the anchor, and
// on release the anchor becomes null, so the box collapsed to (0,0,0,0) and the
// target with it: the label spent its whole fade flying to the top-left corner
// of the screen. Travelling is right between two things that both exist, and
// nonsense towards a thing that does not. So the box is only recomputed while
// there is something to point AT, and letting go leaves the last one standing.
//
// It is PART OF THE BODY rather than a card on top of it. The pill is not drawn
// here at all: it is handed to the chassis as one more shape in the shell's
// distance field, so where it pokes out past the panel that asked for it, the
// two melt together instead of one sitting on the other. It takes a much
// narrower melt than a panel does, because it is a much smaller thing; see
// blob.frag.
Item {
    id: root

    readonly property Item anchor: Tooltips.anchor
    readonly property bool shown: Tooltips.shown

    // Where the anchor IS, in this item's coordinates, HELD once taken.
    //
    // Recomputed when the anchor changes, which is when it matters: the things
    // that ask are icons in a band and rows in a settled panel, none of which
    // move underneath a cursor that has been still long enough to have asked.
    property rect box: Qt.rect(0, 0, 0, 0)

    onAnchorChanged: if (root.anchor)
        root.box = root.mapFromItem(root.anchor, 0, 0, root.anchor.width, root.anchor.height)

    readonly property real gap: Appearance.padding.normal
    readonly property real inset: Appearance.sizes.border

    // FULL SIZE, whatever the growth is doing. The placement has to be decided
    // against the size the pill is going to BE, or the target would move under
    // the glide for the whole of the animation and the label would swim into
    // place instead of growing into it.
    readonly property real fullWidth: label.implicitWidth + Appearance.padding.normal * 2
    readonly property real fullHeight: label.implicitHeight + Appearance.padding.small * 2

    // Beside it, on the side there is room for. The band is on the left and the
    // panels open rightwards, so the right is nearly always the answer; the flip
    // is for whatever ends up near the far edge.
    readonly property real wantX: box.x + box.width + gap + fullWidth > root.width - inset ? box.x - gap - fullWidth : box.x + box.width + gap
    readonly property real wantY: Math.max(inset, Math.min(box.y + (box.height - fullHeight) / 2, root.height - inset - fullHeight))

    Follow {
        id: glideX

        target: root.wantX
        speed: Appearance.anim.trackSpeed
    }

    Follow {
        id: glideY

        target: root.wantY
        speed: Appearance.anim.trackSpeed
    }

    // 0 to 1, and the only thing that says whether it is here. It grows from
    // nothing at the centre of where it is going to be and shrinks back into
    // nothing exactly where it stood.
    Follow {
        id: grow

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.001
    }

    // Nothing to travel FROM on the first appearance, so it is placed rather
    // than flown in from wherever the last one was.
    onShownChanged: if (root.shown) {
        glideX.snap();
        glideY.snap();
    }

    // What the chassis needs to melt this into the shell's body. Nothing at all
    // while it is away: a zero width is the field's own way of skipping a slot,
    // so a tooltip that is not showing costs the shader nothing.
    readonly property var blobs: pill.width < 1 ? [] : [
        {
            x: pill.x,
            y: pill.y,
            w: pill.width,
            h: pill.height,
            radius: Math.min(Appearance.rounding.normal, pill.height / 2),
            // A THIRD of a panel's. Wide enough that the joint is a fillet and
            // not a crease, narrow enough that a pill roughly its own height
            // stays a pill.
            smooth: Appearance.sizes.melt / 3
        }
    ]

    // GEOMETRY ONLY. The shape is the chassis's to draw; this is where it is.
    Item {
        id: pill

        width: root.fullWidth * grow.value
        height: root.fullHeight * grow.value

        // Grown about its own centre, so it swells out of a point rather than
        // unrolling from a corner.
        x: glideX.value + (root.fullWidth - width) / 2
        y: glideY.value + (root.fullHeight - height) / 2

        StyledText {
            id: label

            anchors.centerIn: parent

            // Held while shrinking, or the label would blank a frame before the
            // shape it is inside of.
            text: Tooltips.text || label.text
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.text

            // The text rides the growth rather than being scaled by it: a glyph
            // at a fraction of its size is a smear, and one that fades over the
            // back half of the same movement reads as arriving with the shape.
            opacity: Math.max(0, grow.value * 2 - 1)
        }
    }
}
