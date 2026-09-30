pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property int border: Appearance.sizes.border

    readonly property int stackMax: 3
    readonly property var rows: Launching.shown.slice(-root.stackMax)
    readonly property bool out: root.rows.length > 0

    readonly property var verbs: ({
            waiting: "Opening",
            here: "Opened",
            lost: "Gave up on"
        })

    function tone(state: string): color {
        return state === "lost" ? Appearance.colour.alarm : Appearance.colour.accent;
    }

    readonly property real markSize: Appearance.sizes.launcherIcon

    readonly property int maxChars: 40
    readonly property int verbChars: Math.max(...Object.values(root.verbs).map(v => v.length))

    function charsFor(rec: var): int {
        return Math.min(root.maxChars, root.verbChars + 1 + (rec.name ?? "").length);
    }

    function textWidthFor(rec: var): real {
        return em.advanceWidth * root.charsFor(rec);
    }

    function pillWidthFor(rec: var): real {
        return Appearance.padding.huge * 2 + root.markSize + Appearance.padding.large + root.textWidthFor(rec);
    }

    readonly property real barHeight: Appearance.font.stem

    readonly property real lineHeight: em.height
    readonly property real contentHeight: Math.max(root.markSize, root.lineHeight + Appearance.padding.small + root.barHeight)

    readonly property real pillHeight: Appearance.padding.large * 2 + root.contentHeight + root.border

    readonly property real stackGap: Appearance.padding.small

    TextMetrics {
        id: em

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "0"
    }

    function slotY(slot: int): real {
        return root.height - root.pillHeight - slot * (root.pillHeight + root.stackGap);
    }

    function rowY(slot: int): real {
        const settled = root.slotY(slot);
        return settled + (root.height + Appearance.sizes.melt - settled) * (1 - rise.value);
    }

    function slotOf(i: int): int {
        return root.rows.length - 1 - i;
    }

    readonly property var blobs: rise.value <= 0.001 ? [] : root.rows.map((rec, i) => ({
                x: (root.width - root.pillWidthFor(rec)) / 2,
                y: root.rowY(root.slotOf(i)),
                w: root.pillWidthFor(rec),
                h: root.pillHeight,
                radius: Appearance.rounding.large
            }))

    Follow {
        id: rise

        speed: Appearance.anim.revealSpeed
        target: root.out ? 1 : 0
        epsilon: 0.005
    }

    Repeater {
        model: root.rows

        Item {
            id: pill

            required property int index
            required property var modelData

            readonly property real pillWidth: root.pillWidthFor(pill.modelData)
            readonly property real textWidth: root.textWidthFor(pill.modelData)

            x: (root.width - pill.pillWidth) / 2
            y: root.rowY(root.slotOf(pill.index))
            width: pill.pillWidth
            height: root.pillHeight
            opacity: rise.value

            Item {
                id: content

                x: Appearance.padding.huge
                y: Appearance.padding.large
                width: pill.pillWidth - Appearance.padding.huge * 2
                height: root.contentHeight

                AppMark {
                    id: art

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    spec: pill.modelData.mark
                    size: root.markSize
                    fallback: Apps.genericIcon

                    opacity: pill.modelData.state === "lost" ? 0.5 : 1
                }

                Column {
                    anchors.left: art.right
                    anchors.leftMargin: Appearance.padding.large
                    anchors.verticalCenter: parent.verticalCenter
                    width: pill.textWidth
                    spacing: Appearance.padding.small

                    Row {
                        spacing: em.advanceWidth

                        StyledText {
                            id: lead

                            text: root.verbs[pill.modelData.state] ?? root.verbs.waiting
                            color: root.tone(pill.modelData.state)
                        }

                        StyledText {
                            width: pill.textWidth - lead.width - em.advanceWidth
                            text: pill.modelData.name
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        width: pill.textWidth
                        height: root.barHeight

                        Rectangle {
                            anchors.fill: parent
                            color: Appearance.colour.fill
                        }

                        Rectangle {
                            width: parent.width * Launching.progress(pill.modelData)
                            height: parent.height
                            color: root.tone(pill.modelData.state)
                        }
                    }
                }
            }
        }
    }
}
