import QtQuick
import qs.config

// Every piece of text in the shell goes through here.
//
// Two reasons it exists rather than using Text directly:
//   1. Monocraft is a pixel font. Qt's default distance-field renderer smears
//      the stems; NativeRendering keeps them on the pixel grid and crisp.
//   2. It makes the three-size rule enforceable: sizes come from
//      Appearance.font.size, never from an inline number.
//      See ~/.claude/rules/type-scale.md.
Text {
    id: root

    font.family: Appearance.font.family
    // `small` is the body size. The pixel grid has no step between 9 and 18, so
    // the bottom of the ladder is the workhorse and the tiers above it are for
    // the one thing a view is about. See config/Config.qml's font block.
    font.pixelSize: Appearance.font.size.small
    renderType: Text.NativeRendering
    color: Appearance.colour.text

    // Monocraft's own hhea box is 1440/1080 units, exactly 4/3 of the em, so a
    // line box of 4/3 the pixel size lands on whole pixels at every size that is
    // a multiple of 9. The font's lineGap is off-grid and is deliberately not
    // used.
    lineHeight: Math.round(font.pixelSize * 4 / 3)
    lineHeightMode: Text.FixedHeight

    // OPTICAL CENTRING, for text placed INSIDE a shape.
    //
    // `anchors.centerIn` centres the text ITEM, and a text item is a line box:
    // as tall as the ascent plus the descent, as wide as the advance. A glyph
    // fills neither of those evenly. "Z" has no descender, so the room the line
    // box reserves for one pushes it visibly high, and a character's side
    // bearings are not symmetric either, so it sits off to one side as well. The
    // letter on the rail's handle was centred by anchors and level with nothing.
    //
    // These are how far the INK's middle is from the box's middle. Hand them to
    // horizontalCenterOffset / verticalCenterOffset and the glyph lands where it
    // LOOKS centred, at any size, for any string, without a nudge value tuned by
    // eye for one font and quietly wrong for the next.
    //
    // For a mark in a shape, not for running text: a paragraph wants its
    // baselines on the grid, which is exactly what this moves off it.
    readonly property real inkOffsetX: root.width / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
    readonly property real inkOffsetY: root.height / 2 - (root.baselineOffset + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)

    // AND HOW BIG THE INK ACTUALLY IS, for a shape drawn AROUND text rather than
    // text placed inside a shape.
    //
    // A badge is the case: the line box at the smallest tier is 24px tall, which
    // in a 25px row is the whole row, while the ink of a numeral is under half
    // that. Sizing the shape to the box gives a badge that is all box; sizing it
    // to this gives one that hugs the digits, at any size and for any string.
    readonly property real inkWidth: ink.tightBoundingRect.width
    readonly property real inkHeight: ink.tightBoundingRect.height

    TextMetrics {
        id: ink

        font: root.font
        text: root.text
    }
}
