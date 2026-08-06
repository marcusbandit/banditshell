pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// A CHORD, drawn: the modifiers and the key, in whichever vocabulary the sheet
// is currently speaking.
//
// It is a row of items rather than one string, and that is forced rather than
// chosen. In words it would happily be a string, because every character comes
// out of the shell's own face. In symbols it cannot: the penguin, the shift
// arrow and the control caret live in the Nerd Fonts symbol face (see
// CheatSheet.modBits for how each one was found), Monocraft has none of the four
// codepoints, and one Text has one family. The alternatives were both worse.
// Leaning on Qt's font fallback would mean the sheet's most visible feature
// working because fontconfig happened to resolve a private-use codepoint, and
// failing as a row of empty boxes on a machine where it did not. Rich text with
// a family span would put HTML in the one component whose entire job is that
// there is no HTML in this shell, and would take StyledText off native
// rendering, which is what keeps a pixel font on the pixel grid.
//
// SO THE PARTS ARE LAID OUT, and the price of that is that a chord no longer
// measures itself: a Row's width is only known once it is laid out, and the
// sheet's chord column has to be the same width on every row BEFORE any of them
// are. That is what `cells` is for. Every part declares its width in CHARACTER
// ADVANCES, the caller adds them up (CheatSheet.chordCells) and multiplies by
// one advance, and the drawn row is exactly as wide as the sum said it would be
// because each part below is given that width explicitly. Monocraft is
// monospaced, so an advance is an exact unit rather than an approximation, which
// is the same fact the sheet already leans on to pick its widest chord by string
// length.
Item {
    id: root

    // The parts, from CheatSheet.chordParts: each is a `text` to set in the
    // shell's face, or a `glyph` to set in the symbol face, plus how many
    // character advances wide it is.
    required property var parts

    // One character of the shell's face, measured once by the sheet and handed
    // down. Measured rather than computed from the font's ratio, so a change of
    // face cannot silently put every chord column half a character out.
    required property real advance

    property color color: Appearance.colour.text

    readonly property int cells: {
        let n = 0;
        for (const p of root.parts)
            n += p.cells;
        return n;
    }

    implicitWidth: root.cells * root.advance
    implicitHeight: Math.round(Appearance.font.size.small * 4 / 3)

    Row {
        anchors.fill: parent

        Repeater {
            model: root.parts

            delegate: Item {
                id: part

                required property var modelData

                width: part.modelData.cells * root.advance
                height: root.height

                StyledText {
                    anchors.fill: parent
                    visible: !part.modelData.glyph
                    verticalAlignment: Text.AlignVCenter

                    text: part.modelData.text ?? ""
                    color: root.color
                }

                // A SYMBOL, through the shell's own glyph component rather than
                // through a Text with a family set on it. Icon already knows
                // that a raw codepoint is drawn from the brand face and that a
                // line glyph wants curve rendering rather than the pixel grid;
                // writing that again here would be a second opinion about the
                // same thing, and the first one to drift would be this one.
                //
                // Drawn at the BODY SIZE, not the icon size. A modifier symbol
                // is standing in for a word in a line of type, so it has to sit
                // on that line rather than beside it; at Appearance.font.
                // iconSize it would be the tallest thing in the sheet and every
                // chord carrying one would ride a pixel or two higher than the
                // chords that do not.
                Icon {
                    anchors.centerIn: parent
                    visible: !!part.modelData.glyph

                    glyph: part.modelData.glyph ?? ""
                    size: Appearance.font.size.small
                    color: root.color
                }
            }
        }
    }
}
