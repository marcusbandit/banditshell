pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string hours: "00"

    property string minutes: "00"

    property string suffix: ""

    property bool stacked: false

    property real size: 128

    property string family: Appearance.font.lock

    property color color: Appearance.colour.text

    property real weight: 600

    property real lean: 0

    property point pointer: Qt.point(-100000, -100000)

    readonly property real reach: root.size * 0.8
    readonly property real advance: figure.advanceWidth
    readonly property real colonAdvance: colon.advanceWidth
    readonly property real lineStep: Math.round(root.size * 0.86)
    readonly property real lineHeight: metrics.height

    readonly property var slots: {
        const a = root.advance;
        const c = root.colonAdvance;
        if (root.stacked)
            return [
                { text: root.hours.charAt(0), x: 0, y: 0, w: a },
                { text: root.hours.charAt(1), x: a, y: 0, w: a },
                { text: "", x: 0, y: 0, w: 0 },
                { text: root.minutes.charAt(0), x: 0, y: root.lineStep, w: a },
                { text: root.minutes.charAt(1), x: a, y: root.lineStep, w: a }
            ];
        return [
            { text: root.hours.charAt(0), x: 0, y: 0, w: a },
            { text: root.hours.charAt(1), x: a, y: 0, w: a },
            { text: ":", x: a * 2, y: 0, w: c },
            { text: root.minutes.charAt(0), x: a * 2 + c, y: 0, w: a },
            { text: root.minutes.charAt(1), x: a * 3 + c, y: 0, w: a }
        ];
    }

    implicitWidth: (root.stacked ? root.advance * 2 : root.advance * 4 + root.colonAdvance) + (tail.visible && !root.stacked ? Appearance.padding.small + tail.implicitWidth : 0)
    implicitHeight: (root.stacked ? root.lineStep : 0) + metrics.ascent + (tail.visible && root.stacked ? tail.implicitHeight : 0)

    FontMetrics {
        id: metrics

        font.family: root.family
        font.pixelSize: root.size
    }

    TextMetrics {
        id: figure

        font.family: root.family
        font.pixelSize: root.size
        font.features: ({ "tnum": 1 })
        text: "0"
    }

    TextMetrics {
        id: colon

        font.family: root.family
        font.pixelSize: root.size
        font.features: ({ "case": 1 })
        text: ":"
    }

    Repeater {
        model: 5

        delegate: Item {
            id: glyph

            required property int index

            readonly property var slot: root.slots[glyph.index]
            readonly property string want: glyph.slot.text

            property string shown: ""

            function settle(): void {
                if (glyph.want !== glyph.shown && turn.value < 0.04)
                    glyph.shown = glyph.want;
            }

            onWantChanged: glyph.settle()
            Component.onCompleted: glyph.settle()

            x: glyph.slot.x
            y: glyph.slot.y
            width: glyph.slot.w
            height: root.lineHeight

            Follow {
                id: turn

                target: glyph.want === glyph.shown ? 1 : 0
                speed: Appearance.animation.revealSpeed * 0.45
                epsilon: 0.002

                onValueChanged: glyph.settle()
            }

            Follow {
                id: near

                target: {
                    const dx = root.pointer.x - (glyph.x + glyph.width / 2);
                    const dy = root.pointer.y - (glyph.y + glyph.height / 2);
                    return Math.exp(-(dx * dx + dy * dy) / (2 * root.reach * root.reach));
                }
                speed: Appearance.animation.trackSpeed * 0.5
                epsilon: 0.002
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter

                text: glyph.shown
                color: root.color
                opacity: turn.value

                font.family: root.family
                font.pixelSize: root.size
                font.features: ({ "tnum": 1, "case": 1 })
                font.variableAxes: ({
                        "wght": Math.max(100, Math.min(900, (root.weight + root.lean * near.value) * (0.25 + 0.75 * turn.value))),
                        "opsz": 32
                    })
                renderType: Text.NativeRendering
            }
        }
    }

    Text {
        id: tail

        visible: root.suffix !== ""
        x: root.stacked ? (root.advance * 2 - tail.implicitWidth) / 2 : root.advance * 4 + root.colonAdvance + Appearance.padding.small
        y: root.stacked ? root.lineStep + metrics.ascent : metrics.ascent - tail.baselineOffset

        text: root.suffix
        color: root.color
        opacity: 0.6
        font.family: root.family
        font.pixelSize: Appearance.font.size.small
        font.variableAxes: ({ "wght": root.weight })
    }
}
