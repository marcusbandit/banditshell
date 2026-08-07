pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import "highlight.js" as Highlight

// A BODY OF TEXT, READ RATHER THAN SKIMMED.
//
// ONE DELEGATE PER LINE, which is the whole of the construction and the only
// decision in here that is not taste. A clipboard holds whatever was copied, and
// what was copied is sometimes a sixty-thousand-line log: put that in a single
// Text and Qt lays out the entire document to draw the twenty lines on screen,
// on every resize, and the panel stops answering. A ListView builds the lines it
// can see. The cost is that nothing can wrap across a line boundary and that
// horizontal scrolling is per-line, which is exactly how a code view should
// behave anyway.
//
// COLOURED, and the seam it arrived through is the one this file was built with:
// callers still hand it a `language` and nothing else changed.
// components/highlight.js turns text into spans and knows no colours,
// config/Appearance.qml turns a span's kind into a colour and knows no
// languages, and this file is the only one that knows both, which is the whole
// of what a view is for.
//
// An EMPTY language is still legal and still means "do not colour". That is not
// a fallback, it is the honest answer for the clipboard's common case: a
// paragraph is not code and lexing it as some would put half its words in the
// keyword colour. highlight.js's detect() is deliberately conservative for the
// same reason, and this asks it only when the caller has no opinion.
Item {
    id: root

    property string text: ""
    property string language: ""
    property bool wrap: false
    property bool gutter: false

    // BEYOND THIS, STOP. Not a performance guard (the list already only builds
    // what it draws) but an honesty one: splitting a hundred megabytes into
    // lines is itself the expensive part, and a view that hung on a paste it
    // could not have shown usefully anyway would be worse than one that says how
    // much it is showing.
    property int maxLines: 20000

    readonly property var lines: {
        const all = (root.text ?? "").split("\n");
        return all.length > root.maxLines ? all.slice(0, root.maxLines) : all;
    }

    readonly property int lineCount: (root.text ?? "").split("\n").length
    readonly property bool truncated: root.lineCount > root.maxLines

    // The caller's opinion wins. detect() is only asked when there is none, and
    // it answers "" whenever it is not sure, which is most of the time and is
    // the point of it.
    readonly property string resolvedLanguage: root.language ? root.language : Highlight.detect(root.text ?? "")

    // BEYOND THIS, DO NOT COLOUR. Separate from maxLines and for a different
    // reason: the list only ever builds the lines it draws, but tokenizing is
    // ONE PASS OVER THE WHOLE DOCUMENT (highlight.js says why it cannot be
    // per-line), and that pass is not lazy. A twenty-thousand-line paste would
    // spend it on the frame the panel opens, which is the one frame that must
    // not stutter. Uncoloured text is a small loss; a panel that hitches on open
    // is the thing people actually notice.
    property int colourLimit: 4000

    readonly property bool colouring: root.resolvedLanguage !== "" && root.lineCount <= root.colourLimit

    // One line in, one line out, spans that concatenate back to the input
    // exactly: highlight.js's round-trip contract, which is what lets the
    // markup below be assembled without ever comparing it to the source.
    readonly property var tokens: root.colouring ? Highlight.tokenize(root.text ?? "", root.resolvedLanguage) : null

    // TEXT INTO MARKUP, which is the one genuinely dangerous step here.
    //
    // Every span is escaped before it is wrapped, so a clipboard holding
    // `<b>` or `a && b` draws those characters instead of turning into markup
    // the parser then eats. The lexer guarantees the spans reproduce the input;
    // this guarantees the reproduction survives being put in a tag.
    //
    // SPACES BECOME &nbsp;. Text.StyledText collapses runs of whitespace the way
    // HTML does, which would silently flatten every indent in the document. That
    // is why `wrap` and colouring do not mix: non-breaking spaces cannot wrap.
    // Nothing here sets both, because the callers that ask for colour are
    // showing code and code is panned rather than wrapped.
    function escapeSpan(s: string): string {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/\t/g, "    ").replace(/ /g, "&nbsp;");
    }

    function markup(i: int): string {
        const spans = root.tokens ? root.tokens[i] : null;
        if (!spans)
            return root.escapeSpan(root.lines[i] ?? "");

        let out = "";
        for (let j = 0; j < spans.length; j++) {
            const span = spans[j];
            // `plain` is the default the palette already returns for anything it
            // does not know, so it is written as a tag like everything else
            // rather than special-cased into a bare string. One path, and the
            // colour of ordinary code stays the palette's decision.
            out += `<font color="${Appearance.syntaxColour(span.k)}">${root.escapeSpan(span.s)}</font>`;
        }
        return out;
    }

    // The gutter is as wide as the widest number it will ever hold, measured
    // rather than guessed, so the text does not shift left as the list scrolls
    // past line 100 (~/.claude/rules/math-over-hardcoding.md).
    TextMetrics {
        id: digits

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: `${root.lines.length}`
    }

    readonly property real gutterWidth: root.gutter ? Math.ceil(digits.width) + Appearance.padding.normal : 0

    ListView {
        id: view

        anchors.fill: parent
        clip: true
        model: root.lines
        // Uniform by construction: every line is one line box of one font.
        // Telling the view so is what lets it size itself without measuring
        // delegates it has not built.
        cacheBuffer: Math.round(Appearance.font.size.small * 4 / 3) * 20
        boundsBehavior: Flickable.StopAtBounds

        // Horizontal room for the longest line, when lines are not wrapped.
        // A Flickable inside a Flickable was rejected: the inner one takes the
        // drag and the outer one never scrolls, which is the bug every nested
        // scroll area has. This moves the CONTENT instead, so the vertical list
        // keeps every gesture it had.
        property real pan: 0

        delegate: Item {
            id: line

            required property string modelData
            required property int index

            width: view.width
            height: Math.max(text.implicitHeight, Math.round(Appearance.font.size.small * 4 / 3))

            Text {
                id: number

                visible: root.gutter
                width: root.gutterWidth
                horizontalAlignment: Text.AlignRight
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.small
                renderType: Text.NativeRendering
                lineHeight: Math.round(font.pixelSize * 4 / 3)
                lineHeightMode: Text.FixedHeight
                color: Appearance.colour.textGhost
                text: `${line.index + 1}`
            }

            Text {
                id: text

                x: root.gutterWidth - view.pan
                width: root.wrap ? view.width - root.gutterWidth : implicitWidth
                wrapMode: root.wrap ? Text.Wrap : Text.NoWrap

                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.small
                // Monocraft is a pixel font: the distance-field renderer smears
                // its stems, so every piece of text in this shell goes through
                // native rendering. StyledText's note, and its reason.
                renderType: Text.NativeRendering
                lineHeight: Math.round(font.pixelSize * 4 / 3)
                lineHeightMode: Text.FixedHeight
                // The colour of last resort, for the uncoloured case only: with
                // markup every span carries its own and this is never seen.
                color: Appearance.colour.text
                textFormat: root.colouring ? Text.StyledText : Text.PlainText

                text: root.colouring ? root.markup(line.index) : line.modelData
            }
        }

        // The widest line decides how far there is to pan. Measured off the
        // built delegates only, which is a floor rather than the truth, and is
        // enough: panning stops where the widest line anyone has actually seen
        // ends, and extends as further ones are built.
        onContentYChanged: view.pan = Math.min(view.pan, Math.max(0, view.contentWidth - view.width))

        WheelHandler {
            // A HORIZONTAL scroll pans. Vertical is handed back so the list
            // keeps it, which is the same test the clipboard panel's own pager
            // makes one layer out: a wheel with no pixel delta is a mouse and
            // has nothing horizontal to say.
            onWheel: event => {
                if (root.wrap || Math.abs(event.pixelDelta.x) <= Math.abs(event.pixelDelta.y)) {
                    event.accepted = false;
                    return;
                }
                view.pan = Math.max(0, view.pan - event.pixelDelta.x);
                event.accepted = true;
            }
        }
    }

    // Said out loud rather than simply stopping, because a document that ends
    // without warning reads as the whole document.
    Text {
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        visible: root.truncated
        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        renderType: Text.NativeRendering
        color: Appearance.colour.textFaint
        text: `showing the first ${root.maxLines} of ${root.lineCount} lines`
    }
}
