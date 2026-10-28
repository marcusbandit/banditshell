pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.services

Item {
    id: root

    required property real originX
    required property real inset

    readonly property var concept: loader.item

    readonly property bool alphabetical: Config.values.launcher.concept === "alphabet"

    readonly property bool open: root.concept?.open ?? false
    readonly property var blobs: root.concept?.blobs ?? []
    readonly property Item maskItem: root.concept?.maskItem ?? null

    readonly property real drawnHeight: root.concept?.drawnHeight ?? 0
    readonly property real reach: root.concept?.reach ?? 0
    readonly property real tabWidth: root.concept?.tabWidth ?? 0
    readonly property int resultCount: root.concept?.resultCount ?? 0
    readonly property string scrollInfo: root.concept?.scrollInfo ?? "-"

    function build(span = undefined): var {
        if (!loader.active || loader.status === Loader.Loading) {
            loader.asynchronous = false;
            loader.active = true;
            if (span === undefined)
                Trace.note("built");
            else
                Trace.step("built", span);
        }
        return loader.item;
    }

    function show(text = ""): void {
        const span = root.open ? null : Trace.begin("launcher open", loader.active ? "" : "first");
        root.build(span).show(text);
        Trace.step("shown", span);
    }

    function hide(): void {
        const span = root.open ? Trace.begin("launcher close") : null;
        root.concept?.hide();
        Trace.step("hidden", span);
    }

    function toggle(): void {
        const span = Trace.begin(`launcher ${root.open ? "close" : "open"}`, loader.active ? "" : "first");
        root.build(span).toggle();
        Trace.step(root.open ? "shown" : "hidden", span);
    }

    readonly property real panelWidth: root.concept?.panelWidth ?? (root.alphabetical ? Config.values.launcher.alphabet.width : Appearance.sizes.launcherWidth)

    function scrub(fraction: real): void {
        const concept = root.build();
        if (concept.scrubTo)
            concept.scrubTo(fraction);
    }

    function dragTo(fraction: real, aside: real): void {
        const concept = root.build();
        if (concept.dragTo)
            concept.dragTo(fraction, aside);
    }

    function dragEnd(open: bool): void {
        if (!open && !root.concept)
            return;
        const concept = root.build();
        if (concept.dragEnd)
            concept.dragEnd(open);
        else if (open)
            concept.show();
    }

    Timer {
        interval: 4000
        running: !loader.active

        onTriggered: {
            const span = Trace.begin("launcher warm");
            loader.asynchronous = true;
            loader.active = true;
            Trace.step("asked", span);
        }
    }

    Loader {
        id: loader

        anchors.fill: parent

        active: false
        sourceComponent: root.alphabetical ? alphabet : list

        onLoaded: if (loader.asynchronous) {
            loader.asynchronous = false;
            Trace.note("built");
        }
    }

    Component {
        id: list

        ListLauncher {
            originX: root.originX
            inset: root.inset
        }
    }

    Component {
        id: alphabet

        AlphabetLauncher {
            originX: root.originX
            inset: root.inset
        }
    }
}
