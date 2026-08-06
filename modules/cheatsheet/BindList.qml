pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// THE LIST: every bind there is, grouped by how it is pressed.
//
// It is the sheet as it was before there were two of them, moved out of
// CheatSheet whole rather than rewritten, because nothing about it was wrong:
// it is the view that answers "what is on SUPER" and "what did I bind last
// week", and a keyboard cannot answer either without being read key by key. The
// two views are indexes into the same binds, not a replacement of one by the
// other, which is why the switch between them is a segmented control and not a
// setting somewhere.
//
// The grouping, the ordering and the two-column measurement all live on the
// sheet, because the card is measured off them before this item exists. What is
// here is the drawing.
Item {
    id: root

    // A `var` and not a CheatSheet: the sheet instantiates this file, and naming
    // the type would be a cycle between two components in one directory.
    required property var sheet

    // THE NAME OF THE FAMILY THAT HAS NO MODIFIERS AT ALL, which is a family
    // like any other and on a laptop the commonest one there is: every volume,
    // brightness, mic and media key on this machine is bound bare, ten of the
    // eighty-three, and they sort into a block of their own like SUPER does.
    // Without a name that block is a rule, a band of air and then ten rows,
    // which reads as a stray tail of the family above rather than as a group
    // with something in common.
    //
    // IT IS A WORD IN BOTH VOCABULARIES, and that is not an oversight. There is
    // no symbol anywhere for the ABSENCE of a modifier, in this shell's symbol
    // face or in anybody's, and the toggle upstairs is a choice about how a
    // modifier is spelled rather than about whether the sheet speaks English at
    // all. Handed to the same Chord as every other heading rather than drawn as
    // a StyledText beside it, so it lands on the same baseline, in the same
    // face, at the same colour, by construction instead of by two components
    // agreeing; the cells are the string's own length because the shell's face
    // is monospaced (see Chord).
    readonly property string bareName: "NO MODIFIER"

    readonly property var bareParts: [
        {
            text: root.bareName,
            glyph: "",
            cells: root.bareName.length
        }
    ]

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: root.width
        spacing: Appearance.padding.normal

        // The sheet with nothing on it, which is not the same as a sheet that
        // has not drawn. It names WHERE the nothing came from rather than saying
        // "no binds", because the three ways to get here (a compositor with no
        // binds, an hyprctl that is not on PATH, and one that answered with
        // something other than JSON) are indistinguishable from this side and
        // all three are questions about hyprctl. The parse failure also puts a
        // line in the log.
        StyledText {
            width: parent.width
            elide: Text.ElideRight
            visible: root.sheet.rows.length === 0

            text: "nothing came back from hyprctl"
            color: Appearance.colour.textGhost
        }

        Repeater {
            model: root.sheet.sections

            delegate: Column {
                id: section

                required property var modelData
                required property int index

                width: list.width
                spacing: Appearance.padding.small

                // THE FAMILY'S CHORD, built by CALLING the sheet rather than
                // read off the model, which is what keeps the vocabulary live. A
                // binding that invokes a function still captures every property
                // that function reads, so `symbols` flipping re-evaluates every
                // chord on screen; baking the parts into the parsed rows would
                // freeze them at whichever vocabulary was current when hyprctl
                // answered.
                //
                // Held here rather than written straight into the heading below
                // because the heading has to know whether it came back EMPTY.
                // chordParts writes one part per modifier bit and the key is
                // left off for a heading, so a family pressed with no modifier
                // produces no parts at all and a Chord with no parts is a line
                // of nothing. Tested on the RESULT and not on the mask, because
                // an empty chord is the exact condition that draws as an empty
                // band; all eight xkb modifier bits are in the sheet's table
                // (see CheatSheet.modBits), so mask 0 is the only thing that can
                // reach it and the name below is true whenever it does.
                readonly property var headParts: root.sheet.chordParts(section.modelData.mask, "")

                // A hairline in its own band of air, on every section but the
                // first. The band is what gives the rule room to breathe: a
                // Separator dropped straight into the column would sit one row
                // spacing from the rows on either side and read as an underline
                // on the last of them. An invisible item takes no space in a
                // Column, so the first section simply starts.
                Item {
                    width: parent.width
                    height: Appearance.padding.normal
                    visible: section.index > 0

                    Separator {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                    }
                }

                // THE FAMILY'S NAME, in whichever vocabulary the sheet is
                // speaking, so a heading and the rows under it cannot disagree
                // about what SUPER is called. Drawn through the same component
                // as a chord with the key left off, rather than through a
                // string: a symbol is not a character of the shell's face and
                // one Text has one family (see Chord).
                Item {
                    width: parent.width
                    height: heading.implicitHeight

                    Chord {
                        id: heading

                        // The chord, or the words for not having one, and the
                        // fallback is the whole reason a heading is measured
                        // before it is drawn: see `headParts` above.
                        parts: section.headParts.length > 0 ? section.headParts : root.bareParts
                        advance: root.sheet.advance
                        color: Appearance.colour.textFaint
                    }

                    // The submap, which is not part of the chord and must not
                    // look like it is: a bind inside one does nothing at all
                    // until you have entered the mode, so it qualifies the whole
                    // family rather than adding a key to press.
                    StyledText {
                        x: heading.implicitWidth + Appearance.padding.small
                        width: Math.max(0, parent.width - heading.implicitWidth - Appearance.padding.small)
                        elide: Text.ElideRight
                        visible: !!section.modelData.submap

                        text: section.modelData.submap ? `(${section.modelData.submap})` : ""
                        color: Appearance.colour.textFaint
                    }
                }

                Repeater {
                    model: section.modelData.rows

                    delegate: Item {
                        id: line

                        required property var modelData

                        width: section.width
                        height: chord.implicitHeight

                        // THE CHORD, in the brightest tier: it is the thing you
                        // came here to find, and the description is what
                        // confirms you found the right one.
                        //
                        // It repeats the modifiers the section heading already
                        // named, and that is deliberate: a row you read out of
                        // the corner of your eye, or photograph, or scroll to
                        // with the heading off the top, has to be a complete
                        // answer on its own.
                        Chord {
                            id: chord

                            // Clamped as well as sized, and the clamp is never
                            // reached in practice: the column is already as wide
                            // as the longest chord there is, so nothing is cut.
                            // It is here for the pathological narrow screen,
                            // where the column measured wider than the card it
                            // sits in and a chord would otherwise run out past
                            // the padding.
                            width: Math.min(root.sheet.chordWidth, line.width)
                            // Clipped only when the clamp above actually bit,
                            // and tested against the sheet's two numbers rather
                            // than against this item's own width and implicit
                            // width. Those two are the same test and Qt reads
                            // them as a loop: `clip` is a property of the item
                            // that owns the geometry it would be reading. It is
                            // also a render pass, which is worth avoiding on
                            // eighty rows that never need it.
                            clip: root.sheet.chordWidth > line.width

                            parts: root.sheet.chordParts(line.modelData.mask, line.modelData.key)
                            advance: root.sheet.advance
                        }

                        StyledText {
                            x: root.sheet.chordWidth + root.sheet.gutter
                            width: Math.max(0, line.width - root.sheet.chordWidth - root.sheet.gutter)
                            elide: Text.ElideRight

                            text: line.modelData.what
                            color: Appearance.colour.textDim
                        }
                    }
                }
            }
        }
    }
}
