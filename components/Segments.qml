pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property var options: []

    property int current: 0

    signal picked(int index)

    readonly property int count: root.options.length

    readonly property real segment: root.count > 0 ? root.width / root.count : root.width

    readonly property string widest: {
        let out = "";
        for (const o of root.options)
            if (o.length > out.length)
                out = o;
        return out;
    }

    implicitWidth: root.count * (Math.ceil(ink.width) + Appearance.padding.normal * 2)
    implicitHeight: Math.max(Appearance.sizes.minTarget, Math.round(Appearance.font.size.small * 4 / 3) + Appearance.padding.small * 2)
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

        speed: Appearance.anim.trackSpeed
        target: root.current * root.segment
    }

    Component.onCompleted: slide.snap()

    G2Rect {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colour.fillStrong
    }

    G2Rect {
        x: slide.value
        width: root.segment
        height: parent.height
        radius: height / 2
        color: Appearance.colour.accentFill
        visible: root.count > 0
    }

    Repeater {
        model: root.options

        delegate: Item {
            id: seg

            required property string modelData
            required property int index

            x: seg.index * root.segment
            width: root.segment
            height: root.height

            StyledText {
                anchors.fill: parent

                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter

                text: seg.modelData

                color: seg.index === root.current ? Appearance.colour.text : Appearance.colour.textFaint
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: root.picked(seg.index)
            }
        }
    }
}
