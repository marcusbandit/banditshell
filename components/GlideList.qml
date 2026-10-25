import QtQuick
import qs.config

ListView {
    id: root

    property real step: Appearance.sizes.rowHeight * ControlTuning.wheelRows

    readonly property real maxScroll: Math.max(0, contentHeight - height)

    readonly property real anchor: wheel.goal

    property real revealMargin: 0

    property int pendingReveal: -1

    onContentYChanged: if (root.pendingReveal >= 0 && root.itemAtIndex(root.pendingReveal))
        root.reveal(root.pendingReveal)
    onMovementStarted: root.pendingReveal = -1

    boundsBehavior: Flickable.DragAndOvershootBounds

    function scrollTo(y: real): void {
        wheel.scrollTo(y);
    }

    function reveal(index: int): void {
        if (root.count <= 0)
            return;
        const item = root.itemAtIndex(index);
        root.pendingReveal = item ? -1 : index;
        const rowHeight = root.contentHeight / root.count;
        const top = item ? item.y : index * rowHeight;
        const bottom = top + (item ? item.height : rowHeight);

        if (top < root.anchor + root.revealMargin)
            root.scrollTo(top - root.revealMargin);
        else if (bottom > root.anchor + root.height - root.revealMargin)
            root.scrollTo(bottom - root.height + root.revealMargin);
    }

    function reset(): void {
        root.pendingReveal = -1;
        wheel.stop();
        root.contentY = 0;
    }

    onContentHeightChanged: root.settle()
    onHeightChanged: root.settle()

    function settle(): void {
        if (root.moving || wheel.gliding)
            return;
        const inside = wheel.bound(root.contentY);
        if (Math.abs(inside - root.contentY) > 0.5)
            root.contentY = inside;
    }

    WheelStep {
        id: wheel

        flick: root
        onWheel: root.pendingReveal = -1
    }
}
