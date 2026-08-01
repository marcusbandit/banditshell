import QtQuick
import qs.config

// An engraved line, used to separate sections of a panel.
//
// Two hairlines, not one: a dark score with a lit lower lip. That pair is what
// reads as "cut into the metal" rather than "line drawn on top of it", and it
// costs the same as a divider that reads as neither.
Item {
    id: root

    // Flip the lighting for a groove on a surface lit from below.
    property bool inverted: false

    implicitHeight: 2

    Rectangle {
        width: parent.width
        height: 1
        color: root.inverted ? Appearance.colour.engraveLight : Appearance.colour.engraveDark
    }

    Rectangle {
        y: 1
        width: parent.width
        height: 1
        color: root.inverted ? Appearance.colour.engraveDark : Appearance.colour.engraveLight
    }
}
