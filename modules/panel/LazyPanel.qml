import QtQuick

Item {
    id: root

    property Component panel: null

    property bool needed: false

    readonly property var item: loader.item

    readonly property bool open: root.item?.open ?? false
    readonly property var blobs: root.item?.blobs ?? []
    readonly property Item maskItem: root.item?.maskItem ?? null

    function build(): var {
        loader.active = true;
        return loader.item;
    }

    function show(): void {
        root.build().show();
    }

    function hide(): void {
        root.item?.hide();
    }

    function toggle(): void {
        root.build().toggle();
    }

    function dragTo(fraction: real, aside: real): void {
        root.build().dragTo(fraction, aside);
    }

    function dragEnd(open: bool): void {
        if (open || root.item)
            root.build().dragEnd(open);
    }

    onNeededChanged: if (root.needed)
        root.build()

    Component.onCompleted: if (root.needed)
        root.build()

    Loader {
        id: loader

        anchors.fill: parent

        active: false
        sourceComponent: root.panel
    }
}
