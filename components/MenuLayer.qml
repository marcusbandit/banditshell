import QtQuick
import qs.config

Item {
    id: root

    property bool open: false
    readonly property real indent: Appearance.padding.large

    default property alias content: stack.data

    visible: unroll.value > 0.001
    implicitHeight: stack.implicitHeight * unroll.value

    Follow {
        id: unroll

        target: root.open ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
    }

    SquircleRect {
        x: Math.round(root.indent / 2)
        width: Math.max(2, Math.round(Appearance.sizes.sliderHeight / 3))
        height: parent.height
        pill: "place"
        color: Appearance.colour.separator
    }

    Item {
        id: fold

        readonly property real reach: Appearance.padding.hair

        readonly property real room: unroll.settled && root.open ? fold.reach : 0

        x: -fold.reach
        y: -fold.room
        width: root.width + fold.reach * 2
        height: root.height + fold.room * 2
        clip: true

        Column {
            id: stack

            x: root.indent + fold.reach
            y: fold.room
            width: root.width - root.indent
            spacing: 0
        }
    }
}
