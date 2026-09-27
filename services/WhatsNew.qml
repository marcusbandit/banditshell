pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "whatsnew.js" as WhatsNewLog

// THE WHAT'S NEW LOG, AS THE SHELL READS IT: docs/whats-new.json, one entry
// per push, and the marker saying how far this user has been shown.
//
// THE LOG TRAVELS WITH THE CODE IT DESCRIBES. It is a file in the checkout,
// appended only at push time, so an entry being in the local copy of it IS
// the change being on this machine: a fetch cannot write the file, only a
// pull can. That is what keeps the update's four states honest without this
// service ever asking Update - "available" cannot announce entries it does
// not have, because it does not have the file that carries them - and it is
// also what makes a manual git pull indistinguishable here from a downloaded
// update: both arrived as files, and both are asked the same question, what
// is newer than the marker.
//
// THE MARKER is `updates.seen` in the user's config.json: the id of the
// newest entry whose card they have been shown. A marker that is empty or no
// longer in the log shows everything rather than nothing - the failure
// direction for news is over-showing - and both ways of landing there are
// real: a log trimmed under an old marker, and a user no card was ever
// shown to.
//
// WHO SHOWS IT: the update menu hosts the card (UpdateMenu), and
// ShellWindow summons that menu ONCE at launch while anything is pending -
// the lightest surface that gets the news seen, through the same pinned-open
// machinery the CLI uses, with no new surface of its own (DESIGN.md 2.1).
// The indicator itself stays quiet about unseen entries on purpose: its red
// and blue belong to the update's own machine, and "there is a changelog you
// have not read" is not a third thing worth a colour.
//
// SEEN IS WRITTEN BY THE CARD, not by this service and not by the update
// check: a download nobody has read yet is not a seen. The card marks when
// the menu has believed it - MenuPanel's settle beat, the panel's own test
// for "on screen long enough to be read" - so a menu crossed in a tenth of a
// second is not marked, and every marking was a deliberate open (the
// indicator has no hover route; UpdateIndicator says why).
Singleton {
    id: root

    readonly property string path: `${Quickshell.shellDir}/docs/whats-new.json`

    // The parsed log, newest first, while the file on disk says so. Replaced
    // whole rather than patched: the file only ever changes by a pull, and a
    // pull changes every entry at once.
    property var entries: []

    // Whether a read has been ATTEMPTED, either way. `pending` before the
    // first read is empty rather than wrong: a missing log is a checkout
    // with nothing to announce, and that is the correct failure.
    property bool checked: false

    // The summon's gate, and the marker's: both wait for the user's own
    // settings to be in (Config's `loaded` warns what happens to a writer
    // that does not), because a marker read from the defaults is a marker
    // that does not exist yet.
    readonly property bool ready: Config.loaded && root.checked

    readonly property var pending: WhatsNewLog.accumulated(root.entries, Config.values.updates.seen)

    function markSeen(id: string): void {
        if (!Config.loaded || !id || id === Config.values.updates.seen)
            return;
        Config.set("updates.seen", id);
    }

    // The log's severity vocabulary, for the card's caption. Handed through
    // rather than recomputed so Major is decided in exactly one place.
    function severityOf(entry: var): string {
        return WhatsNewLog.severityOf(entry);
    }

    // Preloaded but NOT blocking: nothing in the first frame is drawn from
    // this list, so a read that cost the shell its first paint would buy
    // nothing (Themes.qml's index makes the same argument). Watched, so a
    // pull landing mid-session brings its own entries in live - the
    // downloaded state's card appears in the menu the user is already
    // looking at, without waiting for a restart.
    FileView {
        id: file

        path: root.path
        preload: true
        watchChanges: true
        printErrors: false

        onFileChanged: file.reload()
        onLoaded: {
            root.entries = WhatsNewLog.parse(file.text());
            root.checked = true;
        }
        onLoadFailed: root.checked = true
    }
}
