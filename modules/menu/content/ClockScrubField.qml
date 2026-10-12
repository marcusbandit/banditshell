import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property int value: 0
    property int from: 0
    property int to: 59
    property int detent: 1
    property bool wrap: true

    property bool zeroIsEmpty: true

    property int held: 0
    property bool holding: false

    readonly property int shown: root.holding ? root.held : root.value

    signal moved(int value)
    signal committed(int value)

    readonly property real pitch: Appearance.sizes.minTarget / Math.max(1, root.detent)
    readonly property int span: root.to - root.from + 1

    implicitWidth: Math.max(Appearance.sizes.minTarget, digits.implicitWidth + Appearance.padding.small * 2)
    implicitHeight: Math.max(Appearance.sizes.rowHeight, Math.round(Appearance.font.size.large * 4 / 3))
    width: implicitWidth
    height: implicitHeight

    function fold(v: int): int {
        if (!root.wrap)
            return Math.max(root.from, Math.min(root.to, v));
        return root.from + ((v - root.from) % root.span + root.span) % root.span;
    }

    function magnet(raw: real): int {
        const step = Math.max(1, root.detent);
        const nearest = Math.round(raw / step) * step;
        return Math.abs(raw - nearest) * root.pitch <= Appearance.sizes.dragThreshold ? nearest : Math.round(raw);
    }

    function hold(): void {
        if (root.holding)
            return;
        root.held = root.value;
        root.holding = true;
    }

    function step(v: int): void {
        if (v === root.held)
            return;
        root.held = v;
        root.moved(v);
    }

    function ask(raw: real): void {
        root.hold();
        root.step(root.fold(root.magnet(raw)));
    }

    function nudge(units: int): void {
        if (units === 0)
            return;
        root.hold();
        root.step(root.fold(root.held + units));
        quiet.restart();
    }

    function release(): void {
        quiet.stop();
        if (!root.holding)
            return;
        root.holding = false;
        if (root.held !== root.value)
            root.committed(root.held);
    }

    onVisibleChanged: if (!root.visible)
        root.release()

    Timer {
        id: quiet

        interval: Appearance.anim.settle
        onTriggered: root.release()
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
        opacity: pointer.containsMouse || pointer.pressed || scroll.active ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    StyledText {
        id: digits

        anchors.centerIn: parent

        text: Clock.pad2(root.shown)
        font.pixelSize: Appearance.font.size.large
        color: root.zeroIsEmpty && root.shown === 0 ? Appearance.colour.textFaint : Appearance.colour.text
    }

    MouseArea {
        id: pointer

        property real fromY: 0
        property int startValue: 0

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        preventStealing: true

        onPressed: mouse => {
            scroll.finish();
            root.hold();
            pointer.fromY = mouse.y;
            pointer.startValue = root.held;
        }

        onPositionChanged: mouse => {
            if (pointer.pressed)
                root.ask(pointer.startValue - (mouse.y - pointer.fromY) / root.pitch);
        }

        onReleased: root.release()
        onCanceled: root.release()

        onWheel: wheel => {
            if (!scroll.feed(wheel)) {
                const notches = wheel.angleDelta.y / 120;
                root.nudge(Math.round(notches) || (notches > 0 ? 1 : notches < 0 ? -1 : 0));
                wheel.accepted = true;
                return;
            }

            wheel.accepted = Math.abs(scroll.dy) >= Math.abs(scroll.dx);
        }

        ScrollGesture {
            id: scroll

            armed: !pointer.pressed

            onBegan: {
                root.hold();
                pointer.startValue = root.held;
            }
            onMoved: (dx, dy) => {
                if (Math.abs(dy) >= Math.abs(dx))
                    root.ask(pointer.startValue - dy / root.pitch);
            }
            onEnded: root.release()
        }
    }
}
