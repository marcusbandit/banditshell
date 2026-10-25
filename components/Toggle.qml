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
        stroke: edgeTone.value
        strokeWidth: Appearance.stroke.ring

        FollowColour {
            id: trackTone

            target: root.checked ? Appearance.colour.accent : Appearance.colour.fill
            speed: Appearance.animation.revealSpeed
        }

        FollowColour {
            id: edgeTone

            target: root.checked ? Appearance.colour.accent : Appearance.colour.textFaint
            speed: Appearance.animation.revealSpeed
        }
    }

    SquircleRect {
        id: knob

        readonly property real gap: Appearance.stroke.ring + Math.max(1, Math.round(root.height / 18))

        y: knob.gap
        x: slide.value
        width: root.height - knob.gap * 2
        height: width
        pill: "object"
        color: knobTone.value

        FollowColour {
            id: knobTone

            target: root.checked ? Appearance.colour.accentText : Appearance.colour.textDim
            speed: Appearance.animation.revealSpeed
        }

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
