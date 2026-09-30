import QtQuick
import qs.config
import qs.components

Item {
    id: root

    required property real border

    required property real span

    property bool armed: true

    readonly property real swellBy: Math.max(1, Appearance.sizes.gap - 1)

    readonly property real travelFull: Math.max(1, root.height - root.border * 2)

    readonly property real slack: Appearance.sizes.pullSlack

    readonly property real cosLimit: Math.cos(Appearance.sizes.pullAngleEdge * Math.PI / 180)

    readonly property real grab: Math.max(root.border + root.swellBy, Appearance.sizes.minTarget)

    readonly property bool active: root.armed && (zone.containsMouse || zone.pressed)

    readonly property Item maskItem: zone

    signal pressed

    signal dragged(real fraction)

    signal finished(bool open)

    readonly property var blobs: swell.value <= 0.01 ? [] : [
        {
            x: (root.width - root.span) / 2,
            y: root.height - (root.border + swell.value),
            w: root.span,
            h: root.border + swell.value,
            radius: Appearance.sizes.windowRadius,
            smooth: Math.min(Appearance.sizes.melt, (root.border + swell.value) / 2)
        }
    ]

    function begin(): void {
        zone.begin();
    }

    function advance(up: real): void {
        zone.advance(up);
    }

    function settle(): void {
        zone.settle();
    }

    Follow {
        id: swell

        target: root.active ? root.swellBy : 0
        speed: Appearance.anim.revealSpeed

        epsilon: 0.2
    }

    MouseArea {
        id: zone

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: root.span
        height: root.grab

        hoverEnabled: true
        preventStealing: true

        property real from: 0
        property bool pulling: false
        property real velocity: 0

        property real lastUp: 0
        property real lastEvent: 0
        property real progress: 0

        function begin(): void {
            zone.pulling = false;
            zone.velocity = 0;
            zone.lastUp = 0;
            zone.lastEvent = Date.now();
            zone.progress = 0;

            root.pressed();
        }

        function advance(up: real): void {

            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - zone.lastEvent));
            zone.lastEvent = now;
            const step = up - zone.lastUp;
            zone.lastUp = up;
            zone.velocity += (step / dt - zone.velocity) * 0.4;

            if (!zone.pulling && up < root.slack)
                return;

            zone.pulling = true;
            zone.progress = Math.max(0, Math.min(up / root.travelFull, 1));
            root.dragged(zone.progress);
        }

        function settle(): void {
            if (zone.pulling)
                root.finished(zone.velocity >= 0 || (zone.progress >= Appearance.sizes.pullCommit && zone.velocity > -Appearance.sizes.pullReversal));
            zone.pulling = false;
        }

        onPressed: mouse => {
            if (!root.armed) {
                mouse.accepted = false;
                return;
            }

            scroll.finish();

            zone.from = mouse.y;
            zone.begin();
        }

        onPositionChanged: mouse => {
            if (zone.pressed)
                zone.advance(zone.from - mouse.y);
        }

        onReleased: {

            if (!zone.pulling)
                root.finished(true);

            zone.settle();
        }

        onCanceled: {
            if (zone.pulling)
                root.finished(false);
            zone.pulling = false;
        }

        onWheel: wheel => {

            wheel.accepted = !zone.pressed && scroll.feed(wheel) && !scroll.crossed;
        }

        ScrollGesture {
            id: scroll

            armed: root.armed

            property bool crossed: false

            onBegan: {
                scroll.crossed = false;
                zone.begin();
            }

            onMoved: (dx, dy) => {
                if (scroll.crossed)
                    return;

                if (!zone.pulling) {
                    const dist = Math.hypot(dx, dy);
                    if (dist >= root.slack && -dy / dist < root.cosLimit) {
                        scroll.crossed = true;
                        return;
                    }
                }

                zone.advance(-dy);
            }
            onEnded: zone.settle()
        }
    }
}
