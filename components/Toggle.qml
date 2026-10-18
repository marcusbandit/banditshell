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
        pill: "place"
        color: trackTone.value

        FollowColour {
            id: trackTone

            target: root.checked ? Appearance.colour.accent : Appearance.colour.fillStrong
            speed: Appearance.animation.revealSpeed
        }
    }

    SquircleRect {
        id: knob

        readonly property real gap: Math.max(2, Math.round(root.height / 9))

        y: knob.gap
        x: slide.value
        width: root.height - knob.gap * 2
        height: width
        pill: "object"
        color: root.checked ? Appearance.colour.accentText : Appearance.colour.text

        Follow {
            id: slide

            target: root.checked ? root.width - knob.width - knob.gap : knob.gap
            speed: Appearance.animation.snapSpeed
            startsAtTarget: true
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
