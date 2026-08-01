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
    font.family: Appearance.font.family
    font.pixelSize: Appearance.font.size.normal
    renderType: Text.NativeRendering
    color: Appearance.colour.text
}
