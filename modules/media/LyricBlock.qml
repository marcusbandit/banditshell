pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
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
    readonly property var widths: root.space > 0 ? root.words.map(w => metrics.advanceWidth(w.text)) : []
    readonly property var rows: Lyrics.layout(root.widths, root.space, Math.max(1, root.width))
    readonly property real rowHeight: Math.round(root.pixelSize * Appearance.font.leading)

    implicitHeight: root.rows.length * root.rowHeight

    function rowText(row: var): string {
        return root.words.slice(row.first, row.first + row.count).map(w => w.text).join(" ");
    }

    Follow {
        id: glow

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
        visible: glow.value > 0.004
        opacity: glow.value

        layer.enabled: visible && GraphicsInfo.api !== GraphicsInfo.Software
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Appearance.withAlpha(root.bright, 0.5)
            shadowBlur: 0.45
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 0
            autoPaddingEnabled: true
        }

        Repeater {
            model: glow.value > 0.004 ? root.rows : []

            delegate: Item {
                id: row

                required property var modelData
                required property int index

                x: root.opposite ? root.width - row.modelData.width : 0
                y: row.index * root.rowHeight
                width: Lyrics.litWidth(row.modelData, root.widths, root.held)
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
