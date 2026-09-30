import QtQuick
import qs.config

Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1

    property real warnAbove: 1

    property real step: 0.05

    property bool dimmed: false

    signal moved(real value)

    readonly property real fraction: Math.max(0, Math.min(1, (value - from) / Math.max(0.0001, to - from)))
    readonly property bool active: pointer.pressed || pointer.containsMouse

    readonly property color lit: root.dimmed ? Appearance.colour.textFaint : root.value > root.warnAbove ? Appearance.colour.accent : Appearance.colour.text

    readonly property real rail: Appearance.sizes.sliderHeight

    readonly property real beadSize: root.enabled ? rail * 2.2 : 0
    readonly property real travel: Math.max(1, width - beadSize)
    readonly property real beadCentre: beadSize / 2 + root.shown * travel

    readonly property real detent: beadSize / 2

    function snap(v: real): real {
        if (root.warnAbove <= root.from || root.warnAbove >= root.to)
            return v;
        const perPixel = (root.to - root.from) / root.travel;
        return Math.abs(v - root.warnAbove) < root.detent * perPixel ? root.warnAbove : v;
    }

    property real dragged: 0
    readonly property real shown: pointer.pressed ? root.dragged : glide.value

    implicitHeight: Math.max(rail, beadSize * 1.35)
    implicitWidth: Appearance.sizes.menuWidth / 2

    function ask(v: real): void {
        const wanted = root.snap(Math.max(root.from, Math.min(root.to, v)));
        const f = (wanted - root.from) / Math.max(0.0001, root.to - root.from);
        root.dragged = f;
        glide.value = f;
        root.moved(wanted);
    }

    Follow {
        id: glide

        target: root.fraction
        speed: Appearance.anim.trackSpeed
        epsilon: 0.001
    }

    G2Rect {
        anchors.verticalCenter: parent.verticalCenter

        width: parent.width
        height: root.rail
        radius: height / 2
        color: Appearance.colour.fill

        G2Rect {
            width: root.beadCentre
            height: parent.height
            radius: height / 2
            color: root.lit
            opacity: 0.55
        }

        G2Rect {
            visible: root.warnAbove > root.from && root.warnAbove < root.to
            x: root.beadSize / 2 + ((root.warnAbove - root.from) / Math.max(0.0001, root.to - root.from)) * root.travel - width / 2
            width: Math.max(2, Math.round(root.rail / 3))
            height: parent.height
            radius: width / 2
            color: Appearance.colour.accentText
            opacity: 0.55
        }
    }

    G2Rect {
        visible: root.enabled

        x: root.beadCentre - width / 2
        y: (root.height - height) / 2
        width: root.beadSize
        height: width
        radius: width / 2
        color: root.lit

        scale: pointer.pressed ? 1.15 : root.active ? 1.3 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent

        anchors.topMargin: -Math.max(0, (Appearance.sizes.minTarget - root.height) / 2)
        anchors.bottomMargin: anchors.topMargin
        anchors.leftMargin: -Appearance.padding.small
        anchors.rightMargin: anchors.leftMargin
        hoverEnabled: true

        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        function report(mx: real): void {
            const f = (pointer.mapToItem(root, mx, 0).x - root.beadSize / 2) / root.travel;
            const clamped = Math.max(0, Math.min(1, f));
            root.ask(root.from + clamped * (root.to - root.from));
        }

        onPressed: mouse => report(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                report(mouse.x);
        }

        onWheel: wheel => {
            const notches = wheel.angleDelta.y / 120;
            root.ask(root.value + notches * root.step);
        }
    }
}
