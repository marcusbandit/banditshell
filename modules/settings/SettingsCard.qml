import QtQuick
import qs.config
import qs.components

// A group of settings rows in one box, with the group's name above it.
//
// The grouped-list idiom every phone's settings app uses, and the whole of
// what gives a page of switches a shape: a box says "these belong together"
// before a single word is read, and a name over the box says what they are.
// A page is a column of these and nothing else.
//
// The rows inside are SettingsRows, which take their corners from their
// place in this card's Column: the box and the highlight inside it are one
// shape seen twice, not a rounded rectangle wearing a smaller one.
Column {
    id: root

    property string title: ""

    default property alias rows: body.data

    width: parent ? parent.width : 0
    spacing: Appearance.padding.small

    StyledText {
        visible: !!root.title
        text: root.title
        color: Appearance.colour.textFaint
        leftPadding: Appearance.padding.small
    }

    G2Rect {
        width: parent.width
        height: body.implicitHeight
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill

        Column {
            id: body

            width: parent.width
        }
    }
}
