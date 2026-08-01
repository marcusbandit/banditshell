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

    // Every popup's rectangle, for the chassis to melt in. Reported in the same
    // order as the items below, so a blob and its contents cannot disagree.
    readonly property var blobs: {
        const out = [];
        for (let i = 0; i < stack.children.length; i++) {
            const item = stack.children[i];
            if (!item?.visible || item.reveal <= 0)
                continue;
            out.push({
                x: root.width - item.width,
                y: item.y,
                w: item.width,
                h: item.height,
                radius: Appearance.rounding.large
            });
        }
        return out;
    }

    readonly property bool any: Notifs.popups.length > 0

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

                entry: modelData
                fullWidth: root.panelWidth
                onDismissed: Notifs.dismissPopup(modelData)
            }
        }
    }
}
