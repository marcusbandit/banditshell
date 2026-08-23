import QtQuick
import "theme.js" as Theme

// Every piece of text the installer draws.
//
// Two jobs, the same two components/StyledText.qml has. Monocraft is a pixel
// font and Qt's distance-field renderer smears its stems, so this pins
// NativeRendering; and the size comes from theme.js by NAME, so the three-size
// rule is something the code enforces rather than something a reviewer has to
// notice. There are no inline pixel sizes in this directory.
//
// Hierarchy past those three sizes is carried by weight, colour and opacity,
// which carry it better anyway. See ~/.claude/rules/type-scale.md.
Text {
    id: root

    font.family: Theme.fontFamily
    font.pixelSize: Theme.small
    renderType: Text.NativeRendering
    color: Theme.text

    // Monocraft's hhea box is exactly 4/3 of the em, so a line box of 4/3 the
    // pixel size lands on whole pixels at every size that is a multiple of 9.
    lineHeight: Math.round(font.pixelSize * 4 / 3)
    lineHeightMode: Text.FixedHeight
}
