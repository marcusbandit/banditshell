import QtQuick
import qs.config

// The chevron that unrolls a layer, as a TARGET OF ITS OWN.
//
// It used to be a bare glyph with a MouseArea stretched over it, sitting inside
// a row that does something else entirely. On a network row the body joins or
// leaves the network and the chevron opens the details: two controls, two
// outcomes, and between them one hover fill that lit the whole row for both. So
// the row read as a single button with a decoration on it, and the decoration
// turned out to be a second button, which you found out by pressing it.
//
// Two things that do two different things get two hover states. The MouseArea
// here takes the hover, and Qt hands hover to the topmost taker only, which is
// what puts the row's own fill OUT while the cursor is on this. That is the
// signal: the row stops being lit and this lights instead, so the boundary
// between the two controls is visible before you commit to either.
//
// A ROUND target against the row's rounded rectangle, so the two are different
// shapes and not just different rectangles. Both are squircles; at radius =
// half the side the corner budget is fully spent and this reads as a disc.
Item {
    id: root

    property bool open: false

    // What it says on hover. There is no label anywhere near a chevron, so this
    // is the only chance it gets to explain itself.
    property string tip: ""

    signal toggled

    readonly property bool hovered: pointer.containsMouse

    // From the glyph and the shell's smallest gap, floored at the minimum
    // target: the old version grew its hit area with a negative margin of
    // exactly one small padding, which is the same number, said once.
    implicitWidth: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)
    implicitHeight: implicitWidth

    G2Rect {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colour.fill

        opacity: root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    Icon {
        anchors.centerIn: parent

        name: "expand_more"
        color: root.open || root.hovered ? Appearance.colour.text : Appearance.colour.textFaint
        rotation: root.open ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    HoverTip {
        text: root.tip
    }
}
