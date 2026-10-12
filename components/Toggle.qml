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
                duration: Appearance.anim.fast
            }
        }
    }

    SquircleRect {
        id: knob

        readonly property real gap: Math.max(2, Math.round(root.height / 9))

        y: knob.gap
        x: root.checked ? parent.width - width - knob.gap : knob.gap
        width: root.height - knob.gap * 2
        height: width
        radius: height / 2
        color: root.checked ? Appearance.colour.accentText : Appearance.colour.text

        Behavior on x {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
