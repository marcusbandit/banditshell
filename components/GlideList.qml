import QtQuick
import qs.config

ListView {
    id: root

    property real step: Appearance.sizes.rowHeight * ControlTuning.wheelRows

    property real scrollTarget: 0

    readonly property real maxScroll: Math.max(0, contentHeight - height)

    readonly property bool handling: dragging || flicking || moving

    boundsBehavior: Flickable.DragAndOvershootBounds

    function scrollTo(y: real): void {
        glide.value = root.contentY;
        root.scrollTarget = Math.max(0, Math.min(y, root.maxScroll));
    }

    function reveal(index: int): void {
        if (root.count <= 0)
            return;
        const item = root.itemAtIndex(index);
        const rowHeight = root.contentHeight / root.count;
        const top = item ? item.y : index * rowHeight;
        const bottom = top + (item ? item.height : rowHeight);

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
        root.scrollTarget = Math.max(0, Math.min(root.scrollTarget, root.maxScroll));

        const inside = Math.max(0, Math.min(root.contentY, root.maxScroll));
        if (!root.handling && Math.abs(inside - root.contentY) > 0.5) {
            glide.value = inside;
            root.scrollTarget = inside;
            root.contentY = inside;
        }
    }

    Follow {
        id: glide

        speed: Appearance.animation.scrollSpeed

        epsilon: 0.5
        target: root.scrollTarget

        onValueChanged: if (!root.handling)
            root.contentY = value
    }

    onContentYChanged: if (root.handling) {
        glide.value = root.contentY;
        root.scrollTarget = root.contentY;
    }

    readonly property real anchor: glide.settled ? contentY : scrollTarget
}
