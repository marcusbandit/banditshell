import QtQuick
import qs.config

Item {
    id: root

    property bool checked: false

    signal toggled

    property bool keyable: true

    function press(): void {
        root.toggled();
    }

    implicitWidth: Appearance.sizes.toggleWidth
    implicitHeight: Appearance.sizes.toggleHeight

    Follow {
        id: lit

        target: root.checked ? 1 : 0
        speed: Appearance.animation.snapSpeed
        epsilon: 0.01
        startsAtTarget: true
    }

    SquircleRect {
        anchors.fill: parent
        pill: "place"
        color: Appearance.blend(Appearance.colour.fill, Appearance.colour.accent, lit.value)
        stroke: Appearance.blend(Appearance.colour.textFaint, Appearance.colour.accent, lit.value)
        strokeWidth: Appearance.stroke.ring
    }

    FocusMark {
        shown: root.activeFocus
        pill: "place"
    }

    SquircleRect {
        id: knob

        readonly property real gap: Appearance.stroke.ring + Math.max(1, Math.round(root.height / 18))

        y: knob.gap
        x: knob.gap + (root.width - knob.width - knob.gap * 2) * lit.value
        width: root.height - knob.gap * 2
        height: width
        pill: "object"
        color: Appearance.blend(Appearance.colour.textDim, Appearance.colour.accentText, lit.value)
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
