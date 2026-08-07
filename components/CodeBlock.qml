pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import "highlight.js" as Highlight

// A BODY OF TEXT, READ AS CODE.
//
// It exists because the shell keeps being handed text it did not write and has
// no idea how big it is: a clipboard entry, a config file, an error a service
// spat out. The size is the whole design problem. Everything else here follows
// from refusing to be surprised by a sixty-thousand-line paste.
//
// ONE DELEGATE PER LINE, on a GlideList. The obvious build is one Text element
// holding the whole document with the colours in it, and it is wrong twice over.
// Rich text is laid out eagerly, so that Text does the work for all sixty
// thousand lines before the first one appears, and it holds the styled layout
// for all of them afterwards. A list builds the lines you can see. The cost is
// that every line is its own layout, which is exactly the trade a code view
// wants: lines are independent, that is what a line IS.
//
// THE COLOURS ARE NOT IN HERE, and they are not in the highlighter either. The
// highlighter returns spans (a kind and the characters it covers) and this file
// turns a kind into one of four values read off Appearance. There is not a hex
// literal anywhere in either file, so a theme swap recolours the code view along
// with everything else and nobody has to remember it exists.
//
// FOUR VALUES, for fourteen kinds, and the sharing is deliberate. The theme is
// one hue family plus one saturated accent, so the honest count of things that
// are TELLABLE APART on this surface is small, and Monocraft makes it smaller: a
// pixel font's stems are one device pixel, anti-aliasing has nothing to work
// with, and a mid-tone turns the text to mush (DESIGN.md 6). Inventing a fifth
// and sixth colour by reaching down the ramp would buy separation by making the
// code harder to read, which is the wrong way round. So:
//
//   accent   what you scan FOR: keywords, types, functions, map keys, booleans
//   text     the body, and numbers
//   pale     strings, one stop down the ramp: a different material, still bright
//   dim      the connective tissue, and the quietest thing here: comments,
//            punctuation, null, and a diff's removed lines
//
// A key and a keyword are never both on screen in a language that has both in
// the same place, and a number and an identifier are told apart by their shape
// long before their colour. Where two kinds share a value, position already
// separates them.
//
// IT IS A VIEWPORT, not a block that grows: give it a size. An implicit height
// of "however tall the document is" is a thing a caller cannot use, because the
// answer is routinely taller than the screen.
Item {
    id: root

    // The source. Anything at all; it does not have to be code.
    property string text: ""

    // "" means: work it out. See Highlight.detect, which answers "" itself
    // rather than guessing, and this passes that straight through.
    property string language: ""

    // Soft-wrap long lines instead of scrolling sideways past them.
    property bool wrap: false

    // Past this many lines the colour stops and the view says so. Tokenizing is
    // linear and fast (about 30ms for 80KB), but the SPANS are the cost: a few
    // objects per line, kept for as long as the block is alive, and past a
    // certain size a reader is scrolling to find one thing rather than reading,
    // which is the job colour was doing.
    property int maxLines: 2000

    // Line numbers down the left. Off by default: a number beside every line is
    // an answer to "which line", and most of the places this gets used are not
    // asking that.
    property bool gutter: false

    // How wide a tab draws. A text convention rather than a design token, which
    // is why it is here and not in Appearance, and a property rather than a 4
    // buried in the escaping.
    property int tabWidth: 4

    readonly property var lines: root.text.split("\n")
    readonly property int lineCount: root.lines.length
    readonly property string resolvedLanguage: root.language !== "" ? root.language : Highlight.detect(root.text)

    readonly property bool coloured: root.lineCount <= root.maxLines

    // Either an array of span arrays or an array of strings, and the delegate
    // takes both. Building [{k: "plain", s: line}] for every line of an
    // uncoloured document would allocate the thing the cap exists to avoid.
    readonly property var rows: root.coloured ? Highlight.tokenize(root.text, root.resolvedLanguage) : root.lines

    // ---------------------------------------------------------------- colour

    // Two stops below the tint on the theme's eleven-stop ramp, at full alpha.
    // The label tiers are all the SAME colour at different opacities, so they
    // can only differ in weight; this is the one value available that differs in
    // kind while staying bright enough for a pixel font to survive.
    readonly property color inkString: Appearance.rampAt(8, 1)

    readonly property color inkPlain: Appearance.colour.text

    // Kind -> colour, as the `#AARRGGBB` string Qt's StyledText parser wants.
    // The hex is GENERATED from a token, never written: `hex()` is the only
    // place in this file that knows what a colour is made of, and it is there
    // because <font color=...> takes a string and nothing else.
    //
    // `plain` is deliberately absent. It is the Text's own colour, so the
    // commonest span in any document costs no markup at all.
    readonly property var inks: ({
            keyword: root.hex(Appearance.colour.accent),
            type: root.hex(Appearance.colour.accent),
            function: root.hex(Appearance.colour.accent),
            key: root.hex(Appearance.colour.accent),
            boolean: root.hex(Appearance.colour.accent),
            added: root.hex(Appearance.colour.accent),
            number: root.hex(Appearance.colour.text),
            string: root.hex(root.inkString),
            comment: root.hex(Appearance.colour.textDim),
            punct: root.hex(Appearance.colour.textDim),
            operator: root.hex(Appearance.colour.textDim),
            null: root.hex(Appearance.colour.textDim),
            removed: root.hex(Appearance.colour.textDim)
        })

    function hex(c: color): string {
        const byte = x => ("0" + Math.round(x * 255).toString(16)).slice(-2);
        return "#" + byte(c.a) + byte(c.r) + byte(c.g) + byte(c.b);
    }

    // ---------------------------------------------------------------- markup

    // One line's spans, as the small subset of HTML that Text.StyledText reads.
    //
    // EVERY SPACE IS FOUGHT FOR. The parser collapses runs of spaces and drops
    // the ones at the head of a line, the way a browser does, which for prose is
    // right and for code destroys the only structure indentation has: a
    // four-space indent measured 0px, and a Python file came out flat. So a
    // space becomes a non-breaking space whenever the character before it was
    // also a space, or when it is the first thing on the line. A run of N is
    // then one ordinary space and N-1 hard ones: the same width in a monospace
    // face, no collapsing, and the one ordinary space left in each run is a
    // place the line is still allowed to wrap. Making every space hard would
    // have preserved the width and quietly disabled `wrap`.
    function markup(row: var): string {
        // A delegate can be handed nothing for a frame while the model is being
        // swapped underneath it, and a view that throws on the way to being
        // replaced fills the log with errors about a row that no longer exists.
        if (row === undefined || row === null)
            return "";

        const spans = typeof row === "string" ? [{
                k: "plain",
                s: row
            }] : row;

        let out = "";
        let column = 0;
        // True at the head of the line, so the indent survives.
        let afterSpace = true;

        for (let i = 0; i < spans.length; i++) {
            const span = spans[i];
            const s = span.s;
            let body = "";

            for (let j = 0; j < s.length; j++) {
                const c = s[j];

                if (c === "\t") {
                    // To the next tab stop, computed from where we actually are
                    // rather than assumed to be one tab wide.
                    const run = root.tabWidth - column % root.tabWidth;
                    for (let k = 0; k < run; k++)
                        body += "&nbsp;";
                    column += run;
                    afterSpace = true;
                    continue;
                }

                if (c === " ") {
                    body += afterSpace ? "&nbsp;" : " ";
                    afterSpace = true;
                    column++;
                    continue;
                }

                body += c === "&" ? "&amp;" : c === "<" ? "&lt;" : c === ">" ? "&gt;" : c;
                afterSpace = false;
                column++;
            }

            const colour = root.inks[span.k];
            out += colour === undefined ? body : "<font color=\"" + colour + "\">" + body + "</font>";
        }

        return out;
    }

    // ------------------------------------------------------------- geometry

    // Monocraft is monospace, so ONE glyph's advance is every glyph's advance
    // and the whole layout is arithmetic from here. Measuring the longest line
    // with a TextMetrics would mean laying out every line in the document to
    // find out how wide the widest one is.
    TextMetrics {
        id: cell

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "0"
    }

    readonly property real cellWidth: cell.advanceWidth

    // As many cells as the biggest line number has digits. Derived, so it is
    // right at nine lines and at ninety thousand without anyone choosing a width.
    readonly property real gutterWidth: root.gutter ? String(root.lineCount).length * root.cellWidth : 0
    readonly property real textLeft: root.gutterWidth + (root.gutter ? Appearance.padding.small : 0)
    readonly property real textWidth: root.width - root.textLeft

    // The document's width in CELLS, tabs expanded the same way the markup
    // expands them, so the scroll extent and the drawn line agree. Skipped
    // entirely while wrapping, where there is no sideways to scroll.
    readonly property int widestColumns: {
        if (root.wrap)
            return 0;
        let widest = 0;
        const ls = root.lines;
        for (let i = 0; i < ls.length; i++) {
            const line = ls[i];
            let w = line.length;
            // The slow path only for the lines that need it.
            if (line.indexOf("\t") >= 0) {
                w = 0;
                for (let j = 0; j < line.length; j++)
                    w += line[j] === "\t" ? root.tabWidth - w % root.tabWidth : 1;
            }
            if (w > widest)
                widest = w;
        }
        return widest;
    }

    readonly property real contentWidth: root.widestColumns * root.cellWidth
    readonly property real maxPan: root.wrap ? 0 : Math.max(0, root.contentWidth - root.textWidth)

    // WHERE THE TEXT IS, sideways. A property rather than a second Flickable
    // wrapped around the list: the gutter must not move when the code does, and
    // a Flickable scrolls everything inside it or nothing. Here the offset is
    // applied to the code inside each row and the numbers simply never see it.
    property real panTarget: 0
    readonly property real panX: Math.max(0, Math.min(pan.value, root.maxPan))

    function clampPan(x: real): real {
        return Math.max(0, Math.min(x, root.maxPan));
    }

    // The same glide the list scrolls with, on the other axis; see
    // components/Follow.qml and ~/.claude/rules/animation-smoothing.md.
    Follow {
        id: pan

        speed: Appearance.anim.scrollSpeed
        epsilon: 0.5
        target: root.panTarget
    }

    // The viewport got narrower, or the content did. Nothing else moves the
    // text, so a view left scrolled past the end of a line it no longer has
    // would simply stay there showing nothing.
    onMaxPanChanged: {
        const inside = root.clampPan(root.panTarget);
        if (inside !== root.panTarget) {
            root.panTarget = inside;
            pan.value = inside;
        }
    }

    // New text is a new document. Watching it scroll back from wherever the last
    // one happened to be is motion that means nothing; GlideList.reset() makes
    // the same argument about the other axis.
    onTextChanged: {
        root.panTarget = 0;
        pan.value = 0;
        if (view)
            view.reset();
    }

    // ----------------------------------------------------------------- parts

    // WHY THERE IS NO COLOUR, said once, where the missing colour is.
    // Silently dropping it would read as a highlighter that does not work.
    G2Rect {
        id: notice

        anchors.left: parent.left
        anchors.top: parent.top

        visible: !root.coloured
        width: label.implicitWidth + Appearance.padding.normal * 2
        // Zero rather than hidden-with-height, because the list anchors to the
        // bottom of this and an invisible strip would still hold the room.
        height: root.coloured ? 0 : label.implicitHeight + Appearance.padding.small * 2

        radius: Appearance.rounding.small
        color: Appearance.colour.fill

        StyledText {
            id: label

            anchors.centerIn: parent
            color: Appearance.colour.textDim
            text: root.lineCount + " lines: colour stops past " + root.maxLines
        }
    }

    GlideList {
        id: view

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: notice.bottom
        anchors.topMargin: root.coloured ? 0 : Appearance.padding.small
        anchors.bottom: parent.bottom

        clip: true
        model: root.rows

        // A wheel notch throws the text sideways exactly as far as it throws the
        // list downward, because it is the same gesture on the other axis.
        //
        // A SECOND WheelHandler on the same item as GlideList's own. Qt offers a
        // wheel event to every handler an item carries rather than stopping at
        // the first one that accepts it, so this sees the event even though the
        // list has already claimed it, and the two never collide: that one reads
        // the y deltas and this one reads the x. If a Qt version ever did stop
        // early, the loss is horizontal WHEEL scrolling and nothing else, since
        // the drag below is a separate path.
        WheelHandler {
            enabled: root.maxPan > 0

            onWheel: event => {
                const pixels = event.pixelDelta.x;
                if (pixels !== 0) {
                    // Fingers are a position, not a request: they move the text
                    // directly, the way GlideList's own handler does.
                    root.panTarget = root.clampPan(pan.value - pixels);
                    pan.value = root.panTarget;
                    return;
                }

                const notches = event.angleDelta.x / 120;
                if (notches !== 0)
                    root.panTarget = root.clampPan((pan.settled ? pan.value : root.panTarget) - notches * view.step);
            }
        }

        // Drag the text sideways. HORIZONTAL ONLY, so a vertical drag never
        // reaches the threshold here and the list keeps its own drag, its flick
        // and its rubber band.
        //
        // The grab permissions drop every "approves takeover" flag Qt sets by
        // default. Flickable steals a grab from a handler the moment it thinks a
        // drag is its own, and it thinks that about a drag which started inside
        // it, which is all of them: without this the pan would hand itself to
        // the list a few pixels in and the text would stop moving mid-gesture.
        DragHandler {
            enabled: root.maxPan > 0
            target: null
            yAxis.enabled: false
            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType

            property real origin: 0

            onActiveChanged: if (active)
                origin = root.panTarget

            onActiveTranslationChanged: {
                if (!active)
                    return;
                root.panTarget = root.clampPan(origin - activeTranslation.x);
                pan.value = root.panTarget;
            }
        }

        delegate: Item {
            id: row

            required property int index
            required property var modelData

            width: view.width
            implicitHeight: body.implicitHeight

            StyledText {
                id: lineNo

                visible: root.gutter
                width: root.gutterWidth
                horizontalAlignment: Text.AlignRight
                color: Appearance.colour.textFaint
                text: row.index + 1
            }

            Item {
                x: root.textLeft
                width: row.width - root.textLeft
                height: row.height

                // A clip per visible row is a scissor per visible row, so it is
                // only paid for when there is something to protect: the list
                // already clips its own edges, and without a gutter there is
                // nothing on the left for a panned line to run over.
                clip: root.gutter && !root.wrap

                StyledText {
                    id: body

                    x: -root.panX
                    // Every row is as wide as the WIDEST row, which is what the
                    // pan is measured against. Sizing each row to its own text
                    // would make the same offset mean a different place on every
                    // line.
                    width: root.wrap ? parent.width : root.contentWidth
                    wrapMode: root.wrap ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap

                    textFormat: Text.StyledText
                    color: root.inkPlain
                    text: root.markup(row.modelData)
                }
            }
        }
    }
}
