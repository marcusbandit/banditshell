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
    // Off the ENTRY's own urgency, never through .notification. That read has
    // been wrong twice in two different ways: first because `history` held
    // plain { notification, time } wrappers and .urgency off the wrapper was
    // always undefined, and then because the live object dies when the sender
    // closes the notification, so a critical alert from a sender that hung up
    // stopped counting as critical, which is the ONE case the design reserves
    // colour for. The entry snapshots urgency at arrival, so this stays true
    // for as long as the entry does.
    readonly property bool anyUrgent: history.some(e => e.urgency === NotificationUrgency.Critical)

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
    //
    // The MIDDLE tier, not the slow one. Dismissal is the one animation in the
    // shell that is not showing anything: the card is already decided about, and
    // every millisecond of it is time the row below spends waiting to move up.
    // `slow` is for something arriving that wants to be noticed.
    readonly property int exitMs: Appearance.anim.normal

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
        // Everything in flight, deduplicated: a popup that is also in history
        // is one entry in two lists, and destroying it twice is a warning in
        // the log. Transient popups and rows mid-exit are in the union too;
        // the old loop walked only `history`, so a transient popup cleared
        // mid-flight kept its entry (and its tracked notification) forever.
        const all = [...new Set([...root.history, ...root.popups, ...root.leaving])];

        // Lists FIRST, teardown second. `dismiss()` makes the server emit
        // `closed` synchronously, and the entry's closed handler flips `live`,
        // which the arrival hook below answers by expiring popups: with the
        // lists already empty that hook finds nothing to expire and the sweep
        // has nothing to double-handle. Dismissing first re-entered the lists
        // this function was busy emptying.
        root.history = [];
        root.popups = [];
        root.leaving = [];

        for (const entry of all) {
            // `?.` carries the dead-sender case: a notification the sender
            // already closed reads as null here, and there is nobody left to
            // tell anyway.
            entry.notification?.dismiss();
            // Entries are created objects parented to this singleton, so
            // dropping the last reference is not enough to free them; the old
            // clear() leaked every entry it removed. destroy() is deferred by
            // the engine, so the delegates torn down by the list change above
            // never see a half-dead entry.
            entry.destroy();
        }
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

            // THE SENDER CAN HANG UP WHILE THE POPUP IS STILL ON THE SCREEN,
            // and this is the hook that answers it.
            //
            // CloseNotification, or a replace chain ending in one, closes a
            // notification nobody has read yet. The entry hears `closed` and
            // flips `live`, which takes the action pills off the card because
            // there is nobody left to press them at, and until this connection
            // existed that was the whole of the answer: the card stayed on the
            // screen, inert, with no way to act on it. For a Critical one it
            // stayed FOREVER, because its timeout is 0 by design (see
            // timeoutFor), so nothing is counting and no tick will ever expire
            // it; the only ways out were throwing it away by hand or clearing
            // the tray. A card that cannot be acted on and will not leave is
            // exactly what `live` was added to let this service answer, and
            // NotifEntry has promised for as long as the flag has existed that
            // the answer is made here.
            //
            // EXPIRED, not dismissed. A sender withdrawing its notification is
            // not you reading it, so the row leaves the screen and stays in the
            // hub with the words it arrived with, which is the same answer this
            // service already gives a popup that merely ran out of time.
            //
            // Connected from HERE rather than decided inside the entry, because
            // an entry does not know whether it is a popup, and deciding list
            // membership from inside a list element is how re-entrancy bugs
            // start. The membership test is the other half of that: drop() and
            // clear() both take an entry out of the lists and THEN dismiss it,
            // and every one of those dismissals comes straight back here as a
            // `live` flip. Finding the entry already gone from `popups` is how
            // this hook knows there is nothing left to take off the screen,
            // rather than putting an entry that is being torn down back into
            // `leaving` for the sweep to walk over.
            entry.liveChanged.connect(() => {
                if (!entry.live && root.popups.includes(entry))
                    root.expire(entry);
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
                // AND THE SENDER'S OBJECT WITH IT, which is the one this branch
                // used to forget. `tracked` above is what asks quickshell to
                // hold the Notification past this callback, and it holds every
                // tracked one until the notification is CLOSED: destroying our
                // entry drops our reference and nothing else, so an evicted one
                // stranded its Notification, and with it the decoded image the
                // notification carries (a full-size avatar or album cover), for
                // the life of the shell. Once `maxHistory` is reached that is
                // one stranded object per notification arriving, which on a
                // chatty session is all of them. drop() and clear() both do
                // this already; eviction is the third door out of the lists and
                // it has the same duty. `?.` because a sender that hung up long
                // ago reads as null here and needs no telling.
                old.notification?.dismiss();
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
