pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import "highlight.js" as Highlight

Item {
    id: root

    property string text: ""

    property string language: ""

    property bool wrap: false

    property int maxLines: 2000

    property bool gutter: false

    property int tabWidth: 4

    readonly property var lines: root.text.split("\n")
    readonly property int lineCount: root.lines.length
    readonly property string resolvedLanguage: root.language !== "" ? root.language : Highlight.detect(root.text)

    readonly property bool coloured: root.lineCount <= root.maxLines

    readonly property var rows: root.coloured ? Highlight.tokenize(root.text, root.resolvedLanguage) : root.lines

    readonly property color inkString: Appearance.rampAt(8, 1)

    readonly property color inkPlain: Appearance.colour.text

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

    function markup(row: var): string {

        if (row === undefined || row === null)
            return "";

        const spans = typeof row === "string" ? [{
                k: "plain",
                s: row
            }] : row;

        let out = "";
        let column = 0;

        let afterSpace = true;

        for (let i = 0; i < spans.length; i++) {
            const span = spans[i];
            const s = span.s;
            let body = "";

            for (let j = 0; j < s.length; j++) {
                const c = s[j];

                if (c === "\t") {

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

    TextMetrics {
        id: cell

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "0"
    }

    readonly property real cellWidth: cell.advanceWidth

    readonly property real gutterWidth: root.gutter ? String(root.lineCount).length * root.cellWidth : 0
    readonly property real textLeft: root.gutterWidth + (root.gutter ? Appearance.padding.small : 0)
    readonly property real textWidth: root.width - root.textLeft

    readonly property int widestColumns: {
        if (root.wrap)
            return 0;
        let widest = 0;
        const ls = root.lines;
        for (let i = 0; i < ls.length; i++) {
            const line = ls[i];
            let w = line.length;

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

    property real panTarget: 0
    readonly property real panX: Math.max(0, Math.min(pan.value, root.maxPan))

    function clampPan(x: real): real {
        return Math.max(0, Math.min(x, root.maxPan));
    }

    Follow {
        id: pan

        speed: Appearance.anim.scrollSpeed
        epsilon: 0.5
        target: root.panTarget
    }

    onMaxPanChanged: {
        const inside = root.clampPan(root.panTarget);
        if (inside !== root.panTarget) {
            root.panTarget = inside;
            pan.value = inside;
        }
    }

    onTextChanged: {
        root.panTarget = 0;
        pan.value = 0;
        if (view)
            view.reset();
    }

    SquircleRect {
        id: notice

        anchors.left: parent.left
        anchors.top: parent.top

        visible: !root.coloured
        width: label.implicitWidth + Appearance.padding.normal * 2

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

        WheelHandler {
            enabled: root.maxPan > 0

            onWheel: event => {
                const pixels = event.pixelDelta.x;
                if (pixels !== 0) {

                    root.panTarget = root.clampPan(pan.value - pixels);
                    pan.value = root.panTarget;
                    return;
                }

                const notches = event.angleDelta.x / 120;
                if (notches !== 0)
                    root.panTarget = root.clampPan((pan.settled ? pan.value : root.panTarget) - notches * view.step);
            }
        }

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

                clip: root.gutter && !root.wrap

                StyledText {
                    id: body

                    x: -root.panX

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
