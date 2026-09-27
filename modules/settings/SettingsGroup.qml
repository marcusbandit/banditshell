pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// One group of a settings page: the tracked-caps heading that owns it, and
// the blocks under it.
//
// THE SPACING IS THE LAW OF PROXIMITY'S ASYMMETRY RULE, stated quantitatively
// in docs/research/proximity-grouping.md: a heading belongs to whatever sits
// CLOSER to it. The page's own spacing (the huge tier) is the break above this
// group; inside it the heading rides one small tier off its first child, a 4:1
// difference, so the heading can only ever be read as owning what follows.
//
// THE CAPS ARE AN IDIOM CHOICE, not a default: GNOME and Fluent both
// discourage all-caps UI text, and the sources allow exactly two group-header
// forms - a small tracked-caps overline (Material's, with Butterick's 5-12%
// added tracking) or a same-size full-alpha heading. This shell is a
// terminal's child, so the overline it is; the tracking is one font stem,
// which at the body tier is 2px or about 0.11em, on the pixel grid. Recorded
// in DESIGN.md.
//
// The heading wears the same faint tier as the secondary text under it - the
// one hierarchy rule the typography research makes absolute: a header must
// never be dimmer than the dimmest text in its own group. Equal is legal.
Column {
    id: root

    property string heading: ""
    default property alias body: bodyCol.data

    width: parent ? parent.width : 0
    spacing: Appearance.padding.small

    StyledText {
        visible: !!root.heading
        width: parent.width
        text: root.heading.toUpperCase()
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        font.letterSpacing: Appearance.font.stem
        leftPadding: Appearance.padding.small
    }

    Column {
        id: bodyCol

        width: parent.width
        spacing: Appearance.padding.normal
    }
}
