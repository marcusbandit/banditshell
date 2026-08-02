import QtQuick
import qs.config

// A LAYER: the things you rarely need, one step under the row they belong to.
//
// The pattern every long menu in this shell ends up wanting. A list of devices,
// or networks, is a list of one-line answers to "which one"; everything else
// about any of them is a page of switches nobody asked for. This holds that page
// folded up under its row, and only one of them is ever open, which is what keeps
// a menu a menu rather than a settings window.
//
// It UNROLLS rather than appearing, and it is clipped while it does, so the rows
// inside are revealed by the opening instead of arriving already there. The rule
// down the left is the whole reason it reads as belonging to the row above it
// rather than as the next section: indentation alone says "further right", and a
// line says "inside".
//
// Anything declared inside goes in the stack, in order.
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

    G2Rect {
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
