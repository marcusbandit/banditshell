import QtQuick
import qs.config

// An icon glyph.
//
// Separate from StyledText because it uses a different face: Monocraft has no
// symbols, so icons come from the icon font in config (`font.icon`). Keeping it
// its own component means swapping that face for a pixel icon set later touches
// one file, not every widget.
//
// CurveRendering, set explicitly rather than left to the default. Native
// rendering gives icons subpixel colour fringes, and orange and blue edges on a
// monochrome glyph is exactly the sort of detail that reads as cheap. The curve
// rasterizer antialiases in greyscale and stays sharp at any size, which suits
// an outline icon; Monocraft keeps NativeRendering, because a pixel font wants
// the pixel grid instead.
Text {
    font.family: Appearance.font.icon
    font.pixelSize: Appearance.font.iconSize
    color: Appearance.colour.text
    renderType: Text.CurveRendering

    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
