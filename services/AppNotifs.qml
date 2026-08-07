pragma Singleton

import QtQuick
import Quickshell

// WHICH APPLICATION EACH NOTIFICATION CAME FROM.
//
// Notifs is a daemon and its history is a stream: one flat list, newest first,
// which is exactly right for a tray and says nothing at all about the thing a
// launcher wants to know, which is "how many is Discord sitting on". So this is
// the index over it, and it is a third file rather than a property on either
// side because it belongs to neither: Notifs must not learn what a desktop entry
// is to serve a notification, and Apps must not pull the notification bus up to
// list what is installed.
//
// THE MATCH IS THE WHOLE PROBLEM, and it has two answers of very different
// quality.
//
//   `desktop-entry` is the spec's own hint and it is an ID: an app that sends it
//   is telling you exactly which file on disk it is, and that is the answer.
//
//   `app_name` is a DISPLAY STRING, sender-controlled, and half of them do not
//   send the hint at all. "Firefox" has to reach `firefox.desktop`, and
//   `org.telegram.desktop` has to reach whatever the entry is actually called.
//   That is the same tangle Apps already went through for icons, so it is asked
//   rather than solved twice: nameVariants takes the string apart the way an
//   icon theme's names are taken apart, and heuristicLookup does the matching.
//
// Anything that resolves to nothing is simply not counted. A notification from a
// process with no desktop entry (a script, a `notify-send` from a terminal) is a
// real notification and there is no row in the launcher it could belong to; the
// tray is where it is read, and it stays there.
Singleton {
    id: root

    // Keyed by desktop entry id, newest first, which is the order the history
    // already arrives in.
    //
    // ON THEIR WAY OUT ARE OUT. A dismissed entry stays in `history` for the
    // length of its exit animation, and a badge that hangs on for a fifth of a
    // second after the swipe that cleared it reads as the swipe not having
    // worked. The tray animates that row leaving because the row is what you are
    // looking at; here the count is, and it should be right immediately.
    readonly property var byApp: {
        const out = {};
        for (const entry of Notifs.history) {
            if (entry.leaving)
                continue;
            const id = root.appIdFor(entry);
            if (!id)
                continue;
            if (!out[id])
                out[id] = [];
            out[id].push(entry);
        }
        return out;
    }

    // The hint first, the display name second. Both go through the same
    // unwrapping, because a `desktop-entry` hint is not guaranteed to be the id
    // either: senders put their bus name in it, their binary in it, and
    // occasionally their own display name.
    function appIdFor(entry: var): string {
        for (const name of [entry?.desktopEntry, entry?.appName]) {
            if (!name)
                continue;
            for (const variant of Apps.nameVariants(name)) {
                if (!variant)
                    continue;
                const id = DesktopEntries.heuristicLookup(variant)?.id;
                if (id)
                    return id;
            }
        }
        return "";
    }

    function forId(id: string): var {
        return root.byApp[id] ?? [];
    }

    function forEntry(entry: var): var {
        return root.forId(entry?.id ?? "");
    }

    function countFor(entry: var): int {
        return root.forEntry(entry).length;
    }

    function newestFor(entry: var): var {
        return root.forEntry(entry)[0] ?? null;
    }

    // Thrown away, not merely taken off the screen. A swipe across a row in the
    // launcher is a decision about the notification, the same one the tray's own
    // dismissal is, so it does not come back in the hub afterwards.
    //
    // COPIED before iterating: dismiss() reaches straight back into Notifs.history,
    // which is what `byApp` is derived from, so the list being walked is rebuilt
    // underneath the loop on the first call.
    function dismissFor(entry: var): void {
        for (const notif of root.forEntry(entry).slice())
            Notifs.dismiss(notif);
    }

    // A whole folder's worth at once, deduplicated, because two members of a
    // folder can resolve to the same entry id and clearing one twice is a
    // warning in the log.
    function countForAll(entries: var): int {
        let n = 0;
        for (const id of new Set(entries.map(e => e?.id ?? "")))
            n += root.forId(id).length;
        return n;
    }

    function dismissForAll(entries: var): void {
        for (const id of new Set(entries.map(e => e?.id ?? "")))
            for (const notif of root.forId(id).slice())
                Notifs.dismiss(notif);
    }
}
