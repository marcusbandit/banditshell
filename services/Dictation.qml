pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// WHAT YOU SAID, and getting it back.
//
// The clipboard's other half. SUPER+R dictates into whatever has focus and
// SUPER+SHIFT+R types the last one again, but "the last one" is a single slot
// and dictating again spends it. Everything said before that was simply gone:
// three transcriptions were lost that way in one afternoon and survived only
// because they happened to still be in the journal. This is the list, and
// picking a row out of it is what refills that slot.
//
// THE DAEMON OWNS THE HISTORY, not this file, and the split is the layering rule
// (DESIGN.md 8): the daemon is the only thing that knows a transcription
// happened, so it is the only thing that can record one. It writes
// ~/.local/share/gvoice/history.json and this watches it, which means the panel
// grows a row as you speak with nothing here polling. Writes go the other way
// through the `voice` CLI rather than by editing that file, because the daemon
// holds the same list in memory and a file edited underneath it would be
// overwritten by its next save.
//
// It is a Singleton for the reason Clipboard is one: the history outlives every
// widget that looks at it.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string path: `${root.home}/.local/share/gvoice/history.json`
    // ABSOLUTE. ~/bin is on the interactive shell's PATH and not necessarily on
    // the one the compositor started this shell with, and a verb that silently
    // does nothing is exactly the failure this panel exists to fix.
    readonly property string cli: `${root.home}/bin/voice`

    // NEWEST FIRST, which is the order the daemon writes and the order the panel
    // reads. Nothing here re-sorts.
    property var entries: []

    // Whether the file has been read yet, so an empty list can say which kind of
    // empty it is. "Nothing has been dictated" and "the daemon is not running"
    // are different facts and the panel says so.
    property bool loaded: false
    // Whether the daemon looks present at all. The history file is created on
    // the first transcription, so its absence is not an error, but it does mean
    // there is nothing to show and no point pretending otherwise.
    property bool present: false

    // ONE TRANSCRIPTION, SHAPED LIKE A CLIPBOARD ENTRY.
    //
    // Deliberately the same shape, because the panel draws both tabs with the
    // same ClipRow and the alternative was a second row type that would drift
    // from the first one. The fields ClipRow actually reads are `kind`, `text`,
    // `recorded` and `pinned`; the rest it guards with ?? and never sees here.
    //
    // `recorded` IS IN MILLISECONDS. The daemon writes seconds, which is what
    // every other timestamp in that process is, and Clipboard.age() measures
    // against Date.now(). Getting this wrong does not throw, it just dates every
    // row to 1970, which is why it is called out rather than merely converted.
    function shape(e: var): var {
        return {
            id: e.id,
            kind: "speech",
            text: e.text ?? "",
            recorded: (e.at ?? 0) * 1000,
            // Nothing pins a transcription. The list is time-ordered and short,
            // and a pinned row would have to survive the daemon's own cap.
            pinned: false
        };
    }

    // WAS THIS SAID, RATHER THAN COPIED?
    //
    // Asked by services/Clipboard.qml, and the paste is the reason. A
    // transcription reaches the focused window by going onto the clipboard for
    // the length of one Ctrl+V and being taken off again (~/bin/voice-daemon,
    // paste_text). The clipboard recorder watches the selection, so it sees
    // that, and without this the same sentence lands in BOTH tabs of the panel:
    // once as a thing that was said and once as a thing that was copied, and a
    // clipboard history nobody filled deliberately fills up with speech.
    //
    // A WINDOW rather than "is it the newest", because the two events are
    // watched over different channels and neither promises to arrive first. The
    // daemon does give this side a head start on purpose: it writes the history
    // file BEFORE it waits for the key to come up, and only touches the
    // clipboard after that, which is tens of milliseconds at the very least.
    // The window is what covers a head start not being a guarantee.
    //
    // Known limit: `voice retype` pastes a transcription that may be hours old,
    // and that one will be recorded as a copy. It is the rarer path and the
    // alternative, matching the whole list with no window at all, would silently
    // swallow a deliberate copy of anything ever dictated.
    readonly property int echoWindow: 15000

    function said(text: string): bool {
        const needle = (text ?? "").trim();
        if (!needle)
            return false;
        const cut = Date.now() - root.echoWindow;
        return root.entries.some(e => e.recorded >= cut && (e.text ?? "").trim() === needle);
    }

    // Narrowed the same way the clipboard narrows, by asking Clipboard's own
    // matcher rather than writing a second one. Two search boxes in one panel
    // that scored matches differently would be a worse bug than the coupling.
    function search(needle: string): var {
        if (!needle)
            return root.entries;
        return root.entries.filter(e => Clipboard.tier(e, needle) > Clipboard.tierNone);
    }

    // INTO THE RETYPE SLOT, and no further. It deliberately does not type: this
    // is called with the panel open and the keyboard held by the shell, so
    // typing here would land in the panel or in whatever gets focus as it
    // closes. Loading the slot and letting SUPER+SHIFT+R fire it keeps one path
    // to the screen, and it is the path that already works.
    function use(entry: var): void {
        if (!entry?.id)
            return;
        root.run(["use", entry.id]);
    }

    function drop(entry: var): void {
        if (!entry?.id)
            return;
        // Dropped here as well as at the daemon, so the row leaves under the
        // hand that threw it. The file watch will confirm it a moment later;
        // waiting for that round trip would leave the row sitting there through
        // an HTTP call and read as the gesture having missed.
        root.entries = root.entries.filter(e => e.id !== entry.id);
        root.run(["drop", entry.id]);
    }

    function run(args: var): void {
        poke.command = [root.cli, ...args];
        poke.running = true;
    }

    Process {
        id: poke

        // stderr only. The verbs print a line on success that nothing here
        // reads, and the failure worth hearing about is a daemon that is not
        // answering, which is the case where the panel would otherwise appear to
        // work and then not type.
        stderr: SplitParser {
            onRead: line => console.warn("Dictation:", line)
        }
    }

    FileView {
        id: store

        path: root.path
        // WATCHED, so a transcription that finishes while the panel is open
        // appears in it. The daemon renames a temporary file over this one
        // precisely so that this watcher never sees a half-written list.
        watchChanges: true
        printErrors: false

        onLoaded: root.absorb(text())
        onFileChanged: reload()

        onLoadFailed: err => {
            root.loaded = true;
            root.present = false;
            root.entries = [];
            if (err !== FileViewError.FileNotFound)
                console.warn(`Dictation: could not read ${root.path} (${err}).`);
            // FileNotFound is not a warning. The file does not exist until the
            // first transcription is recorded, so on a fresh machine this is the
            // normal state and the panel says "nothing dictated yet".
        }
    }

    function absorb(raw: string): void {
        root.loaded = true;
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            console.warn("Dictation: history.json did not parse; showing nothing.");
            root.present = false;
            root.entries = [];
            return;
        }
        if (!Array.isArray(data)) {
            root.present = false;
            root.entries = [];
            return;
        }
        root.present = true;
        root.entries = data.filter(e => e && e.text).map(e => root.shape(e));
    }
}
