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
// It arrives SOFTLY, which is the whole brief: it fades rather than appears, and
// when it moves from one thing to the next it travels rather than teleports, so
// a column of icons reads as one label being carried down it. Both are the same
// exponential smoothing everything else in this shell moves by.
Item {
    id: root

    readonly property Item anchor: Tooltips.anchor
    readonly property bool shown: Tooltips.shown

    // Where the anchor IS, in this item's coordinates. Recomputed when the
    // anchor changes, which is when it matters: the things that ask are icons in
    // a band and rows in a settled panel, none of which move underneath a
    // cursor that has been still long enough to have asked.
    readonly property rect box: root.anchor ? root.mapFromItem(root.anchor, 0, 0, root.anchor.width, root.anchor.height) : Qt.rect(0, 0, 0, 0)

    readonly property real gap: Appearance.padding.normal
    readonly property real inset: Appearance.sizes.border

    // Beside it, on the side there is room for. The band is on the left and the
    // panels open rightwards, so the right is nearly always the answer; the flip
    // is for whatever ends up near the far edge.
    readonly property real wantX: box.x + box.width + gap + pill.width > root.width - inset ? box.x - gap - pill.width : box.x + box.width + gap
    readonly property real wantY: Math.max(inset, Math.min(box.y + (box.height - pill.height) / 2, root.height - inset - pill.height))

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

    // Nothing to travel FROM on the first appearance, so it is placed rather
    // than flown in from wherever the last one was.
    onShownChanged: if (root.shown) {
        glideX.snap();
        glideY.snap();
    }

    G2Rect {
        id: pill

        x: glideX.value
        y: glideY.value
        width: label.implicitWidth + Appearance.padding.normal * 2
        height: label.implicitHeight + Appearance.padding.small * 2
        radius: Appearance.rounding.normal
        color: Appearance.colour.surface

        opacity: root.shown ? 1 : 0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            // Held while fading OUT, or the label would blank a frame before the
            // pill it is inside of.
            text: Tooltips.text || label.text
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.text
        }
    }
}
