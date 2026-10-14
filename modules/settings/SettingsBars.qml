import QtQuick
import qs.config
import qs.components

Row {
    id: root

    property int lit: 4
    property int count: 4
    property real barWidth: 3
    property real step: 3.5
    property real round: 1
    property color colour: Appearance.colour.textDim

    spacing: 2

    Repeater {
        model: root.count

        delegate: SquircleRect {
            required property int index

            anchors.bottom: parent.bottom
            width: root.barWidth
            height: Math.round(root.step * (index + 1))
            radius: root.round
            cornerPower: 2
            color: root.colour
            opacity: index < root.lit ? 1 : 0.28
        }
    }
}
