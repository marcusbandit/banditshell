import QtQuick

Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property alias horizontalAlignment: label.horizontalAlignment

    property int maxLines: 6

    implicitHeight: label.implicitHeight
    implicitWidth: label.implicitWidth

    TextMetrics {
        id: ruler

        font: label.font
        text: "MMMMMMMMMM"
    }

    readonly property real advance: ruler.advanceWidth / ruler.text.length

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

        return Math.min(room, (narrowest + 0.5) * root.advance);
    }

    StyledText {
        id: label

        width: root.balanced
        wrapMode: Text.WordWrap
        maximumLineCount: root.maxLines
        elide: Text.ElideRight
    }
}
