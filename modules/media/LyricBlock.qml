pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property var words: []
    property int pixelSize: Appearance.font.size.normal
    property bool opposite: false

    property bool lit: false
    property real position: 0

    property color dim: Appearance.colour.textDim
    property color bright: Appearance.colour.text

    FontMetrics {
        id: metrics

        font.family: Appearance.font.family
        font.pixelSize: root.pixelSize
    }

    readonly property real space: metrics.font.pixelSize > 0 && metrics.font.family ? metrics.advanceWidth(" ") : 0
    readonly property var fitted: Lyrics.fit(root.space > 0 ? root.words.map(w => w.text) : [], text => metrics.advanceWidth(text), Math.max(1, root.width))
    readonly property var rows: Lyrics.layout(root.fitted.widths, root.space, Math.max(1, root.width), root.fitted.joined)
    readonly property real rowHeight: Math.round(root.pixelSize * Appearance.font.leading)

    implicitHeight: root.rows.length * root.rowHeight

    function rowText(row: var): string {
        return Lyrics.rowText(root.fitted, row);
    }

    Follow {
        id: fill

        target: root.lit ? 1 : 0
        speed: root.lit ? Appearance.animation.revealSpeed : Appearance.animation.revealSpeed * 0.35
        epsilon: 0.004
    }

    property real held: 0

    onPositionChanged: if (root.lit)
        root.held = root.position

    onLitChanged: if (root.lit)
        root.held = root.position

    Repeater {
        model: root.rows

        delegate: StyledText {
            required property var modelData
            required property int index

            x: root.opposite ? root.width - modelData.width : 0
            y: index * root.rowHeight
            text: root.rowText(modelData)
            font.pixelSize: root.pixelSize
            color: root.dim
        }
    }

    Item {
        anchors.fill: parent
        visible: fill.value > 0.004
        opacity: fill.value

        Repeater {
            model: fill.value > 0.004 ? root.rows : []

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                x: root.opposite ? root.width - row.modelData.width : 0
                y: row.index * root.rowHeight
                width: Lyrics.litWidth(row.modelData, root.fitted.widths, Lyrics.piecePosition(root.fitted, root.held))
                height: root.rowHeight
                clip: true
                visible: width > 0

                StyledText {
                    text: root.rowText(row.modelData)
                    font.pixelSize: root.pixelSize
                    color: root.bright
                }
            }
        }
    }
}
