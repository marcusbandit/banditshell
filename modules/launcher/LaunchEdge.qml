import QtQuick
import qs.config
import qs.components

Item {
    id: root

    required property real border

    required property real span

    property bool armed: true

    readonly property real swellBy: Math.max(1, Appearance.sizes.gap - 1)

    property real reach: 0

    property real bulge: root.span

    readonly property real roam: Math.max(0, (root.span - root.bulge) / 2)

    property real grabOffset: 0

    property real bulgeAt: 0

    function offsetAt(x: real): real {
        return Math.max(-root.roam, Math.min(root.roam, x - root.span / 2));
    }

    readonly property real travelFull: Math.max(1, root.reach > 0 ? root.reach : root.height - root.border * 2)

    readonly property real slack: Config.values.control.pullSlack

    readonly property real cosLimit: Math.cos(Config.values.control.pullAngleEdge * Math.PI / 180)

    readonly property real grab: Math.max(root.border + root.swellBy, Appearance.sizes.minTarget)

    readonly property bool active: root.armed && (zone.containsMouse || zone.pressed) && !zone.pulling

    readonly property Item maskItem: zone

    signal pressed

    signal dragged(real fraction, real aside)

    signal finished(bool open)

    readonly property var blobs: swell.value <= 0.01 ? [] : [
        {
            x: (root.width - root.bulge) / 2 + Math.max(-root.roam, Math.min(root.roam, root.bulgeAt)),
            y: root.height - (root.border + swell.value),
            w: root.bulge,
            h: root.border + swell.value,
            radius: Appearance.sizes.windowRadius,
            smooth: Math.min(Appearance.sizes.melt, (root.border + swell.value) / 2)
        }
    ]

    function begin(): void {
        zone.begin();
    }

    function advance(up: real, aside: real): void {
        zone.advance(up, aside);
    }

    function settle(): void {
        zone.settle();
    }

    Follow {
        id: swell

        target: root.active ? root.swellBy : 0
        speed: Appearance.animation.revealSpeed

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
        property real fromX: 0
        property bool pulling: false
        property real velocity: 0

        property real lastUp: 0
        property real lastEvent: 0
        property real progress: 0

        function begin(): void {
            root.grabOffset = zone.containsMouse || zone.pressed ? zone.mouseX - root.span / 2 : 0;
            root.bulgeAt = root.offsetAt(zone.mouseX);
            zone.pulling = false;
            zone.velocity = 0;
            zone.lastUp = 0;
            zone.lastEvent = Date.now();
            zone.progress = 0;

            root.pressed();
        }

        function advance(up: real, aside: real): void {

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
            root.dragged(zone.progress, aside);
        }

        function settle(): void {
            if (zone.pulling)
                root.finished(zone.velocity >= 0 || (zone.progress >= Config.values.control.pullCommit && zone.velocity > -Config.values.control.pullReversal));
            zone.pulling = false;
        }

        onPressed: mouse => {
            if (!root.armed) {
                mouse.accepted = false;
                return;
            }

            scroll.finish();

            zone.from = mouse.y;
            zone.fromX = mouse.x;
            zone.begin();
        }

        onPositionChanged: mouse => {
            if (zone.pressed)
                zone.advance(zone.from - mouse.y, mouse.x - zone.fromX);
            else if (!zone.pulling)
                root.bulgeAt = root.offsetAt(mouse.x);
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

                zone.advance(-dy, dx);
            }
            onEnded: zone.settle()
        }
    }
}
