pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property bool playing: false
    property color color: Appearance.colour.text
    property real size: Appearance.font.iconSize * 0.7

    readonly property real bar: Math.max(2, Math.round(root.size / 5))

    implicitWidth: root.bar * 3 + root.bar * 2
    implicitHeight: root.size

    Follow {
        id: swell

        target: root.playing ? 1 : 0
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.004
    }

    QtObject {
        id: clock

        property real t: 0
    }

    NumberAnimation {
        target: clock
        property: "t"
        from: 0
        to: Math.PI * 2
        duration: 1400
        loops: Animation.Infinite
        running: root.visible && root.playing && !Appearance.lessMotion
    }

    Repeater {
        model: 3

        SquircleRect {
            required property int index

            readonly property real wave: 0.5 + 0.5 * Math.sin(clock.t * (index === 1 ? 2 : 3) + index * 2.1)
            readonly property real reach: 0.28 + 0.72 * wave * swell.value

            x: index * root.bar * 2
            y: root.height - height
            width: root.bar
            height: Math.max(root.bar, root.height * reach)
            radius: root.bar / 2
            color: root.color
        }
    }
}
