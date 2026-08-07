pragma ComponentBehavior: Bound

import QtQuick
import qs.config

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
// It takes a `language` and currently does nothing with it. That is deliberate
// rather than unfinished: the split between "show me this text" and "colour it"
// is where the seam belongs, so the highlighting can arrive without this file's
// callers changing. Until then a paste is legible, scrollable and correctly
// monospaced, which is most of what the full view is for.
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
    readonly property string resolvedLanguage: root.language

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
                color: Appearance.colour.text
                textFormat: Text.PlainText

                text: line.modelData
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
