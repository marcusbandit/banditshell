pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property bool keepLeaves: true

    signal tapped
    signal held
    signal released
    signal kept
    signal scrolled(real by)
    signal scrollEnded(real speed)

    property real dragX: 0
    property real pulled: 0
    property bool dragging: false
    property bool flinging: false
    property int flung: 0

    readonly property real shift: root.dragging ? root.dragX : slide.value
    readonly property real fade: Math.min(1, Math.abs(root.shift) / Math.max(1, root.width))

    readonly property bool pressed: press.pressed
    readonly property bool moved: press.throwing || press.scrolling
    readonly property bool hovered: pointer.hovered
    readonly property bool handling: press.pressed || root.dragging || root.flinging

    readonly property real throwDistance: root.width * Config.values.control.dragDismissFraction

    readonly property bool committed: Math.abs(root.pulled) >= root.throwDistance || (root.pulled * press.velocity > 0 && Math.abs(press.velocity) >= Config.values.control.flickVelocity)

    function resist(delta: real): real {
        const commit = root.throwDistance;
        const k = Config.values.control.dragResistance;
        const m = Math.abs(delta);
        const resisted = m < commit ? m * k : commit * k + (m - commit);
        return delta < 0 ? -resisted : resisted;
    }

    function springBack(): void {
        slide.value = root.shift;
        slide.target = 0;
        root.dragging = false;
        root.pulled = 0;
        press.throwing = false;
    }

    function fling(direction: int): void {
        if (root.flinging)
            return;
        if (direction < 0 && !root.keepLeaves) {
            root.springBack();
            root.kept();
            return;
        }
        slide.value = root.shift;
        root.dragging = false;
        root.pulled = 0;
        press.throwing = false;
        root.flung = direction;
        root.flinging = true;
        slide.target = direction * root.width * 1.15;
    }

    function reset(): void {
        root.flinging = false;
        root.dragging = false;
        root.flung = 0;
        root.pulled = 0;
        slide.target = 0;
        slide.snap();
    }

    HoverHandler {
        id: pointer
    }

    Follow {
        id: slide

        speed: Appearance.animation.trackSpeed
        epsilon: 0.5

        onValueChanged: if (root.flinging && Math.abs(slide.value) >= root.width) {
            const direction = root.flung;
            root.flinging = false;
            if (direction > 0)
                root.released();
            else
                root.kept();
        }
    }

    MouseArea {
        id: press

        property real anchorX: 0
        property real anchorY: 0
        property real startedAt: 0
        property real lastDx: 0
        property real lastDy: 0
        property real lastEvent: 0
        property real velocity: 0
        property var trail: []

        property bool throwing: false
        property bool scrolling: false
        property bool holding: false
        property bool wandered: false

        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        preventStealing: press.throwing
        cursorShape: press.throwing ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        function begin(): void {
            press.startedAt = root.shift;
            press.throwing = false;
            press.scrolling = false;
            press.holding = false;
            press.wandered = false;
            press.velocity = 0;
            press.lastDx = 0;
            press.lastDy = 0;
            press.trail = [];
            press.lastEvent = Date.now();
        }

        function advance(dx: real, dy: real): void {
            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - press.lastEvent));
            press.lastEvent = now;
            press.velocity += ((dx - press.lastDx) / dt - press.velocity) * 0.4;
            press.lastDx = dx;

            if (!press.throwing) {
                if (Math.abs(dy) >= Config.values.control.dragThreshold)
                    press.wandered = true;
                if (Math.abs(dy) > Math.abs(dx)) {
                    if (Math.abs(dy) >= Config.values.control.dragThreshold) {
                        press.scrolling = true;
                        press.trail = [...press.trail.filter(p => now - p.t < 120), {
                                y: dy,
                                t: now
                            }];
                        root.scrolled(dy - press.lastDy);
                    }
                    press.lastDy = dy;
                    return;
                }
                if (Math.abs(dx) < Config.values.control.dragThreshold)
                    return;
                press.throwing = true;
            }

            root.pulled = dx;
            root.dragX = root.resist(press.startedAt + dx);
            root.dragging = true;
        }

        function stream(dx: real, dy: real): void {
            if (!press.throwing && press.scrolling)
                return;
            if (!press.throwing && Math.abs(dy) > Math.abs(dx) && Math.abs(dy) >= Config.values.control.dragThreshold) {
                press.scrolling = true;
                return;
            }
            press.advance(dx, dy);
        }

        function conclude(): void {
            if (!press.throwing)
                return;
            if (root.committed)
                root.fling(root.pulled > 0 ? 1 : -1);
            else
                root.springBack();
        }

        function scrollSpeed(): real {
            const first = press.trail[0];
            const last = press.trail[press.trail.length - 1];
            return first && last && last.t > first.t && Date.now() - last.t < 80 ? (last.y - first.y) / (last.t - first.t) : 0;
        }

        onPressed: mouse => {
            scroll.finish();
            press.anchorX = mouse.x;
            press.anchorY = mouse.y;
            press.begin();
        }

        onPositionChanged: mouse => {
            if (press.pressedButtons !== Qt.LeftButton)
                return;
            press.advance(mouse.x - press.anchorX, mouse.y - press.anchorY);
        }

        onPressAndHold: {
            if (press.throwing || press.scrolling)
                return;
            press.holding = true;
            root.held();
        }

        onReleased: mouse => {
            if (press.scrolling) {
                root.scrollEnded(press.scrollSpeed());
                press.scrolling = false;
                return;
            }
            if (press.throwing) {
                press.conclude();
                return;
            }
            if (press.holding || press.wandered)
                return;
            if (mouse.button === Qt.RightButton)
                root.fling(1);
            else
                root.tapped();
        }

        onCanceled: {
            if (press.scrolling)
                root.scrollEnded(0);
            if (press.throwing)
                root.springBack();
            press.scrolling = false;
            press.holding = false;
            press.wandered = false;
        }

        onWheel: wheel => {
            if (press.pressed) {
                wheel.accepted = false;
                return;
            }
            if (!scroll.feed(wheel))
                return;
            wheel.accepted = press.throwing;
        }

        ScrollGesture {
            id: scroll

            onBegan: press.begin()
            onMoved: (dx, dy) => press.stream(dx, dy)
            onEnded: press.conclude()
        }
    }
}
