import QtQuick
import qs.config

// TWO RECTANGLES, WHICH IS THE WHOLE SENTENCE.
//
// "Fits this screen" is four words for a fact that has no words in it. A
// picture has a shape, a monitor has a shape, and the only honest way to say
// whether one suits the other is to draw both and let them be looked at: a
// squat bar inside a tall outline needs no reading at all, and it says HOW
// badly rather than merely that.
//
// The outline is the screen and the solid one is the picture, which is the
// right way round because the screen is the thing that does not change while
// you scrub the strip. What moves is the shape inside it.
//
// BOTH FIT THE SAME SQUARE, rather than sharing a height or a width. Sharing a
// height makes a 32:9 picture eleven times wider than a portrait one and the
// mark stops being a mark; sharing a width does the same thing standing up.
// Fitting each into one box means the mark is always the same size, always the
// same weight beside a line of type, and the only thing that varies is the one
// thing it is drawing.
Item {
    id: root

    // Width over height. 0 for "not measured", which draws the outline alone:
    // an SVG or an audio file has no shape to compare, and an empty box is the
    // honest picture of that. See services/Wallpaper.qml's `shapes`.
    property real aspect: 0

    // The shape being compared against, normally a screen's.
    property real reference: 0

    // Whether the two count as a match. Not recomputed here: the rule lives in
    // Wallpaper.fits with the tolerance it reads, and a mark that decided for
    // itself would be a second opinion that could disagree with the strip it is
    // sitting under.
    property bool fits: false

    // The box both shapes are fitted into, and therefore the mark's own size.
    property real size: Appearance.font.iconSize

    implicitWidth: size
    implicitHeight: size

    // THE PICTURE SITS INSIDE THE SCREEN, never exactly on it.
    //
    // A wallpaper that fits perfectly is the common case and was the one the
    // mark could not draw: the two rectangles came out identical, the solid one
    // covered the outline exactly, and what was left was a single blue block
    // saying nothing about a screen at all. The outline has to stay visible for
    // the mark to be a comparison rather than a swatch.
    //
    // So the picture is fitted into a box one stroke smaller on every side.
    // A perfect match then reads as a fill sitting neatly inside its frame,
    // which is what "it covers the screen" looks like, and a mismatch reads as
    // the same fill failing to reach two of the edges.
    readonly property real inner: root.size - Appearance.font.stem * 4

    // A rectangle of aspect `a` fitted into a square of side `box`: the long
    // edge takes the whole box and the short one follows from the aspect. One
    // expression for both orientations, since a portrait shape is simply the
    // case where `a` is under one.
    function spanW(a: real, box: real): real {
        return a >= 1 ? box : box * a;
    }

    function spanH(a: real, box: real): real {
        return a >= 1 ? box / a : box;
    }

    // THE SCREEN, as an outline. Drawn at the same weight as the type beside it
    // so the mark reads as part of the line rather than as a diagram dropped
    // into it.
    G2Rect {
        anchors.centerIn: parent
        width: root.reference > 0 ? root.spanW(root.reference, root.size) : root.size
        height: root.reference > 0 ? root.spanH(root.reference, root.size) : root.size
        radius: Appearance.rounding.small / 2
        color: "transparent"
        stroke: Appearance.colour.textFaint
        strokeWidth: Appearance.font.stem
    }

    // THE PICTURE, solid, over it. Coloured by whether it fits, because that is
    // the one piece of state the mark is carrying and the shell's way of saying
    // "this one is on" is the accent.
    G2Rect {
        anchors.centerIn: parent
        visible: root.aspect > 0
        width: root.spanW(root.aspect, root.inner)
        height: root.spanH(root.aspect, root.inner)
        radius: Appearance.rounding.small / 2
        color: root.fits ? Appearance.colour.accent : Appearance.colour.textFaint
    }
}
