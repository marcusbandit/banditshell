import QtQuick
import qs.config
import qs.components
import "../../services/mixer.js" as Logic
import "../../components/wheel-pass.js" as WheelPass

Item {
    id: root

    property real value: 0
    property real to: 1
    property real step: 0.05
    property real peak: 0
    property bool live: true
    property bool dimmed: false
    property color lit: Appearance.huedOr(Appearance.hue.sound, Appearance.colour.accent)

    signal moved(real value)

    readonly property real track: Math.max(8, Math.round(Appearance.sizes.sliderHeight * 1.6))
    readonly property real handleWidth: Math.max(4, Math.round(root.track / 2))
    readonly property real travel: Math.max(1, root.width - root.handleWidth)
    readonly property real fraction: Math.max(0, Math.min(1, root.value / Math.max(0.0001, root.to)))
    readonly property real shown: pointer.pressed ? root.dragged : glide.value
    readonly property real handleX: root.shown * root.travel
    readonly property real level: root.live && !root.dimmed ? Logic.meter(root.peak) : 0

    property real dragged: 0

    implicitHeight: root.track + Appearance.padding.normal * 2
    implicitWidth: Appearance.sizes.menuWidth / 2

    function ask(v: real): void {
        const wanted = Math.max(0, Math.min(root.to, v));
        root.dragged = wanted / Math.max(0.0001, root.to);
        glide.value = root.dragged;
        root.moved(wanted);
    }

    Follow {
        id: glide

        target: root.fraction
        speed: Appearance.animation.trackSpeed
        epsilon: 0.001
    }

    Follow {
        id: meter

        target: root.level
        speed: meter.value < root.level ? 40 : 6
        epsilon: 0.002
    }

    SquircleRect {
        id: rail

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.track
        pill: "place"
        color: Appearance.colour.fill

        SquircleRect {
            width: root.handleX + root.handleWidth / 2
            height: parent.height
            pill: "place"
            color: root.dimmed ? Appearance.colour.fill : Appearance.colour.fillStronger
        }

        SquircleRect {
            width: Math.round((root.handleX + root.handleWidth / 2) * meter.value)
            height: parent.height
            visible: width >= 2
            pill: "place"
            color: root.lit
        }

        SquircleRect {
            visible: root.to > 1
            x: root.travel / root.to + root.handleWidth / 2 - width / 2
            width: 2
            height: parent.height
            pill: "object"
            color: Appearance.colour.textFaint
        }
    }

    SquircleRect {
        x: root.handleX
        anchors.verticalCenter: parent.verticalCenter
        width: root.handleWidth
        height: root.track + Appearance.padding.normal
        pill: "object"
        color: root.dimmed ? Appearance.colour.textFaint : Appearance.colour.text
        scale: pointer.pressed || pointer.containsMouse ? 1.15 : 1

        FocusMark {
            shown: root.activeFocus
            pill: "object"
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        anchors.leftMargin: -Appearance.padding.small
        anchors.rightMargin: -Appearance.padding.small
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        function report(mx: real): void {
            const f = (pointer.mapToItem(root, mx, 0).x - root.handleWidth / 2) / root.travel;
            root.ask(Math.max(0, Math.min(1, f)) * root.to);
        }

        onPressed: mouse => report(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                report(mouse.x);
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y === 0 || WheelPass.passes(root, root.activeFocus, pointer.pressed)) {
                wheel.accepted = false;
                return;
            }
            root.ask(root.value + wheel.angleDelta.y / 120 * root.step);
        }
    }
}
