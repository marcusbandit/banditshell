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
    // Through .notification: `history` holds { notification, time } wrappers, so
    // reading .urgency off the wrapper is always undefined and the sidebar never
    // went accent for a critical notification, which is the ONE case the design
    // reserves colour for.
    readonly property bool anyUrgent: history.some(e => e.notification?.urgency === NotificationUrgency.Critical)

    // How long a popup lives, in ms. 0 means it stays until acted on.
    function timeoutFor(n: var): int {
        if (n?.urgency === NotificationUrgency.Critical)
            return 0;
        return n?.expireTimeout > 0 ? n.expireTimeout : root.defaultTimeout;
    }

    // Notifications keep arriving while you are not looking. A hub that shows
    // three hundred is not a hub, it is a log.
    readonly property int maxHistory: Config.values.notifications.maxHistory
    readonly property int defaultTimeout: Config.values.notifications.timeout
    readonly property int maxPopups: Config.values.notifications.maxPopups

    function dismiss(entry: var): void {
        root.popups = root.popups.filter(e => e !== entry);
        root.history = root.history.filter(e => e !== entry);
        entry?.notification?.dismiss();
        // Entries are created objects parented to this singleton, so dropping
        // the last reference is not enough to free them.
        entry?.destroy();
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

    Component {
        id: entryComponent

        NotifEntry {}
    }

    // ONE ticker for every popup. Per-card timers were both duplicated work and
    // the thing that reset itself whenever the list changed.
    Timer {
        interval: 50
        repeat: true
        running: root.popups.length > 0

        onTriggered: {
            const done = [];
            for (const entry of root.popups)
                if (entry.tick(interval))
                    done.push(entry);
            for (const entry of done)
                root.dismissPopup(entry);
        }
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

            const entry = entryComponent.createObject(root, {
                notification: notification,
                time: Date.now(),
                timeout: root.timeoutFor(notification)
            });

            // Anything pushed off the end of the history is gone for good, so
            // it has to be destroyed rather than merely forgotten.
            const evicted = [entry, ...root.history].slice(root.maxHistory);
            root.history = [entry, ...root.history].slice(0, root.maxHistory);
            for (const old of evicted)
                old.destroy();

            // Transient notifications are for things like volume OSDs: show,
            // never keep.
            if (notification.transient)
                root.history = root.history.filter(e => e !== entry);

            root.popups = [entry, ...root.popups].slice(0, root.maxPopups);
            // The countdown lives on the card, not here: it has to be a
            // reactive value so the card can draw it, and it has to pause while
            // the cursor is on the card, which only the card knows.

        }
    }

}
