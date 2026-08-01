import QtQuick
import qs.config

// An icon glyph, by name.
//
// Separate from StyledText because it uses a different face: Monocraft has no
// symbols, so icons come from the icon font in config (`font.icon`). Keeping it
// its own component means swapping that face for a pixel icon set later touches
// one file, not every widget.
//
// IT CHECKS THE NAME EXISTS, which is the whole reason this is not a plain Text.
// An icon font addresses glyphs by LIGATURE, so a name the font does not have
// does not fail: it renders as its own name, in letters, at icon size, in the
// middle of the interface. `battery_charging_70` is not a Material Symbol, and
// the shell cheerfully drew the words "ARGING_70" across a menu. A missing
// ligature is far wider than one glyph, so measuring is enough to catch it, and
// then it says so in the log instead of on the screen.
Text {
    id: root

    // The ligature to draw.
    property string name: ""
    // What to draw when `name` is not in the font.
    property string fallback: "question_mark"

    readonly property bool resolved: probe.width <= font.pixelSize * 1.7

    text: resolved ? name : fallback

    font.family: Appearance.font.icon
    font.pixelSize: Appearance.font.iconSize
    color: Appearance.colour.text

    // Material Symbols is a variable font whose optical-size axis runs 20 to 48
    // and defaults to 48. Drawn at 18 with opsz left at its default, every glyph
    // carries stroke weights drawn for an icon more than twice the size. Track
    // the rendered size, clamped into the axis's real range rather than to a
    // number picked here.
    // Reads the token, NOT font.pixelSize: `font` is one property group, so a
    // binding on font.variableAxes that reads font.pixelSize is a loop.
    font.variableAxes: ({
            opsz: Math.max(20, Math.min(48, Appearance.font.iconSize))
        })

    // CurveRendering, set explicitly rather than left to the default. Native
    // rendering gives icons subpixel colour fringes, and orange and blue edges on
    // a monochrome glyph is exactly the sort of detail that reads as cheap. The
    // curve rasterizer antialiases in greyscale and stays sharp at any size,
    // which suits an outline icon; Monocraft keeps NativeRendering, because a
    // pixel font wants the pixel grid instead.
    renderType: Text.CurveRendering

    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter

    TextMetrics {
        id: probe

        font: root.font
        text: root.name
    }

    onResolvedChanged: if (!resolved && name)
        console.warn(`Icon: "${name}" is not in ${Appearance.font.icon}; drawing ${fallback} instead.`)
}
