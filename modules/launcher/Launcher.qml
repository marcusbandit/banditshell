pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Which launcher is live.
//
// TWO CONCEPTS, both in the tree, chosen at runtime rather than kept on a
// branch. A design you cannot switch back on while the shell is running is a
// design you cannot compare against the one that replaced it, and comparing is
// the entire point of having a second one.
//
//   list      a search field over a dense, icon-led list of everything
//             installed, ranked by what you use. See ListLauncher.
//   niagara   text before icons: a few favourites at rest, and the rest of the
//             alphabet reached by scrubbing a rail. See NiagaraLauncher.
//
// `banditshell set launcher.concept niagara`, and it swaps under you.
//
// This forwards rather than implements: everything outside asks the launcher
// whether it is open, what to melt, and what to let the cursor touch, and none
// of it should have to know which one answered.
Item {
    id: root

    required property real originX
    required property real inset

    readonly property var concept: loader.item

    readonly property bool open: root.concept?.open ?? false
    readonly property var blobs: root.concept?.blobs ?? []
    readonly property Item maskItem: root.concept?.maskItem ?? null

    // For `banditshell status`.
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

    // How wide the live concept is, so the bottom edge can be an affordance for
    // exactly the thing it opens rather than for the whole screen.
    readonly property real panelWidth: root.concept?.panelWidth ?? 0

    // Only the niagara concept has a rail; the list one ignores it.
    function scrub(fraction: real): void {
        if (root.concept?.scrubTo)
            root.concept.scrubTo(fraction);
    }

    // Pulled out of the bottom edge by hand. Concepts that cannot follow a drag
    // simply open on release, which is what the edge did before it could.
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

        NiagaraLauncher {
            originX: root.originX
            inset: root.inset
        }
    }
}
