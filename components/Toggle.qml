import QtQuick
import qs.config

Item {
    id: root

    property bool checked: false

    signal toggled

    implicitWidth: Appearance.sizes.toggleWidth
    implicitHeight: Appearance.sizes.toggleHeight

    SquircleRect {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Appearance.colour.accent : Appearance.colour.fillStrong

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.fast
            }
        }
    }

    SquircleRect {
        id: knob

        readonly property real gap: Math.max(2, Math.round(root.height / 9))

        y: knob.gap
        x: knob.gap + slide.value * (knob.parent.width - knob.width - knob.gap * 2)
        width: root.height - knob.gap * 2
        height: width
        radius: height / 2
        color: root.checked ? Appearance.colour.accentText : Appearance.colour.text

        Follow {
            id: slide

            target: root.checked ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: 0.005
            Component.onCompleted: slide.snap()
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
