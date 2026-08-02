pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Notifications, arriving, inside ONE tray.
//
// The tray is a single blob melted into the right band, and the cards live
// INSIDE it. That is the third arrangement this file has had, and the reasoning
// is worth keeping:
//
//   - Panels chained through the melt fused into each OTHER as well as into the
//     shell: three peers within melt distance became one lumpy mass with pinches
//     where the boundaries should have been.
//   - Melting each card into the band separately fixed that, and produced N
//     tongues off the edge, which is not one body either.
//   - A metaball chain cannot give both. Cards fuse into a column only when they
//     are closer together than half the melt, and that is exactly the spacing at
//     which they stop being legible.
//
// So the connection is made by a CONTAINER rather than by the field. One tray,
// one join to the shell, and the cards inside it separated the ordinary way, by
// a raised fill and a gap. The stack grows and shrinks as one shape.
//
// Newest at the top, so a new arrival never shoves the one you are reading out
// from under the cursor.
Item {
    id: root

    // How far in from the content area's top edge the tray sits.
    required property real inset

    // The band's thickness. The tray reaches past it, to the screen edge.
    required property real edgeInset

    readonly property real panelWidth: Appearance.sizes.notificationWidth

    readonly property bool any: Notifs.popups.length > 0

    // What the window's input mask should cover: the TRAY, not this item.
    //
    // This item fills the screen, because the tray is positioned inside it.
    // Handing it to the mask as-is made the whole screen interactive the moment
    // any notification existed, so the shell swallowed every click anywhere. A
    // critical notification never times out, so it stayed that way.
    readonly property Item maskItem: tray

    // The tray's rectangle, for the chassis to melt in.
    //
    // PUSHED, not bound. A binding here has to read the tray's geometry, and
    // reading a lazy binding re-evaluates it, which emits the very change signal
    // that invalidates this list WHILE it is being computed: a binding loop on
    // every frame of every arrival. Qt.callLater coalesces the pushes, so a tray
    // that moves and resizes in the same frame rebuilds this once.
    property var blobs: []

    function sync(): void {
        if (!root.any || tray.height <= 0) {
            root.blobs = [];
            return;
        }
        root.blobs = [
            {
                x: tray.x,
                y: tray.y,
                w: tray.width,
                h: tray.height,
                radius: Appearance.rounding.large
            }
        ];
    }

    onAnyChanged: Qt.callLater(root.sync)
    onWidthChanged: Qt.callLater(root.sync)

    Item {
        id: tray

        // Flush with the SCREEN edge, not with the band's inner edge. The tray
        // and the band are one body; held off the edge it would join the shell
        // through a neck instead of simply being part of it.
        x: root.width - root.panelWidth
        y: root.inset
        width: root.panelWidth
        height: stack.height + Appearance.padding.normal * 2
        visible: root.any

        onYChanged: Qt.callLater(root.sync)
        onHeightChanged: Qt.callLater(root.sync)

        Column {
            id: stack

            x: Appearance.padding.normal
            y: Appearance.padding.normal
            width: tray.width - Appearance.padding.normal * 2
            spacing: Appearance.padding.normal

            Repeater {
                model: Notifs.popups

                delegate: NotificationCard {
                    required property var modelData

                    entry: modelData
                    fullWidth: stack.width
                    onDismissed: Notifs.dismissPopup(modelData)
                }
            }
        }
    }
}
