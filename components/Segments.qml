pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property var options: []

    property int current: 0

    property var swatches: []

    property bool fit: false

    property real zoom: 1

    readonly property int textSize: Math.round(Appearance.font.size.small * root.zoom)
    readonly property real pad: Math.round(Appearance.padding.normal * root.zoom)

    signal picked(int index)

    readonly property bool keyable: root.count > 1
    readonly property string adjusts: "horizontal"

    function adjust(steps: int): void {
        const to = Math.max(0, Math.min(root.count - 1, root.current + steps));
        if (to !== root.current)
            root.picked(to);
    }

    readonly property int count: root.options.length

    readonly property real segment: root.count > 0 ? root.width / root.count : root.width

    readonly property real swatchRoom: root.swatches.length > 0 ? 18 + Appearance.padding.small : 0

    readonly property var widths: {
        ink.font;
        return root.options.map(o => Math.ceil(ink.advanceWidth(o)) + root.swatchRoom + root.pad * 2);
    }
    readonly property real natural: root.count * root.widths.reduce((a, b) => Math.max(a, b), 0)
    readonly property real compact: root.widths.reduce((a, b) => a + b, 0)

    function segmentX(i: int): real {
        return root.fit ? root.widths.slice(0, i).reduce((a, b) => a + b, 0) : i * root.segment;
    }

    function segmentWidth(i: int): real {
        return root.fit ? root.widths[i] ?? 0 : root.segment;
    }

    implicitWidth: root.fit ? root.compact : root.natural
    implicitHeight: Math.max(Appearance.sizes.minTarget, Math.round((Appearance.font.line.small + Appearance.padding.small * 2) * root.zoom))
    width: implicitWidth
    height: implicitHeight

    FontMetrics {
        id: ink

        font.family: Appearance.font.family
        font.pixelSize: root.textSize
    }

    Follow {
        id: slide

        speed: Appearance.animation.trackSpeed
        target: root.segmentX(root.current)
    }

    Follow {
        id: span

        speed: Appearance.animation.trackSpeed
        target: root.segmentWidth(root.current)
    }

    function settle(): void {
        slide.snap();
        span.snap();
    }

    Component.onCompleted: root.settle()
    onSegmentChanged: root.settle()
    onFitChanged: root.settle()
    onWidthsChanged: root.settle()

    SquircleRect {
        anchors.fill: parent
        pill: "place"
        color: Appearance.colour.fillStrong
    }

    SquircleRect {
        x: slide.value
        width: span.value
        height: parent.height
        pill: "place"
        color: Appearance.colour.accent
        visible: root.current >= 0 && root.current < root.count
    }

    FocusMark {
        shown: root.activeFocus
        pill: "place"
    }

    Repeater {
        model: root.options

        delegate: Item {
            id: seg

            required property string modelData
            required property int index

            readonly property real covered: seg.width > 0 ? Math.max(0, 1 - Math.abs(slide.value - seg.x) / seg.width) : 0

            x: root.segmentX(seg.index)
            width: root.segmentWidth(seg.index)
            height: root.height

            StyledText {
                id: label

                anchors.fill: parent
                leftPadding: root.swatchRoom

                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                text: seg.modelData
                font.pixelSize: root.textSize

                color: seg.covered > 0.5 ? Appearance.colour.accentText : Appearance.colour.text
            }

            SquircleRect {
                x: (seg.width - root.swatchRoom - label.contentWidth) / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 6
                color: root.swatches[seg.index] ?? "transparent"
                stroke: label.color
                strokeWidth: seg.covered > 0.5 ? 1.5 : 0
                visible: root.swatchRoom > 0
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: root.picked(seg.index)
            }
        }
    }
}
