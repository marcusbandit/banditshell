import QtQuick
import qs.config

ListView {
    id: root

    property real step: Appearance.sizes.rowHeight * Appearance.sizes.wheelRows

    property real scrollTarget: 0

    readonly property real maxScroll: Math.max(0, contentHeight - height)

    readonly property bool handling: dragging

    boundsBehavior: Flickable.DragAndOvershootBounds

    function scrollTo(y: real): void {
        root.scrollTarget = Math.max(0, Math.min(y, root.maxScroll));
    }

    function reveal(index: int): void {
        if (root.count <= 0)
            return;
        const rowHeight = root.contentHeight / root.count;
        const top = index * rowHeight;
        const bottom = top + rowHeight;

        if (top < root.anchor)
            root.scrollTo(top);
        else if (bottom > root.anchor + root.height)
            root.scrollTo(bottom - root.height);
    }

    function reset(): void {
        root.scrollTarget = 0;
        glide.value = 0;
        root.contentY = 0;
    }

    onContentHeightChanged: root.settle()
    onHeightChanged: root.settle()

    function settle(): void {
        root.scrollTo(root.scrollTarget);

        const inside = Math.max(0, Math.min(root.contentY, root.maxScroll));
        if (!root.handling && Math.abs(inside - root.contentY) > 0.5) {
            glide.value = inside;
            root.scrollTarget = inside;
            root.contentY = inside;
        }
    }

    Follow {
        id: glide

        speed: Appearance.anim.scrollSpeed

        epsilon: 0.5
        target: root.scrollTarget

        onValueChanged: if (!root.handling)
            root.contentY = value
    }

    onDraggingChanged: {
        glide.value = root.contentY;
        root.scrollTarget = root.contentY;
    }

    readonly property real anchor: glide.settled ? contentY : scrollTarget

    property real velocity: 0
    property real lastEvent: 0

    WheelHandler {
        onWheel: event => {
            event.accepted = true;

            if (event.phase === Qt.ScrollEnd || (event.pixelDelta.y === 0 && event.angleDelta.y === 0)) {
                root.coastOn();
                return;
            }

            if (event.pixelDelta.y === 0) {
                root.scrollTo(root.anchor - event.angleDelta.y / 120 * root.step);
                return;
            }

            const now = Date.now();
            const dt = Math.max(1, Math.min(100, now - root.lastEvent));
            root.lastEvent = now;

            const before = root.contentY;
            root.contentY = Math.max(0, Math.min(root.contentY - event.pixelDelta.y, root.maxScroll));

            const sample = (root.contentY - before) / dt;
            root.velocity += (sample - root.velocity) * 0.4;

            root.scrollTarget = root.contentY;
            glide.value = root.contentY;

            coast.restart();
        }
    }

    function coastOn(): void {
        coast.stop();
        root.scrollTo(root.contentY + root.velocity * Appearance.sizes.coastMs);
        root.velocity = 0;
    }

    Timer {
        id: coast

        interval: Appearance.anim.fast
        onTriggered: root.coastOn()
    }
}
