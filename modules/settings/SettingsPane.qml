pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property bool backable: false

    property real inset: 0

    default property alias content: holder.data

    property real target: 0
    readonly property real position: flow.value
    readonly property real limit: Math.max(0, holder.childrenRect.height + holder.childrenRect.y + root.inset - root.height)

    readonly property bool backing: swipe.backing
    readonly property real backFraction: Math.max(0, Math.min(1, swipe.backX / Math.max(1, root.width)))

    signal backed(bool committed)

    clip: true

    function scrollTo(y: real): void {
        root.target = Math.max(0, Math.min(y, root.limit));
    }

    function drag(y: real): void {
        root.scrollTo(y);
        flow.value = root.target;
    }

    function coast(v: real): void {
        root.scrollTo(flow.value + v * Appearance.sizes.coastMs);
    }

    onLimitChanged: root.scrollTo(root.target)

    Follow {
        id: flow

        target: root.target
        speed: Appearance.anim.scrollSpeed
        epsilon: 0.5
    }

    MouseArea {
        id: swipe

        property real anchorX: 0
        property real anchorY: 0
        property real fromScroll: 0

        property bool scrolling: false
        property bool backing: false
        property bool spent: false

        property real backX: 0
        property real velocity: 0
        property real lastEvent: 0

        anchors.fill: parent

        function begin(): void {

            root.drag(root.position);
            swipe.fromScroll = root.position;
            swipe.scrolling = false;
            swipe.backing = false;
            swipe.spent = false;
            swipe.backX = 0;
            swipe.velocity = 0;
            swipe.lastEvent = Date.now();
        }

        function advance(dx: real, dy: real): void {
            if (swipe.spent)
                return;
            if (!swipe.scrolling && !swipe.backing) {
                if (Math.abs(dx) < Appearance.sizes.dragThreshold && Math.abs(dy) < Appearance.sizes.dragThreshold)
                    return;
                if (Math.abs(dy) > Math.abs(dx))
                    swipe.scrolling = true;
                else if (root.backable && dx > 0)
                    swipe.backing = true;
                else {
                    swipe.spent = true;
                    return;
                }
            }

            if (swipe.scrolling) {

                const now = Date.now();
                const dt = Math.max(1, Math.min(100, now - swipe.lastEvent));
                swipe.lastEvent = now;
                const before = root.position;
                root.drag(swipe.fromScroll - dy);
                swipe.velocity += ((root.position - before) / dt - swipe.velocity) * 0.4;
                return;
            }

            const next = Math.max(0, dx);
            swipe.velocity += (next - swipe.backX - swipe.velocity) * 0.4;
            swipe.backX = next;
        }

        function settle(meant: bool): void {
            if (swipe.backing) {

                const thrown = swipe.velocity >= Appearance.sizes.flickVelocity;
                const far = root.backFraction >= Appearance.sizes.pullCommit;
                swipe.backing = false;
                root.backed(meant && (thrown || far));
            } else if (swipe.scrolling && meant) {
                root.coast(swipe.velocity);
            }
            swipe.scrolling = false;
            swipe.spent = false;
        }

        onPressed: mouse => {

            scroll.finish();
            swipe.anchorX = swipe.x + mouse.x;
            swipe.anchorY = swipe.y + mouse.y;
            swipe.begin();
        }

        onPositionChanged: mouse => {
            if (swipe.pressed)
                swipe.advance(swipe.x + mouse.x - swipe.anchorX, swipe.y + mouse.y - swipe.anchorY);
        }

        onReleased: swipe.settle(true)
        onCanceled: swipe.settle(false)

        onWheel: wheel => {
            if (scroll.feed(wheel))
                return;
            wheel.accepted = true;
            const step = wheel.pixelDelta.y !== 0 ? wheel.pixelDelta.y : wheel.angleDelta.y / 120 * Appearance.sizes.rowHeight * Appearance.sizes.wheelRows;
            root.scrollTo(root.target - step);
        }

        ScrollGesture {
            id: scroll

            armed: !swipe.pressed

            onBegan: swipe.begin()
            onMoved: (dx, dy) => swipe.advance(dx, dy)
            onEnded: swipe.settle(true)
        }
    }

    Item {
        id: holder

        width: root.width
        y: -root.position
    }

}
