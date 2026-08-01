pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Notifications, arriving.
//
// They come out of the RIGHT band the way a menu comes out of the sidebar: each
// one is a blob in the shell's field, so it swells out of the chassis and sinks
// back into it. Nothing is drawn on top of the desktop that has not grown out of
// the shell's own body, which is the whole point of the field.
//
// Stacked downward from the top, newest first, so a new one never pushes the one
// you are reading out from under the cursor.
Item {
    id: root

    // Where the chassis's right band begins.
    required property real originX
    required property real inset

    readonly property real panelWidth: Appearance.sizes.notificationWidth
    readonly property real gap: Appearance.padding.normal

    // Bumped whenever a card moves or resizes.
    //
    // `blobs` reads geometry through mapToItem(), and QML cannot see inside a
    // function call to know what the binding depends on. Without something that
    // visibly changes, the blob is computed once and then stays put while the
    // card is dragged out from under it: the body sat still and the text slid
    // away from it.
    property int revision: 0

    // Every popup's rectangle, for the chassis to melt in. Reported in the same
    // order as the items below, so a blob and its contents cannot disagree.
    readonly property var blobs: {
        root.revision;
        const out = [];
        for (let i = 0; i < stack.children.length; i++) {
            const item = stack.children[i];
            if (!item?.visible || item.reveal <= 0)
                continue;
            // MAPPED, not assembled from parts. `item.y` is relative to the
            // stack, which is itself inset, and hand-anchoring the blob to the
            // right while the card grew from the left put the two in completely
            // different places for the whole animation: at half reveal they did
            // not even overlap.
            const at = item.mapToItem(root, 0, 0);
            out.push({
                x: at.x,
                y: at.y,
                // Shrinks as the card fades, so the body leaves with its
                // contents instead of lingering as an empty bulge.
                w: item.width * item.opacity,
                h: item.height,
                radius: Appearance.rounding.large
            });
        }
        return out;
    }

    readonly property bool any: Notifs.popups.length > 0

    // What the window's input mask should cover: the CARDS, not this item.
    //
    // This item fills the screen, because the cards are positioned inside it.
    // Handing it to the mask as-is made the whole screen interactive the moment
    // any notification existed, so the shell swallowed every click anywhere. A
    // critical notification never times out, so it stayed that way.
    readonly property Item maskItem: stack

    Column {
        id: stack

        x: root.width - root.panelWidth
        y: root.inset
        width: root.panelWidth
        spacing: root.gap

        Repeater {
            model: Notifs.popups

            delegate: NotificationCard {
                required property var modelData

                // Grows from the RIGHT: this band is on the right, so the edge
                // that stays put is the one against the chassis. Given as `base`
                // rather than `x`, because a throw owns x while it lasts.
                base: stack.width - width

                onXChanged: root.revision++
                onYChanged: root.revision++
                onWidthChanged: root.revision++
                onHeightChanged: root.revision++
                onOpacityChanged: root.revision++

                entry: modelData
                fullWidth: root.panelWidth
                onDismissed: Notifs.dismissPopup(modelData)
            }
        }
    }
}
