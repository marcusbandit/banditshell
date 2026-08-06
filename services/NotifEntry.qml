import QtQuick
import Quickshell.Services.Notifications

// One notification's own state, as a real object.
//
// It is NOT a plain JS record, and that is the whole point. A Repeater over a
// plain array rebuilds every delegate whenever the array changes, so any state
// living in a delegate is destroyed and reset by its NEIGHBOUR being dismissed.
// The countdowns lived in the cards, and every expiry reset the timers of every
// other popup, so after the first one nothing ever expired again.
//
// State that belongs to a notification lives with the notification. The card
// binds to it and can be rebuilt as often as the list likes.
QtObject {
    id: root

    // The server's live object, kept ONLY for talking back to the sender:
    // invoking an action, telling the bus a dismissal happened. It is
    // Quickshell's object and it dies when the SENDER says so, not when we
    // do: CloseNotification, or a replace chain ending in one, destroys it
    // under us, and from then on every read through this reference yields
    // null. Nothing that DISPLAYS may read through it; that is what the
    // snapshot below is for.
    property var notification: null
    property double time: 0

    // THE ENTRY OWNS WHAT IT SHOWS. These are copies, not bindings.
    //
    // The card used to read every field through `notification`, which worked
    // exactly until the sender hung up. Chatty apps close and replace their
    // notifications constantly (Discord most of all), and a closed
    // notification's object is destroyed by the server, so every card over a
    // dead one collapsed to the fallback bell on a bare fill row: history
    // filled with tombstones and read as "notifications disappear". A
    // notification is a thing that HAPPENED; what it said is not the sender's
    // to unsay by hanging up.
    //
    // Copied at arrival, and re-copied whenever the live object changes,
    // because a replace (notify-send -r, Discord edits, progress updates)
    // mutates the SAME object in place rather than sending a new one: a
    // snapshot that never followed would freeze every updating notification at
    // its first version. When the object dies the change signals stop coming
    // and the snapshot simply stops changing, which is exactly what history
    // wants.
    property string appName: ""
    property string summary: ""
    property string body: ""
    property string appIcon: ""
    property string image: ""
    property int urgency: NotificationUrgency.Normal
    property bool hasActions: false

    // Whether the sender's object is still there to be talked TO. Display
    // never needs it; invoking an action does, and the card hides its action
    // pills on this, because a button that cannot invoke is worse than no
    // button.
    //
    // A flag flipped by `closed` below, NOT a binding on `notification`,
    // because destruction nulls a var's referent WITHOUT a change signal: an
    // expression like `notification !== null` reads false ever after but
    // nothing re-evaluates it, so it would go stale at exactly the moment it
    // exists for. Quickshell emits `closed` before destroying the object on
    // every path (expiry, dismissal, CloseNotification), so this is reliably
    // reactive where the null test is not.
    property bool live: false

    function snapshot(): void {
        const n = root.notification;
        if (!n)
            return;
        root.appName = n.appName;
        root.summary = n.summary;
        root.body = n.body;
        root.appIcon = n.appIcon;
        root.image = n.image;
        root.urgency = n.urgency;
        root.hasActions = (n.actions?.length ?? 0) > 0;
        root.live = true;
    }

    // Both doors, deliberately. The changed handler covers the property being
    // handed to createObject, and Component.onCompleted covers any engine that
    // applies initial properties without a change signal; snapshot() is
    // idempotent, so taking it twice costs a few reads and buys not caring
    // which of the two fired first.
    onNotificationChanged: root.snapshot()
    Component.onCompleted: root.snapshot()

    // Follows the live object while it lives. Declared as a property because
    // a QtObject is the right base for an entry and children are not what
    // this is; a property holding the Connections keeps it owned by the
    // entry, so it dies with the entry and a notification that outlives us
    // (evicted history) never signals into a destroyed object.
    //
    // A dead or null target is fine: Connections goes quiet, which is the
    // snapshot ceasing to change, which is the behaviour we want spelled as
    // the absence of code.
    readonly property Connections follow: Connections {
        target: root.notification

        function onAppNameChanged(): void {
            root.snapshot();
        }
        function onSummaryChanged(): void {
            root.snapshot();
        }
        function onBodyChanged(): void {
            root.snapshot();
        }
        function onAppIconChanged(): void {
            root.snapshot();
        }
        function onImageChanged(): void {
            root.snapshot();
        }
        function onUrgencyChanged(): void {
            root.snapshot();
        }
        function onActionsChanged(): void {
            root.snapshot();
        }

        // The sender hung up (or we dismissed and the server is echoing it
        // back). The snapshot is already taken, so nothing to save; the one
        // job here is flipping `live` so the card stops offering buttons that
        // cannot answer. What happens to the entry itself is Notifs' call,
        // made off liveChanged where the entry is created (the connection is in
        // Notifs' onNotification, and it expires a popup whose sender hung up):
        // the ENTRY does not know whether it is a popup, and deciding list
        // membership from inside a list element is how re-entrancy bugs start.
        function onClosed(): void {
            root.live = false;
        }
    }

    // How long this popup lives, in ms. 0 means it stays until acted on.
    property int timeout: 0

    // 1 down to 0.
    property real remaining: timeout > 0 ? 1 : 0

    // Set by whichever card is showing this: a notification must not expire from
    // under the pointer while you are reaching for its button.
    property bool held: false

    // On its way out, and how long it has been going. Removal is two-phase so
    // the card can animate before its row actually disappears; see Notifs.
    property bool leaving: false
    property int leaveElapsed: 0

    // Whether leaving means GONE, or merely off the screen.
    //
    // The difference the tray is built on: a popup that timed out is still a
    // notification you have not read, and the tray must still have it. One you
    // threw away is a decision, and it does not come back.
    property bool forget: false

    readonly property bool running: timeout > 0 && remaining > 0 && !held && !leaving

    function tick(ms: int): bool {
        if (!root.running)
            return false;
        root.remaining = Math.max(0, root.remaining - ms / root.timeout);
        return root.remaining <= 0;
    }
}
