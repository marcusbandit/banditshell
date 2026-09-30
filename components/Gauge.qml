pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property real value: 0

    property real mark: -1

    property color fill: Appearance.colour.accent
    property color track: Appearance.colour.fillStronger
    property color notch: Appearance.colour.text

    implicitHeight: Appearance.padding.small

    readonly property real fraction: Math.max(0, Math.min(1, root.value))

    SquircleRect {
        anchors.fill: parent
        radius: root.height / 2
        color: root.track
    }

    SquircleRect {

        width: Math.max(root.height, root.width * root.fraction)
        height: root.height
        radius: root.height / 2
        color: root.fill
    }

    Rectangle {
        visible: root.mark >= 0 && root.mark <= 1

        readonly property real span: root.width - root.height
        x: root.height / 2 + span * Math.max(0, Math.min(1, root.mark)) - width / 2

        width: Math.max(1, Math.round(root.height / 3))
        height: root.height
        color: root.notch
    }
}
