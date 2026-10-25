pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property var options: []

    property int current: 0

    property var swatches: []

    signal picked(int index)

    readonly property int count: root.options.length

    readonly property real segment: root.count > 0 ? root.width / root.count : root.width

    readonly property real swatchRoom: root.swatches.length > 0 ? 14 + Appearance.padding.small : 0

    readonly property string widest: {
        let out = "";
        for (const o of root.options)
            if (o.length > out.length)
                out = o;
        return out;
    }

    implicitWidth: root.count * (Math.ceil(ink.width) + root.swatchRoom + Appearance.padding.normal * 2)
    implicitHeight: Math.max(Appearance.sizes.minTarget, Appearance.font.line.small + Appearance.padding.small * 2)
    width: implicitWidth
    height: implicitHeight

    TextMetrics {
        id: ink

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.widest
    }

    Follow {
        id: slide

        speed: Appearance.animation.trackSpeed
        target: root.current * root.segment
    }

    Component.onCompleted: slide.snap()
    onSegmentChanged: slide.snap()

    SquircleRect {
        anchors.fill: parent
        pill: "place"
        color: Appearance.colour.fillStrong
    }

    SquircleRect {
        x: slide.value
        width: root.segment
        height: parent.height
        pill: "place"
        color: Appearance.colour.accent
        visible: root.current >= 0 && root.current < root.count
    }

    Repeater {
        model: root.options

        delegate: Item {
            id: seg

            required property string modelData
            required property int index

            readonly property real covered: root.segment > 0 ? Math.max(0, 1 - Math.abs(slide.value - seg.x) / root.segment) : 0

            x: seg.index * root.segment
            width: root.segment
            height: root.height

            StyledText {
                id: label

                anchors.fill: parent
                leftPadding: root.swatchRoom

                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                text: seg.modelData

                color: seg.covered > 0.5 ? Appearance.colour.accentText : Appearance.colour.text
            }

            SquircleRect {
                x: (seg.width - root.swatchRoom - label.contentWidth) / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                height: 14
                radius: 5
                color: root.swatches[seg.index] ?? "transparent"
                stroke: Appearance.colour.surfaceSolid
                strokeWidth: 1
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
