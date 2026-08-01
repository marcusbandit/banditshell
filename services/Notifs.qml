pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.config

// The notification daemon.
//
// This is a SERVER, not a reader. Nothing publishes notifications for the shell
// to observe: owning `org.freedesktop.Notifications` on the bus is what makes
// them exist, and only one process on the session can. So this is also the one
// service that conflicts with another shell, and the reason a second one running
// at the same time will appear to swallow every notification.
//
// Two lists, because they answer different questions. `popups` is what is on
// screen right now and each entry leaves on its own timer. `history` is what has
// arrived, kept until dismissed, which is what a hub shows.
Singleton {
    id: root

    readonly property alias server: server

    // Newest first, both of them: the thing you have not read yet is the thing
    // you are looking for.
    property var history: []
    property var popups: []

    readonly property int count: history.length
    readonly property bool any: count > 0
    readonly property bool anyUrgent: history.some(n => n.urgency === NotificationUrgency.Critical)

    // Notifications keep arriving while you are not looking. A hub that shows
    // three hundred is not a hub, it is a log.
    readonly property int maxHistory: Config.values.notifications.maxHistory
    readonly property int defaultTimeout: Config.values.notifications.timeout
    readonly property int maxPopups: Config.values.notifications.maxPopups

    function dismiss(entry: var): void {
        root.popups = root.popups.filter(e => e !== entry);
        root.history = root.history.filter(e => e !== entry);
        entry?.notification?.dismiss();
    }

    function dismissPopup(entry: var): void {
        root.popups = root.popups.filter(e => e !== entry);
    }

    function clear(): void {
        // Copy first: dismiss() mutates the list being walked.
        for (const entry of root.history.slice())
            entry.notification?.dismiss();
        root.history = [];
        root.popups = [];
    }

    function urgencyLabel(n: var): string {
        switch (n?.urgency) {
        case NotificationUrgency.Critical:
            return "critical";
        case NotificationUrgency.Low:
            return "low";
        default:
            return "";
        }
    }

    // A notification's own icon if it gave one, else something that says what
    // kind of thing it is.
    function icon(n: var): string {
        if (n?.urgency === NotificationUrgency.Critical)
            return "priority_high";
        return "notifications";
    }

    NotificationServer {
        id: server

        // Everything we can honestly render. Claiming a capability the shell
        // does not implement makes apps send things that then do not appear.
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: notification => {
            // Tracking is what keeps the object alive past this callback.
            notification.tracked = true;

            const entry = {
                notification: notification,
                time: Date.now()
            };

            root.history = [entry, ...root.history].slice(0, root.maxHistory);

            // Transient notifications are for things like volume OSDs: show,
            // never keep.
            if (notification.transient)
                root.history = root.history.filter(e => e !== entry);

            root.popups = [entry, ...root.popups].slice(0, root.maxPopups);

            // Critical ones stay until acted on: that is what the urgency means.
            if (notification.urgency !== NotificationUrgency.Critical)
                timeout.createObject(root, {
                    entry: entry,
                    interval: notification.expireTimeout > 0 ? notification.expireTimeout : root.defaultTimeout
                });
        }
    }

    Component {
        id: timeout

        Timer {
            required property var entry

            running: true
            onTriggered: {
                root.dismissPopup(entry);
                destroy();
            }
        }
    }
}
