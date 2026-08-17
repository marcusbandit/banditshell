import QtQuick
import Quickshell
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

    // HOW FAR ALONG THE SENDER SAYS IT IS, 0..100, from the `value` hint. -1 is
    // "no progress in this packet", which is nearly every notification.
    //
    // A sentinel rather than a companion `hasProgress` flag: two properties that
    // together mean one thing are two properties that can disagree, and the one
    // that would go stale is the flag, leaving a bar drawn at whatever number
    // was last in the other.
    property real progress: -1

    // WHICH DESKTOP ENTRY THE SENDER SAYS IT IS, snapshotted with the rest of
    // it. The spec's `desktop-entry` hint, and the only field in the packet that
    // names the APPLICATION rather than the notification: `appName` is a display
    // string a sender may write any way it likes ("discord", "Discord", "Discord
    // Canary"), where this is an id that matches something on disk. It is what
    // `mark` below reaches the shell's own icon table with, so a Discord
    // notification can wear the same mark a Discord window wears.
    //
    // Measured on this machine: Discord sends `desktop-entry=discord`, and
    // quickshell fills `appIcon` in from it when the sender gave no app_icon of
    // its own, so the two agree far more often than the spec promises. Kept
    // separately all the same, because the day they disagree is the day this
    // field is the one that is right.
    property string desktopEntry: ""

    // WHERE A COPY OF THE PICTURE MAY BE PUT, handed in by the service that
    // created this entry rather than read back off it.
    //
    // An entry is a list element and the service owns the list, the directory,
    // and the sweep; this is the one thing it has to be TOLD, and being told it
    // once at construction is what keeps an entry from calling back into the
    // thing that made it. See Notifs.cacheDir for what the directory is and why
    // it is not the state directory the rest of the shell writes to.
    property string cacheDir: ""

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

    // ------------------------------------------------------------------
    // THE PICTURE, which is the one snapshot field that is not a copy of what
    // the sender SAID but a copy of WHERE THE SENDER KEPT IT.
    //
    // Measured, on this machine, against a real Discord notification and
    // against gdbus sending the same shape by hand:
    //
    //   image-data (raw pixels in the packet, which is what Discord and every
    //   other Electron app send, because notify_notification_set_image_from_pixbuf
    //   is how they hand over an avatar) arrives as `image://qsimage/93/1`.
    //   That is a url into a provider the NOTIFICATION OBJECT owns, so the
    //   moment the sender hangs up the registration goes with it and the url
    //   resolves to nothing: "Failed to get image from provider" in the log,
    //   once per card, and the generic bell on screen. Copying the string into
    //   the snapshot copies a pointer to something about to be freed.
    //
    //   image-path (a filename in the packet, which is what this shell's own
    //   screenshot notification sends) arrives as `image://icon//path/to.png`,
    //   and THAT provider is quickshell's global icon provider. It answers for
    //   as long as the file is on disk, which is why one card in a tray full of
    //   dead Discord avatars kept its picture and made the whole thing look
    //   like a design choice.
    //
    // So a picture that came as data has to be copied out of the sender's
    // memory and into a file of our own before the sender lets go. Nothing here
    // can do that: see the copier in modules/notifications/NotificationCard.qml,
    // which lives in a window and is therefore the only part of this that Qt
    // will render anything for. This end owns the POLICY: which pictures need
    // copying, where the copy goes, which copy is current, and which files are
    // rubbish now.
    //
    // BORROWED: a picture we are looking at through somebody else's window.
    // Tested by exclusion rather than by naming `qsimage`, and the direction of
    // the guess is the point. Every url quickshell hands out that is NOT the
    // shared icon provider belongs to an object with a lifetime, so a provider
    // this shell has never heard of is copied too: the cost of copying
    // something that did not need it is one file in a directory that is already
    // capped, and the cost of NOT copying something that did is the bug this
    // whole mechanism exists to remove, reappearing silently the day quickshell
    // renames a provider. A bare path or a file: url is nobody's to revoke and
    // is left alone.
    readonly property bool borrowed: root.borrows(root.image)

    // ASKED OF A URL rather than read off `image`, because the card taking the
    // copy is holding a load of the url it LATCHED, and a replace can hand this
    // entry a different one while that load is still in flight. The card is the
    // only thing that knows which picture its own pixels came from, so it has to
    // be able to ask these two questions about that url and not about whatever
    // is current by the time they land. The current picture is the common case
    // and keeps the plain property above.
    function borrows(url: string): bool {
        return url.startsWith("image://") && !url.startsWith("image://icon/");
    }

    // WHERE THIS PICTURE'S COPY GOES, keyed on the url it is a copy OF.
    //
    // Not on the entry, which would be the obvious key and is wrong: a replace
    // (Discord edits its notifications constantly) hands the same entry a NEW
    // provider url, and one file per entry would mean writing the new picture
    // over the old path. Qt caches a decoded image by its url, so the card
    // would go on drawing the old avatar out of the pixmap cache from a file
    // that no longer contains it, which is a bug that only shows up for the
    // people who get a lot of notifications. Keyed on the url, a new picture is
    // a new file and the old one becomes rubbish the moment it is replaced.
    //
    // Non-alphanumerics collapse to a dash rather than being percent-encoded,
    // because this name is never parsed back: it only has to be unique per url
    // and safe to hand to `rm`.
    readonly property string copyPath: root.copyPathFor(root.image)

    // The naming rule itself, kept in one place for the same reason `borrows` is
    // a function: the card names the file it is writing after the url its pixels
    // actually came from, and it must not do that by rebuilding this expression
    // in its own file. The directory is read first so that a binding on this
    // depends on it even when the url is not one worth copying, which is the
    // ordering that makes `copyPath` re-evaluate if the entry is ever told where
    // the cache is after construction.
    function copyPathFor(url: string): string {
        if (!root.cacheDir || !root.borrows(url))
            return "";
        return `${root.cacheDir}/${url.replace(/[^a-zA-Z0-9]+/g, "-")}.png`;
    }

    // The copy that has actually been WRITTEN, which is not the same question
    // as where it would go. Empty until a card has taken it.
    property string cached: ""

    // Whether a copy is being taken right now. Every screen draws its own card
    // for the same entry, so without this each of them would separately load
    // the picture and grab it to the same file.
    property bool copying: false

    // A file this entry is done with. The service that made the entry is
    // listening; the entry does not know how to delete anything and should not,
    // for the same reason it does not decide its own list membership.
    signal orphaned(path: string)

    readonly property bool wantsCopy: root.live && root.copyPath !== "" && root.cached !== root.copyPath && !root.copying

    // A copy landed. Guarded rather than trusted, because the grab is
    // asynchronous and a replace can land while it is in flight: a copy of a
    // picture the sender has already moved on from is rubbish the moment it is
    // written, and saying so here is cheaper than teaching the card to check.
    function keep(path: string): void {
        if (path !== root.copyPath)
            return root.orphaned(path);

        // ALREADY HOLDING THIS EXACT FILE, which is not a harmless repeat but a
        // deletion if it is not said here. `retire()` below hands whatever
        // `cached` names to the service, and the service's answer to an orphan
        // is `rm -f`: keeping a path that is already the cached one would erase
        // the picture and then set `cached` back to the name of the file it had
        // just deleted. The entry would go on advertising a copy that is no
        // longer on disk, `picture` would hand the card a dead path the moment
        // the sender hung up, and the card would fall back to the app mark with
        // no picture at all: silently, and precisely the failure this whole
        // mechanism exists to remove.
        //
        // Reachable whenever two cards complete a copy of the same url, which
        // costs the same bytes written twice and nothing else once this returns
        // early. See NotificationCard's claim, which is what makes that rare
        // rather than routine.
        if (path === root.cached)
            return;

        root.retire();
        root.cached = path;
    }

    // Let go of whatever copy we were holding.
    function retire(): void {
        if (!root.cached)
            return;
        root.orphaned(root.cached);
        root.cached = "";
    }

    // WHAT THE CARD ACTUALLY DRAWS, and the swap is deliberately late.
    //
    // While the sender is alive its own url is the better source: it is already
    // decoded, it is what the popup is drawing at the moment it arrives, and
    // reaching for our copy instead would swap an Image's source out from under
    // a card that is already showing the picture, which costs a reload and a
    // visible flinch in the badge for nothing. The copy is what the card falls
    // back to when the sender lets go, which is the exact moment the borrowed
    // url stops answering.
    //
    // Reactive on both terms, so a copy that lands AFTER the sender hung up
    // still gets picked up: `cached` changing re-evaluates this and the bell
    // turns back into the avatar.
    readonly property string picture: (root.live || !root.cached) ? root.image : root.cached

    // ------------------------------------------------------------------
    // WHO SENT IT, resolved to something drawable and resolved HERE.
    //
    // The other half of the same complaint. A picture is what the notification
    // is ABOUT and this is who it is FROM, and the card had only ever been
    // handed the raw `app_icon` string, which is a freedesktop icon NAME and
    // fails silently as an image source. Resolved in the entry rather than in
    // the card because it is a lookup and not a drawing decision, and because
    // the answer has to outlive the sender exactly the way the words do: every
    // input below is a snapshot, so this keeps answering after the object is
    // gone.
    //
    // The order runs from what the sender said about THIS notification down to
    // what the shell knows about the application in general:
    //
    //   The sender's own app_icon, as a path when it is one. The spec allows
    //   app_icon to be a file, and an Image will take it as-is.
    //
    //   The sender's own app_icon, as a theme name. This is the common case and
    //   the one that was broken: Discord sends `discord`, the theme has
    //   `discord.svg`, and nothing was asking the theme.
    //
    //   What YOU picked for this application, from services/AppIcons.qml, when
    //   the pick names a file. It is below the sender's own answer rather than
    //   above it, which is the opposite of AppIcons.markFor's own order, and on
    //   purpose: a pick exists to overrule what the SHELL worked out, and the
    //   sender naming its own icon is not something the shell worked out.
    //
    //   Then the desktop entry, through Apps.iconSourceFor, which is the same
    //   call AppIcons.markFor makes for the workspace column: so in the mode
    //   where that column draws real icons, a Discord notification and a
    //   Discord window end up on the same file by construction rather than by
    //   coincidence.
    //
    // markFor's SPEC was rejected as the thing to reuse, though it answers a
    // near-identical question. It is keyed by window class, which a
    // notification does not have; and it answers with `symbol:` and `glyph:`
    // forms as often as with a file, because it is feeding components/AppMark,
    // which is a mark drawn in the shell's own colour. This badge is a picture
    // slot, and the user's complaint was that it was showing them a shell glyph
    // instead of the sender's own artwork.
    readonly property string mark: root.markFor()

    function markFor(): string {
        if (root.appIcon.startsWith("/") || root.appIcon.startsWith("file:"))
            return root.appIcon;

        const themed = root.appIcon ? Quickshell.iconPath(root.appIcon, true) : "";
        if (themed)
            return themed;

        // The entry id first and the display name second, because the id is
        // what matches something on disk and the name is a string a sender
        // wrote for a human. Both are tried, because plenty of senders give
        // neither hint and their name is all there is to go on.
        const names = [root.desktopEntry, root.appName].filter(n => n);

        for (const name of names) {
            const picked = AppIcons.specFor(name);
            if (AppIcons.isFile(picked))
                return picked.slice(picked.indexOf(":") + 1);
        }

        return Apps.iconSourceFor(names);
    }

    function snapshot(): void {
        const n = root.notification;
        if (!n)
            return;
        root.appName = n.appName;
        root.summary = n.summary;
        root.body = n.body;
        root.appIcon = n.appIcon;
        root.desktopEntry = n.desktopEntry;

        // THE PICTURE MOVED, which a replace does and nothing else does. The
        // copy we are holding is a copy of the old one, so it is rubbish now,
        // and the in-flight-copy flag has to come down or the new picture would
        // never be copied at all: `wantsCopy` is what a card watches, and it
        // would sit false forever behind a flag that belonged to a load that
        // finished long ago.
        if (n.image !== root.image) {
            root.retire();
            root.image = n.image;
            root.copying = false;
        }

        root.urgency = n.urgency;
        root.hasActions = (n.actions?.length ?? 0) > 0;

        // Hints are a map the SENDER fills in, so `value` is whatever arrived
        // over the bus: usually absent, and not necessarily a number when it is
        // there. Anything unusable reads as "no progress" rather than as 0,
        // because 0 would draw an empty bar on a notification that never asked
        // for one, and an empty bar is a claim that something is stuck.
        const v = n.hints?.value;
        root.progress = typeof v === "number" && isFinite(v) ? Math.max(0, Math.min(100, v)) : -1;

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
        function onDesktopEntryChanged(): void {
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

        // A progress sender may move ONLY the hint, leaving summary and body
        // exactly as they were. Without this the bar would still creep along,
        // but only on the ticks where some other field happened to change too,
        // which is the sort of bug that looks like a stutter rather than a
        // missing connection.
        function onHintsChanged(): void {
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

    // PINNED: swiped left, or press-and-held. Two things at once. The countdown
    // stops, and the next dismissal HIDES this notification instead of forgetting
    // it, so it is still in the hub afterwards.
    //
    // On the ENTRY rather than on the card, for the reason this whole file
    // exists: the tray swaps its delegates when it expands, and a pin living in a
    // card would be lost by the row next to it being dismissed.
    property bool pinned: false

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

    // `pinned` as well as `held`, though the card folds the pin into `held`
    // anyway: an entry with no card on any screen still has to stop counting, and
    // `held` is only ever written by a card.
    readonly property bool running: timeout > 0 && remaining > 0 && !held && !pinned && !leaving

    function tick(ms: int): bool {
        if (!root.running)
            return false;
        root.remaining = Math.max(0, root.remaining - ms / root.timeout);
        return root.remaining <= 0;
    }
}
