pragma ComponentBehavior: Bound

import QtQuick
import qs.config

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
    readonly property int resultCount: root.concept?.resultCount ?? 0
    readonly property string scrollInfo: root.concept?.scrollInfo ?? "-"

    function build(): var {
        loader.active = true;
        return loader.item;
    }

    function show(text = ""): void {
        root.build().show(text);
    }

    function hide(): void {
        root.concept?.hide();
    }

    function toggle(): void {
        root.build().toggle();
    }

    readonly property real panelWidth: root.concept?.panelWidth ?? (root.alphabetical ? Config.values.launcher.alphabet.width : Appearance.sizes.launcherWidth)

    function scrub(fraction: real): void {
        const concept = root.build();
        if (concept.scrubTo)
            concept.scrubTo(fraction);
    }

    function dragTo(fraction: real): void {
        const concept = root.build();
        if (concept.dragTo)
            concept.dragTo(fraction);
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

        onTriggered: loader.active = true
    }

    Loader {
        id: loader

        anchors.fill: parent

        active: false
        sourceComponent: root.alphabetical ? alphabet : list
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
