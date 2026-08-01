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

    Column {
        id: stack

        x: root.width - root.panelWidth - root.inset
        y: root.inset
        width: root.panelWidth
        spacing: Appearance.padding.normal

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
