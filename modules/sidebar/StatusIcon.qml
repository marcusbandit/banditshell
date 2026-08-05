import QtQuick
import qs.config
import qs.components

// One system indicator.
//
// It deliberately does not know what it indicates. A service binds `icon`,
// `active`, `alert` and `available`, and connects `activated` to whatever menu
// the thing opens. Until those services exist it renders its placeholder glyph
// and still reacts to the cursor, so wiring one up later is a few bindings
// rather than a rewrite.
Item {
    id: root

    property string icon
    property bool active: false     // the thing is on / connected
    property bool alert: false      // wants attention
    property bool available: true   // this machine has one at all

    // A DRAWN mark, instead of the glyph, for the indicators the icon font
    // cannot actually say. Signal strength and a charge level are meters, and a
    // font that has to name every state can only approximate one: it ran out of
    // wifi glyphs after four ragged steps and out of charging glyphs after six.
    //
    // Whatever is loaded here is handed the colour the glyph would have taken,
    // through a property it must call `colour`. That is the whole contract: a
    // mark lights up on hover and goes accent on alert without knowing why, and
    // this file still does not know what it is indicating.
    property Component mark: null

    signal activated

    readonly property bool hovered: mouse.containsMouse

    // Label tiers, not colours. Accent is kept for `alert` only, so a colour in
    // this bar always means something is wrong.
    readonly property color markColour: !root.available ? Appearance.colour.textFaint : root.alert ? Appearance.colour.accent : root.hovered || root.active ? Appearance.colour.text : Appearance.colour.textDim

    // AS BIG AS THE PICTURE, and no bigger, which is now a statement about what
    // it wants rather than what it gets. The group hands it the width of the
    // whole band (see StatusIcons), and this is what it falls back to when
    // nobody hands it anything.
    implicitWidth: drawing.width
    implicitHeight: drawing.height

    // THE DRAWING, AND ONLY THE DRAWING, at exactly the slot it has always been.
    //
    // The item around it is as wide as the band now, so that a press anywhere
    // across the bar lands on the gauge it is level with; the MouseArea below is
    // the whole of why. Nothing drawn may follow it out there. The hover fill
    // was anchored to the item, and at the band's width that stops being a
    // rounded 28px square and becomes a 62px stripe under the cursor, which is
    // most of what this sidebar looks like. Giving that one child a centred
    // square of its own would have fixed the fill and left the trap armed for
    // whatever is added next, so the picture is wrapped instead: everything in
    // here is laid out against the slot and cannot reach past it.
    Item {
        id: drawing

        anchors.centerIn: parent
        width: Appearance.sizes.statusSlot
        height: Appearance.sizes.statusSlot

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            // A step above the group's own container fill, or hovering inside the
            // container would not read as anything.
            color: Appearance.colour.fillStrong
            opacity: root.hovered ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Icon {
            anchors.centerIn: parent
            visible: !root.mark
            name: root.icon
            color: root.markColour

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Loader {
            anchors.centerIn: parent
            active: !!root.mark
            sourceComponent: root.mark

            // Bound after the fact rather than declared: a Component cannot be
            // handed properties at construction, and the mark is written where
            // someone knows what it means, which is not here.
            onLoaded: item.colour = Qt.binding(() => root.markColour)
        }
    }

    // THE HIT AREA IS NOT THE DRAWING, and this is the only place in the file
    // where the two are allowed to disagree.
    //
    // The drawn slot is 28px in a 62px band, in a column with a 4px gap, so a
    // gauge answered over a fifth of the room it sits in: four pixels between
    // one gauge and the next belonged to neither, and seventeen either side
    // belonged to nothing at all. Every one of them is visibly ON a control, and
    // a finger that landed there did nothing. Filling the item closes both
    // lanes, because the item is now as wide as the band the group was given and
    // the margins reach half the gap up and down: neighbours meet exactly (two
    // and two), nothing overlaps, and there is no line down the bar, across it
    // or between two icons, that answers to nobody.
    //
    // The margins are half the gap the Column was given rather than a number of
    // their own, so changing the spacing moves both at once and they cannot
    // drift apart. Sideways there is nothing to halve: the neighbour is the edge
    // of the screen on one side and the rest of the desktop on the other, so the
    // target simply takes the band it was handed.
    //
    // NOTHING MOVES. Every drawn part lives in `drawing`, a slot-sized square
    // centred in the item, so the gauge draws exactly where and at exactly the
    // size it did before; only the region that answers changes. A bigger slot
    // would have been the obvious alternative and it is the wrong one: the slot
    // is a visual measurement shared with the tray, and growing it to fix a
    // touch target would put a visible hover fill under every dead pixel.
    //
    // The margins reach outside the item, which is legal and load-bearing here:
    // neither this item nor the Column above it clips, and Qt hit-tests a child
    // whose parent does not clip on the child's own geometry.
    MouseArea {
        id: mouse

        anchors.fill: parent
        anchors.topMargin: -Appearance.sizes.statusGap / 2
        anchors.bottomMargin: -Appearance.sizes.statusGap / 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    // NO TOOLTIP HERE, deliberately. Hovering one of these opens its menu, and
    // the menu's first line is its name: a label floating over the panel that
    // already says the same word is the clutter tooltips are supposed to cure.
}
