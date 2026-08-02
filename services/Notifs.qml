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

    // Countdowns stop while the tray is open. A notification that expires out
    // from under the list you are reading is the same bug as one expiring under
    // the pointer, one level up.
    property bool paused: false

    // How long a row has to get itself off the screen. Fixed rather than
    // exponential, unlike everything else in the shell, because the SERVICE has
    // to know when the animation is done: a card leaving is a one-shot A to B,
    // not something tracking a moving target, and one duration read by both ends
    // means they agree by construction instead of by a callback.
    readonly property int exitMs: Appearance.anim.slow

    // Removal is TWO-PHASE. Taking a row out of the list immediately gives the
    // view nothing to animate: the card is destroyed on the same frame and the
    // stack jumps. So this marks the entry and the sweep below finishes the job
    // once the card has had its exit.
    function beginLeave(entry: var, forget: bool): void {
        if (!entry || entry.leaving)
            return;
        entry.forget = forget;
        entry.leaveElapsed = 0;
        entry.leaving = true;
        root.leaving = [...root.leaving, entry];
    }

    // Thrown away, or acted on. A decision, so it does not come back.
    function dismiss(entry: var): void {
        root.beginLeave(entry, true);
    }

    // Merely out of time. It leaves the screen and stays in the tray, because it
    // is still a notification nobody has read.
    function expire(entry: var): void {
        root.beginLeave(entry, false);
    }

    // Phase two: the row is off the screen, so it can actually go.
    function drop(entry: var): void {
        root.leaving = root.leaving.filter(e => e !== entry);
        root.popups = root.popups.filter(e => e !== entry);

        // Back to rest, because the SAME object is still in the tray. A
        // transient one is not: it was never put in the history, so timing out
        // is the end of it and nothing else will ever free it.
        if (!entry.forget && root.history.includes(entry)) {
            entry.leaving = false;
            entry.leaveElapsed = 0;
            return;
        }

        root.history = root.history.filter(e => e !== entry);
        entry.notification?.dismiss();
        // Entries are created objects parented to this singleton, so dropping
        // the last reference is not enough to free them.
        entry.destroy();
    }

    function clear(): void {
        // Copy first: this mutates the lists being walked.
        for (const entry of root.history.slice())
            entry.notification?.dismiss();
        root.history = [];
        root.popups = [];
        root.leaving = [];
    }

    // On their way out, waiting on the sweep.
    property var leaving: []

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
        running: root.popups.length > 0 || root.leaving.length > 0

        onTriggered: {
            if (!root.paused) {
                const done = [];
                for (const entry of root.popups)
                    if (entry.tick(interval))
                        done.push(entry);
                for (const entry of done)
                    root.expire(entry);
            }

            // The sweep runs whether or not the countdowns do: a row already on
            // its way out has to land even while the tray is held open.
            const gone = [];
            for (const entry of root.leaving) {
                entry.leaveElapsed += interval;
                if (entry.leaveElapsed >= root.exitMs)
                    gone.push(entry);
            }
            for (const entry of gone)
                root.drop(entry);
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
            for (const old of evicted) {
                // It can still be on screen: maxPopups and maxHistory are
                // different numbers, and destroying an object the stack is
                // holding leaves the view with a dangling row.
                root.popups = root.popups.filter(e => e !== old);
                root.leaving = root.leaving.filter(e => e !== old);
                old.destroy();
            }

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
