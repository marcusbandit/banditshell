import QtQuick
import qs.config

// A one-step button: move this thing one place that way.
//
// Expander's shape and sizing with a different glyph on it and no state of its
// own. A round target against a row's rounded rectangle, taking the hover off
// the row so the boundary between "this row" and "this button" is visible
// before you commit to either.
//
// DEAD AT THE ENDS RATHER THAN INERT, and still in place. The first item's "up"
// and the last item's "down" have nowhere to go; a control that looks pressable
// and does nothing is the interface telling a lie it could just as easily not
// tell. Hiding them instead would shorten those rows' trailing slots and bend
// the columns of buttons out of line, so they stay put and go ghost, and the
// shape of a list is readable from its ends being out.
//
// Item's own `enabled` does the work rather than a property of its own:
// disabling the button disables the MouseArea and the tooltip handler inside it
// in one move, because that is what `enabled` already means.
//
// A FILE RATHER THAN AN INLINE COMPONENT, which is not a style preference. As
// `component Nudge: Item` inside a page, every instance warned "QML G2Rect:
// Cannot find member data" against `<Unknown File>`: a `Behavior on opacity`
// declared inside a type whose default property is an alias (G2Rect routes its
// children to `inner.data`) is not routed correctly from inside an inline
// component. Expander does the identical thing from its own file and is
// silent, which is the whole difference.
Item {
    id: root

    property string glyph: ""
    property string tip: ""

    signal nudged

    readonly property bool hovered: pointer.containsMouse

    // From the glyph and the shell's smallest gap, floored at the minimum
    // target, which is Expander's sizing said again for the same reason: a 16px
    // chevron is a bad thing to ask a hand to hit.
    implicitWidth: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)
    implicitHeight: implicitWidth

    // At radius = half the side the corner budget is fully spent and the
    // squircle reads as a disc, which is the point: a different SHAPE from the
    // row it sits in, not just a smaller rectangle.
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

        name: root.glyph
        color: !root.enabled ? Appearance.colour.textGhost : root.hovered ? Appearance.colour.text : Appearance.colour.textFaint

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.nudged()
    }

    // Asked through the MouseArea above, which fills this item and therefore
    // takes the hover before any handler under it hears a thing. See HoverTip.
    HoverTip {
        text: root.tip
        asked: pointer.containsMouse
    }
}
