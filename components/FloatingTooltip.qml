import QtQuick
import qs.config
import "tooltip-warmth.js" as Warmth

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

    opacity: rise.value
    visible: rise.value > 0.01 || rise.target > 0
    scale: 0.94 + 0.06 * rise.value
    transformOrigin: Item.Bottom

    onShownChanged: {
        if (!root.shown)
            root.up = false;
        else if (root.text !== "" && Warmth.warm(Appearance.animation.grace))
            root.up = true;
    }

    onUpChanged: root.up ? Warmth.opened() : Warmth.closed()

    Component.onDestruction: if (root.up)
        Warmth.closed()

    Follow {
        id: rise

        target: root.up ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
        startsAtTarget: true
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
        offset.y: Appearance.padding.hair
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colour.surfaceSolid
        stroke: Appearance.colour.fillStrong
        strokeWidth: Appearance.stroke.line
    }

    StyledText {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: Appearance.colour.text
    }
}
