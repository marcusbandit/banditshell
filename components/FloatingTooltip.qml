import QtQuick
import qs.config

Item {
    id: root

    property string text: ""
    property bool shown: false
    property real gap: Appearance.padding.small

    property bool up: false

    x: Math.round((root.parent.width - root.width) / 2)
    y: -root.height - root.gap
    z: 100
    width: label.implicitWidth + Appearance.padding.normal * 2
    height: label.implicitHeight + Appearance.padding.small * 2

    opacity: root.up ? 1 : 0
    visible: root.opacity > 0
    scale: root.up ? 1 : 0.94
    transformOrigin: Item.Bottom

    onShownChanged: if (!root.shown)
        root.up = false

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.animation.fast
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Appearance.animation.fast
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        interval: Appearance.animation.tooltip
        running: root.shown && root.text !== ""
        onTriggered: root.up = true
    }

    DropShadow {
        anchors.fill: parent
        radius: Appearance.rounding.small
        blur: Appearance.padding.normal
        offset.y: Math.round(Appearance.padding.small / 2)
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.fillStrong
        strokeWidth: 1
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: Appearance.colour.text
    }
}
