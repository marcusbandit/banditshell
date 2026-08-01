pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Notifications, arriving.
//
// A plain stack of DISCRETE CARDS inside the content area, not blobs in the
// chassis field. See NotificationCard for why: peers that melt into each other
// stop being separable, which is the one thing a stack has to be.
//
// Newest at the top, so a new arrival never shoves the one you are reading out
// from under the cursor.
Item {
    id: root

    // How far in from the content area's edges to sit.
    //
    // Zero on the right on purpose: the cards sit FLUSH against the band so the
    // field has something to join them to. Held off it, the melt reaches across
    // the gap and makes a neck instead of a fillet.
    required property real inset

    readonly property real panelWidth: Appearance.sizes.notificationWidth

    readonly property bool any: Notifs.popups.length > 0

    // What the window's input mask should cover: the CARDS, not this item.
    //
    // This item fills the screen, because the cards are positioned inside it.
    // Handing it to the mask as-is made the whole screen interactive the moment
    // any notification existed, so the shell swallowed every click anywhere. A
    // critical notification never times out, so it stayed that way.
    readonly property Item maskItem: stack

    // Where the chassis's inner edge is on the right.
    required property real edgeInset

    // The cards' rectangles, for the chassis to melt in. They join the SHELL and
    // never each other: see meltPanel in blob.frag.
    //
    // PUSHED, not bound. A binding here has to loop over the stack's children,
    // and reading a card's `x` re-evaluates that card's lazy binding, which
    // emits xChanged, which invalidates this list WHILE it is being computed:
    // a binding loop every frame of every arrival. Qt.callLater coalesces the
    // pushes, so a card that moves and resizes in one frame rebuilds this once.
    property var blobs: []

    function sync(): void {
        const out = [];
        for (let i = 0; i < stack.children.length; i++) {
            const item = stack.children[i];
            if (!item?.visible || item.opacity <= 0.01 || item.height <= 0)
                continue;
            out.push({
                x: stack.x + item.x,
                y: stack.y + item.y,
                w: item.width,
                h: item.height,
                radius: Appearance.rounding.large
            });
        }
        root.blobs = out;
    }

    Column {
        id: stack

        x: root.width - root.panelWidth - root.edgeInset
        y: root.inset
        width: root.panelWidth
        spacing: Appearance.padding.normal

        Repeater {
            model: Notifs.popups

            delegate: NotificationCard {
                required property var modelData

                onXChanged: Qt.callLater(root.sync)
                onYChanged: Qt.callLater(root.sync)
                onHeightChanged: Qt.callLater(root.sync)
                onOpacityChanged: Qt.callLater(root.sync)
                Component.onCompleted: Qt.callLater(root.sync)
                Component.onDestruction: Qt.callLater(root.sync)

                entry: modelData
                fullWidth: root.panelWidth
                onDismissed: Notifs.dismissPopup(modelData)
            }
        }
    }
}
