import QtQuick
import qs.config
import qs.components
import qs.modules.controls

Item {
    id: root

    property string icon: ""
    property string tip: ""
    property bool on: false
    property bool turned: false
    property real size: 36
    property color tint: Appearance.colour.textFaint

    signal clicked

    readonly property bool hovered: pointer.containsMouse && root.enabled

    implicitWidth: root.size
    implicitHeight: root.size

    opacity: root.enabled ? 1 : Appearance.opacity.disabled

    SquircleRect {
        anchors.fill: parent
        radius: height / 2
        cornerPower: 2
        color: root.on ? Appearance.colour.accentFill : Appearance.colour.fill
        opacity: backdrop.value

        Follow {
            id: backdrop

            target: root.on || root.hovered ? 1 : 0
            speed: Appearance.animation.revealSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        fill: root.on ? 1 : 0
        color: glyphTone.value
        rotation: flip.value

        Follow {
            id: flip

            target: root.turned ? 180 : 0
            speed: Appearance.animation.trackSpeed
            startsAtTarget: true
        }

        FollowColour {
            id: glyphTone

            target: root.on ? Appearance.colour.accent : root.hovered ? Appearance.colour.text : root.tint
            speed: Appearance.animation.revealSpeed
        }
    }

    scale: press.value

    Follow {
        id: press

        target: pointer.pressed && root.enabled ? 0.92 : 1
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    HoverTip {
        host: root
        text: root.tip
        asked: pointer.containsMouse
    }
}
