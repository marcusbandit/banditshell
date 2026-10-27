import QtQuick
import qs.services

Item {
    id: root

    property string name: ""

    property Component panel: null

    property bool needed: false

    readonly property var item: loader.item

    readonly property bool open: root.item?.open ?? false
    readonly property var blobs: root.item?.blobs ?? []
    readonly property Item maskItem: root.item?.maskItem ?? null

    function build(span = undefined): var {
        if (!loader.active) {
            loader.active = true;
            if (span === undefined)
                Trace.note("built");
            else
                Trace.step("built", span);
        }
        return loader.item;
    }

    function show(): void {
        const span = root.open ? null : Trace.begin(`${root.name} open`, root.item ? "" : "first");
        root.build(span).show();
        Trace.step("shown", span);
    }

    function hide(): void {
        const span = root.open ? Trace.begin(`${root.name} close`) : null;
        root.item?.hide();
        Trace.step("hidden", span);
    }

    function toggle(): void {
        const span = Trace.begin(`${root.name} ${root.open ? "close" : "open"}`, root.item ? "" : "first");
        root.build(span).toggle();
        Trace.step(root.open ? "shown" : "hidden", span);
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
