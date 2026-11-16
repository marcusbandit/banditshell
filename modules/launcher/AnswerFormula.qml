import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var parts: null
    property real available: 0
    property color colour: Appearance.colour.text

    readonly property int display: Appearance.font.size.display
    readonly property var list: root.parts ?? []
    readonly property int tallest: root.list.reduce((most, part) => Math.max(most, part.kind === "matrix" ? part.rows.length : 1), 1)
    readonly property int brackets: root.list.filter(part => part.kind === "matrix").length * 2
    readonly property real natural: root.list.reduce((sum, part, i) => sum + root.lead(part, i) * root.display + root.inked(part), 0)
    readonly property int size: root.list.length ? Math.floor(Math.min(root.display, root.display * 3 / root.tallest, root.display * (root.available - Appearance.stroke.ring * root.brackets) / root.natural)) : 0
    readonly property bool shown: root.list.length > 0 && root.size >= Appearance.font.size.small * 0.75
    readonly property int line: Math.round(root.size * Appearance.font.leading)

    function lead(part: var, i: int): real {
        return i === 0 ? 0 : part.kind === "power" ? 0.05 : 0.3;
    }

    function inked(part: var): real {
        if (part.kind === "power")
            return metrics.advanceWidth(part.text) * 0.6;
        if (part.kind !== "matrix")
            return metrics.advanceWidth(part.text);
        let sum = 0;
        for (let c = 0; c < part.rows[0].length; c++)
            sum += part.rows.reduce((widest, row) => Math.max(widest, metrics.advanceWidth(row[c])), 0);
        return sum + root.display * (0.7 * (part.rows[0].length - 1) + 0.7 + 1 / 6);
    }

    function tall(part: var): int {
        return part && part.kind === "matrix" ? part.rows.length * root.line : root.line;
    }

    visible: root.shown
    width: row.width
    height: root.tallest * root.line

    FontMetrics {
        id: metrics

        font.family: Appearance.font.family
        font.pixelSize: root.display
        font.weight: Font.DemiBold
    }

    Row {
        id: row

        height: root.height

        Repeater {
            model: root.shown ? root.list : []

            delegate: Item {
                id: piece

                required property var modelData
                required property int index

                readonly property bool raised: piece.modelData.kind === "power"
                readonly property int base: root.tall(piece.index > 0 ? root.list[piece.index - 1] : null)

                width: Math.round(root.lead(piece.modelData, piece.index) * root.size) + (piece.modelData.kind === "matrix" ? matrix.width : words.implicitWidth)
                height: root.height

                AnswerMatrix {
                    id: matrix

                    visible: piece.modelData.kind === "matrix"
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    rows: piece.modelData.kind === "matrix" ? piece.modelData.rows : []
                    size: root.size
                    colour: root.colour
                }

                StyledText {
                    id: words

                    visible: piece.modelData.kind !== "matrix"
                    anchors.right: parent.right
                    y: piece.raised ? Math.max(0, (root.height - piece.base) / 2 - Math.round(root.size * 0.1)) : (root.height - height) / 2
                    text: piece.modelData.kind === "matrix" ? "" : piece.modelData.text
                    font.pixelSize: piece.raised ? Math.round(root.size * 0.6) : root.size
                    font.weight: Font.DemiBold
                    color: root.colour
                }
            }
        }
    }
}
