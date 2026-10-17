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
        opacity: root.on || root.hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.fade.fast
            }
        }
    }

    Icon {
        anchors.centerIn: parent
        name: root.icon
        fill: root.on ? 1 : 0
        color: root.on ? Appearance.colour.accent : root.hovered ? Appearance.colour.text : root.tint
        rotation: root.turned ? 180 : 0

        Behavior on rotation {
            NumberAnimation {
                duration: Appearance.animation.normal
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.fast
            }
        }
    }

    scale: pointer.pressed && root.enabled ? 0.92 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animation.fast
        }
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
