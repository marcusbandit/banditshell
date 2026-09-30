import QtQuick
import qs.config

Item {
    id: root

    property bool open: false
    readonly property real indent: Appearance.padding.large

    default property alias content: stack.data

    clip: true
    visible: unroll.value > 0.001
    implicitHeight: stack.implicitHeight * unroll.value

    Follow {
        id: unroll

        target: root.open ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.001
    }

    SquircleRect {
        x: Math.round(root.indent / 2)
        width: Math.max(2, Math.round(Appearance.sizes.sliderHeight / 3))
        height: parent.height
        radius: width / 2
        color: Appearance.colour.separator
    }

    Column {
        id: stack

        x: root.indent
        width: root.width - root.indent
        spacing: 0
    }
}
