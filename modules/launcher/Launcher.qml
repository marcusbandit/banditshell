pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    required property real originX
    required property real inset

    readonly property var concept: loader.item

    readonly property bool open: root.concept?.open ?? false
    readonly property var blobs: root.concept?.blobs ?? []
    readonly property Item maskItem: root.concept?.maskItem ?? null

    readonly property real drawnHeight: root.concept?.drawnHeight ?? 0
    readonly property int resultCount: root.concept?.resultCount ?? 0
    readonly property string scrollInfo: root.concept?.scrollInfo ?? "-"

    function show(): void {
        root.concept?.show();
    }

    function hide(): void {
        root.concept?.hide();
    }

    function toggle(): void {
        root.concept?.toggle();
    }

    readonly property real panelWidth: root.concept?.panelWidth ?? 0

    function scrub(fraction: real): void {
        if (root.concept?.scrubTo)
            root.concept.scrubTo(fraction);
    }

    function dragTo(fraction: real): void {
        if (root.concept?.dragTo)
            root.concept.dragTo(fraction);
    }

    function dragEnd(open: bool): void {
        if (root.concept?.dragEnd)
            root.concept.dragEnd(open);
        else if (open)
            root.show();
    }

    Loader {
        id: loader

        anchors.fill: parent
        sourceComponent: Config.values.launcher.concept === "niagara" ? niagara : list
    }

    Component {
        id: list

        ListLauncher {
            originX: root.originX
            inset: root.inset
        }
    }

    Component {
        id: niagara

        AlphabetLauncher {
            originX: root.originX
            inset: root.inset
        }
    }
}
