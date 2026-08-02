import QtQuick

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

    property var notification: null
    property double time: 0

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
