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

    // A RAW GLYPH from the brand face, given as the character itself. Set this
    // and it is drawn instead of `name`: a Nerd Font addresses its glyphs by
    // codepoint rather than by ligature, so there is no name to look up and
    // nothing to verify. See Apps.brandGlyphs.
    property string glyph: ""

    // How big to draw it. A property rather than a direct binding on
    // font.pixelSize, because `font` is ONE property group: a binding on
    // font.variableAxes that reads font.pixelSize is a loop, and the optical
    // size axis below has to know the rendered size.
    property real size: Appearance.font.iconSize

    // SOLID or outlined, 0 to 1. Material Symbols treats FILL as a STATE axis
    // rather than a style one: the same mark, filled, is how the set says "this
    // one is on". So it belongs here as a property of the mark, not as a second
    // icon name to remember, and it takes fractions because the axis does - a
    // mark can be filled part of the way as it turns on.
    property real fill: 0

    readonly property bool resolved: probe.width <= font.pixelSize * 1.7

    text: root.glyph || (resolved ? name : fallback)

    font.family: root.glyph ? Appearance.font.brand : Appearance.font.icon
    font.pixelSize: root.size
    color: Appearance.colour.text

    // Material Symbols is a variable font whose optical-size axis runs 20 to 48
    // and defaults to 48. Drawn at 18 with opsz left at its default, every glyph
    // carries stroke weights drawn for an icon more than twice the size. Track
    // the rendered size, clamped into the axis's real range rather than to a
    // number picked here.
    font.variableAxes: ({
            opsz: Math.max(20, Math.min(48, root.size)),
            FILL: root.fill
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

    // OPTICAL CENTRING, for a mark placed inside a shape. See
    // StyledText.inkOffsetX for what these are and why a centred anchor does not
    // do it on its own.
    //
    // Measured off `text` rather than `name`, because what is drawn may be the
    // fallback or a raw brand glyph, and it is the DRAWN thing that has to sit
    // in the middle. From contentWidth rather than width, because this one is
    // centre-aligned: the ink is measured from where the string actually starts,
    // and that is the middle of the box, not its left edge.
    readonly property real inkOffsetX: root.contentWidth / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
    readonly property real inkOffsetY: root.height / 2 - (root.baselineOffset + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)

    TextMetrics {
        id: probe

        font: root.font
        text: root.name
    }

    TextMetrics {
        id: ink

        font: root.font
        text: root.text
    }

    onResolvedChanged: if (!resolved && name && !root.glyph)
        console.warn(`Icon: "${name}" is not in ${Appearance.font.icon}; drawing ${fallback} instead.`)
}
