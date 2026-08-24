import QtQuick
import qs.config

// A paragraph that BREAKS ON PURPOSE rather than wherever it runs out of room.
//
// Ordinary word wrap is greedy: it fills each line to the edge and whatever is
// left over becomes the last one. Two thirds of the time that is fine and the
// rest of the time it hands you an orphan - a full line and then the word "in" -
// which reads as text that overflowed rather than text that was set. It is worst
// on exactly the strings this shell does not write itself: a notification body,
// a certificate warning, "Automatically unlock this keyring whenever I'm logged
// in", where the length is somebody else's decision and there is no hand-placed
// break to fall back on.
//
// So the LINE COUNT is taken from the room, and then the width is pulled in
// until one more pull would cost a line. Same number of lines, evened out, and
// the break lands where the sentence can take it.
//
//     ┌──────────────────────────────┐   ┌───────────────────────┐
//     │ Automatically unlock this    │   │ Automatically unlock  │
//     │ keyring whenever I'm         │   │ this keyring whenever │
//     │ logged in                    │   │ I'm logged in         │
//     └──────────────────────────────┘   └───────────────────────┘
//                greedy                          balanced
//
// EXACT, NOT ESTIMATED, because the shell's face is monospaced: every glyph has
// the same advance, so a line's width in characters IS its width in pixels and
// the search below is arithmetic rather than a series of trial layouts. On a
// proportional face this construction would still be right and would need real
// measurement; there is one ruler at the bottom of this file and it is the only
// thing that would have to change.
//
// A caller gives it the room (a width, or left and right anchors) and reads the
// height back, exactly as it would from a wrapping Text:
//
//     BalancedText {
//         width: parent.width
//         text: Keyring.description
//         color: Appearance.colour.textFaint
//     }
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property alias horizontalAlignment: label.horizontalAlignment

    // The ceiling on how many lines this may become. NOT restraint: it is a
    // fuse. Every string this component is pointed at was written by somebody
    // else, and a sender that emits a paragraph must not be able to push a
    // card's buttons off the bottom of the screen.
    property int maxLines: 6

    implicitHeight: label.implicitHeight
    implicitWidth: label.implicitWidth

    // One character's advance, measured off the font in use rather than assumed
    // from Monocraft's two-thirds. Ten of them and a division, because a single
    // character's advance is a rounding error's worth of the answer.
    TextMetrics {
        id: ruler

        font: label.font
        text: "MMMMMMMMMM"
    }

    readonly property real advance: ruler.advanceWidth / ruler.text.length

    // How many lines greedy wrapping would need at a given number of columns.
    // The same rule Text applies, so the count this predicts is the count that
    // gets drawn: fill until the next word would not fit, then break.
    //
    // A word LONGER than the column count still takes its own line here, which
    // is what Text does too once it has broken the word by force. Both agree
    // about the line, and neither pretends the word fits.
    function lines(words: var, columns: int): int {
        let count = 1;
        let filled = 0;
        for (const word of words) {
            const grown = filled ? filled + 1 + word.length : word.length;
            if (grown > columns && filled) {
                count += 1;
                filled = word.length;
            } else {
                filled = grown;
            }
        }
        return count;
    }

    readonly property var words: root.text.split(/\s+/).filter(w => w.length > 0)

    // THE NARROWEST WIDTH THAT STILL COSTS THE SAME NUMBER OF LINES.
    //
    // Walked down one column at a time rather than bisected, and that is not
    // laziness: the line count is a step function of the width and the step this
    // is looking for is the FIRST one below the room, so a bisection would need
    // the same monotonicity argument and would land on the same column after
    // more code. These are label-length strings, so the walk is a handful of
    // integer comparisons.
    //
    // Stopped at the fuse: if the room already needs more lines than `maxLines`,
    // there is nothing to balance and the full width is the honest answer, since
    // narrowing it would only add lines to a paragraph that is already too tall.
    readonly property real balanced: {
        const room = Math.max(0, root.width);
        if (!root.words.length || root.advance <= 0 || room <= 0)
            return room;

        const columns = Math.floor(room / root.advance);
        if (columns < 1)
            return room;

        const want = root.lines(root.words, columns);
        if (want <= 1 || want > root.maxLines)
            return room;

        let narrowest = columns;
        for (let c = columns - 1; c >= 1; c--) {
            if (root.lines(root.words, c) > want)
                break;
            narrowest = c;
        }
        // Half a character of slack, so a line that measures exactly its column
        // count is not tipped over by the renderer's own rounding.
        return Math.min(room, (narrowest + 0.5) * root.advance);
    }

    StyledText {
        id: label

        // NOT anchored to the parent's edges: the whole point is that this is
        // narrower than the room it was given. Left-aligned within it, so a
        // stack of these keeps one margin however the individual widths land.
        width: root.balanced
        wrapMode: Text.WordWrap
        maximumLineCount: root.maxLines
        elide: Text.ElideRight
    }
}
