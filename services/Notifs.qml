pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
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

    // Countdowns stop while a tray is open. A notification that expires out
    // from under the list you are reading is the same bug as one expiring under
    // the pointer, one level up.
    //
    // WHO IS HOLDING THEM STILL, rather than a flag every tray assigns. There is
    // one tray per monitor (shell.qml wraps the whole shell in Variants over
    // Quickshell.screens), and while this was a bool they all wrote, whichever
    // one moved LAST decided for all of them: collapsing an empty tray on the
    // second screen, one that had never been opened and had nothing in it,
    // resumed every countdown under the list being read on the first. That is the
    // same mistake the tray's own `expanded` records one level up, and it takes
    // the same answer, because a set has no ordering to get wrong. The countdowns
    // stand still while ANY claim is still out and start again when the last of
    // them is dropped.
    property var pausedBy: []

    // Which makes this the cache of an answer rather than the answer, and it is
    // derived so that it cannot be anything else. Read by the ticker below, and
    // by nothing outside this file: who is holding the countdowns is the set's
    // business and nobody asks.
    readonly property bool paused: root.pausedBy.length > 0

    // A claim is an OBJECT, never a name and never a count. The holder is the
    // key, so a tray saying the same thing twice is one claim and cannot be
    // released twice, and no tray can drop another one's. It is asked for rather
    // than assigned because membership of a list this service owns is this
    // service's to decide, which is the rule `history` and `popups` are already
    // kept by.
    //
    // A HOLDER THAT DIES STILL HOLDING would stop every countdown in the shell
    // for as long as it runs, with nothing left anywhere that could take the
    // claim back, and a monitor being unplugged destroys a tray in exactly that
    // state. So a tray drops its claim from Component.onDestruction, the way a
    // ShellWindow unregisters itself (services/Shell.qml), and the filter here is
    // the second half of that promise: a destroyed QObject reads as falsy, so
    // anything that did get away is swept out by the next claim either way.
    function pause(who: var): void {
        if (root.pausedBy.includes(who))
            return;
        root.pausedBy = [...root.pausedBy.filter(w => w), who];
    }

    function resume(who: var): void {
        root.pausedBy = root.pausedBy.filter(w => w && w !== who);
    }

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

    // Thrown off the SCREEN, or acted on there. A decision, so it does not come
    // back.
    //
    // UNLESS IT WAS PINNED, which is worth exactly one of these: the row leaves
    // the screen and stays in the hub, with the words it arrived with, which is
    // the whole of what a pin is for. The pin is SPENT doing it, so nothing is
    // left holding the notification anywhere.
    function dismiss(entry: var): void {
        if (!entry || entry.leaving)
            return;
        const spare = entry.pinned;
        entry.pinned = false;
        root.beginLeave(entry, !spare);
    }

    // Thrown out of the HUB, which is a different sentence and needs its own
    // door.
    //
    // A pin means "keep this after it leaves the screen", and in the hub it has
    // already arrived there: there is nowhere further back to go, so honouring a
    // pin here would answer a deliberate swipe by taking the row off a list it is
    // still on, which drop() reads as "put it back" and the card visibly bounces.
    // The hub is the last stop, so this forgets whatever it is given.
    function forget(entry: var): void {
        if (!entry || entry.leaving)
            return;
        entry.pinned = false;
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
        // AND THE COPY OF ITS PICTURE, which is this shell's file rather than
        // the sender's and so is nobody else's to clean up. Entries leave the
        // lists by three doors (here, clear(), and eviction on arrival) and
        // every one of them has to say this, or the cache grows by one file per
        // notification for as long as the shell runs.
        root.erase(entry.cached);
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
            // The second of the three doors, and the one that opens widest:
            // clearing the tray is where the whole cache goes at once.
            root.erase(entry.cached);
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

    // ------------------------------------------------------------------
    // WHERE A BORROWED PICTURE IS COPIED TO.
    //
    // A notification that carries its avatar as raw pixels hands out a url into
    // a provider it owns, and that url is worth nothing once the sender hangs
    // up: see the long argument in NotifEntry, which is where the policy lives.
    // The copy itself is taken by the card, because a picture can only be
    // copied by something that can draw it and the card is the only part of
    // this that is in a window. This end owns the DIRECTORY.
    //
    // THE CACHE DIRECTORY, not the state one AppIcons and Usage write to, and
    // the difference is the whole reason it is somewhere else. Those two keep a
    // record: what you chose, when the machine was awake, things whose loss is
    // a loss. This holds copies of pictures belonging to notifications that do
    // not themselves survive a restart, so every byte of it is disposable by
    // construction and the right place for it is the directory whose whole
    // meaning is "safe to delete". XDG_CACHE_HOME when the session sets one,
    // which it usually does not, and the spec's own default otherwise.
    readonly property string cacheRoot: `${Quickshell.env("XDG_CACHE_HOME") || `${Quickshell.env("HOME")}/.cache`}/banditshell/notifications`

    // AND A ROOM OF ITS OWN INSIDE IT, named after the process that writes there
    // and the moment that process last loaded its configuration.
    //
    // ONE SHARED DIRECTORY WAS A SHELL DELETING ANOTHER SHELL'S PICTURES. The
    // path above is a constant per user, nothing in it says who owns the files,
    // and the sweep below is the first thing an instance does. Only one process
    // on the session can own the notification bus name (see the header), but
    // starting a second one is neither hard nor rare: `banditshell run` is the
    // documented way to see QML errors and, unlike `start`, it does not check
    // whether the shell is already up. That second instance cannot serve a
    // single notification, and it used to delete every copy the FIRST one was
    // relying on, so every entry whose sender had already hung up silently lost
    // its picture. Under a name nobody else writes, a second instance cannot
    // reach the first one's files at all.
    //
    // THE RELOAD IS THE SECOND HALF of the name. `keepOnReload` is false, so a
    // configuration reload leaves this service with an empty history and every
    // copy taken before it orphaned with no entry left to erase it: the room has
    // to change when the engine does, and the process id alone does not. Date is
    // a fine tiebreak for a directory that only has to differ from the last one,
    // and the expression is evaluated once because nothing in it is reactive.
    readonly property string cacheName: `${Quickshell.processId}-${Date.now()}`
    readonly property string cacheDir: `${root.cacheRoot}/${root.cacheName}`

    // THE SWEEP, which is now the only thing that deletes anything it did not
    // write, and deletes nothing anybody is still writing to.
    //
    // Its own room is made and never emptied, because it is brand new: there is
    // nothing in it to reconcile, and that is what took the race out of this.
    // The old sweep wiped the directory it was about to be given copies in, and
    // it does that asynchronously, so a picture that landed before the process
    // was scheduled was deleted by the very command meant to precede it. What is
    // left is a copy completing before `mkdir` returns, which costs that one
    // picture the fallback it would have had and never costs a good file.
    //
    // What it takes instead is every OTHER room whose owner is gone, which is
    // the leak the per-entry deletions cannot reach: a shell killed with copies
    // outstanding, which is every crash and every `banditshell restart`. `/proc`
    // is the liveness test, and it is exact rather than a guess about age. A
    // room belonging to a live process is left alone unless that process is this
    // one, which is how the reload's own leftovers go.
    //
    // NOTHING ELSE IS TOUCHABLE. Only names shaped like a room (digits, a dash,
    // digits) and stray `*.png` from the flat layout this replaced can be
    // deleted at all, so a wrong turn in the path above still costs somebody
    // their pictures at worst rather than their documents, which is the property
    // the old one-line `rm -f` had by construction and this one has to say out
    // loud. `\${n%%-*}` is the shell's own way of naming the part before the
    // first dash; the backslash is QML's, since a bare `${` inside a template
    // literal is read by the engine instead of by sh.
    Process {
        id: sweep

        command: ["sh", "-c", `
            mkdir -p '${root.cacheDir}' && cd '${root.cacheRoot}' || exit 0
            for n in *; do
                case "$n" in
                *.png)
                    rm -f "./$n"
                    ;;
                [0-9]*-[0-9]*)
                    [ "$n" = '${root.cacheName}' ] && continue
                    p=\${n%%-*}
                    [ "$p" != '${Quickshell.processId}' ] && [ -d "/proc/$p" ] && continue
                    rm -rf "./$n"
                    ;;
                esac
            done
        `]
        running: true
    }

    // Files nobody wants any more, waiting on the eraser.
    property var doomed: []

    function erase(path: string): void {
        if (!path)
            return;
        root.doomed = [...root.doomed, path];
        // COALESCED, because the paths arrive in bursts: clearing the tray
        // orphans every copy in it inside one turn, and that would otherwise be
        // fifty processes to delete fifty files. Qt.callLater lets the whole
        // burst pile up and go out as one command line.
        Qt.callLater(root.flush);
    }

    function flush(): void {
        // One at a time. A Process is a single slot, so handing it a new
        // command while it is still running would drop the batch in flight;
        // whatever piles up meanwhile goes out on the next exit.
        if (eraser.running || root.doomed.length === 0)
            return;
        eraser.command = ["rm", "-f", ...root.doomed];
        root.doomed = [];
        eraser.running = true;
    }

    Process {
        id: eraser

        // DEFERRED, not called straight out of the handler. `flush` refuses to
        // start a second batch while `running` is true, and a process reporting
        // its own exit is the one moment that flag is least worth trusting: a
        // read that still said true here would drop whatever piled up during the
        // last batch and leave those files on disk until the next deletion
        // happened to come along. A turn later the answer is settled.
        onExited: Qt.callLater(root.flush)
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
                timeout: root.timeoutFor(notification),
                // Told once, at construction. An entry needs to know where a
                // copy of its picture may be put and nothing else about this
                // service; reading it back off the singleton would be a list
                // element reaching into the list, which this file already
                // refuses to do for membership and refuses here for the same
                // reason.
                cacheDir: root.cacheDir
            });

            // A copy the entry is done with: a picture replaced by a newer one,
            // or a grab that landed after the sender had already moved on.
            // Connected from here rather than deleted by the entry, because
            // deleting is a process and the entry has no business starting one:
            // the eraser is one queue for the whole shell, so a burst of
            // replaces costs one command line instead of one per file.
            entry.orphaned.connect(path => root.erase(path));

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
                // The third door, and the one that decides the cache's SIZE: an
                // evicted entry is exactly a notification the history no longer
                // keeps, so a cache that did not delete here would be a cache
                // with no cap at all, growing by one avatar per notification for
                // the life of the session.
                root.erase(old.cached);
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
