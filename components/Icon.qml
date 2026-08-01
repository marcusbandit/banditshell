import QtQuick
import qs.config

// An icon glyph.
//
// Separate from StyledText because it uses a different face: Monocraft has no
// symbols, so icons come from the icon font in config (`font.icon`). Keeping it
// its own component means swapping that face for a pixel icon set later touches
// one file, not every widget.
//
// QtRendering, not NativeRendering: unlike a pixel font, icon outlines want the
// distance-field renderer so they scale and stay smooth.
Text {
    font.family: Appearance.font.icon
    font.pixelSize: Appearance.font.size.large
    color: Appearance.colour.text

    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
