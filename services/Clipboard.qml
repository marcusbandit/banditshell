pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// WHAT HAS BEEN COPIED, and how to get it back.
//
// The shell records its own history rather than reading another clipboard
// manager's, and the reason is the one thing every other manager throws away:
// TYPES. A selection is offered as several MIME types at once, and that list is
// the only place the difference between a file, a picture, a sound and a
// sentence is written down. clipse keeps four fields and no type among them, so
// a path, a URL and a paragraph come back identical and anything built on it can
// only guess from the text. `wl-paste --list-types` is not a guess, and
// scripts/clip-record.sh is where it is asked.
//
// The split is the layering rule (DESIGN.md 8) one notch further out than usual:
// the script answers what the compositor can answer and QML cannot (the type
// list, percent-decoding, libmagic, saving bytes), and every decision made ABOUT
// that answer is here. So "is this audio" is a MIME test in this file, not a
// filename test in the script, and changing what counts as audio does not
// involve a shell.
//
// It is a Singleton because a history outlives every widget that looks at it and
// because there must be exactly ONE watcher: two would both record every
// selection and the file would grow in pairs.
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/clipboard.json`
    // Where the recorder puts bytes it could not put in the history: pictures,
    // and anything else that is not text. Handed to the script rather than
    // agreed with it, so there is one definition of where the store is.
    readonly property string blobs: `${root.dir}/clipboard`

    // NEWEST FIRST, which is the order the list is read in and therefore the
    // order it is kept in. Every writer below preserves it.
    property var entries: []

    // Whether the file has been read yet. Everything that writes checks this:
    // saving before the first read would persist an empty history over the real
    // one, which is the whole failure Usage.qml documents at length.
    property bool loaded: false

    // Whether the history may be written at all. Dropped when the file existed
    // and could not be read, because a file this shell cannot parse is far more
    // likely to be one caught half-written than one that genuinely holds
    // nothing, and every one of those still has the history in it. Usage.qml
    // makes the same bargain for the same reason: track the session in memory,
    // leave the bytes alone for a later hand or a later parser.
    property bool keep: true

    // WHETHER THE WATCHERS FROM PREVIOUS LIVES HAVE BEEN SEEN OFF.
    //
    // `wl-paste --watch` is a child process, and a shell that is killed rather
    // than asked to quit does not get to reap its children: the watcher is
    // reparented to init and goes on running with nobody reading it. Every
    // restart that was not a clean exit therefore leaves one behind, and they
    // accumulate, one per crash and one per `kill -9`, each still waking a
    // script on every selection for the rest of the session.
    //
    // So the first thing this does is kill any watcher pointed at OUR script,
    // and only then start one. Matched on the script's full path rather than on
    // "wl-paste": somebody else's watcher, or the user's own, is not this
    // shell's to end.
    property bool reaped: false

    // WHETHER ANYTHING IS ACTUALLY BEING RECORDED.
    //
    // Worth being able to ask from outside, because it is the one failure this
    // service cannot show: a watcher that died leaves a history that simply
    // stops growing, which is indistinguishable from an afternoon in which
    // nothing was copied. `banditshell clipboard status` reads this.
    readonly property bool recording: watcher.running

    // WHAT IS ON THE CLIPBOARD RIGHT NOW, as an entry id, or empty. Not the same
    // question as "the first row": copying something the history already holds
    // moves it to the top, but so does nothing else, and a cleared clipboard
    // leaves the row that used to be current still sitting there. A menu that
    // marks the live selection has to be told when it stops being live.
    property string current: ""

    // ---- KINDS -------------------------------------------------------------
    //
    // The vocabulary the menu draws with. Ordered from most specific to least,
    // and resolved in that order, because the types overlap on purpose: a copied
    // song is a file AND a URI list AND text, and it is worth saying "audio".

    readonly property var kinds: ["image", "audio", "video", "document", "files", "colour", "url", "text"]

    function markFor(kind: string): string {
        switch (kind) {
        case "image":
            return "image";
        case "audio":
            return "graphic_eq";
        case "video":
            return "movie";
        case "document":
            return "description";
        case "files":
            return "folder";
        case "colour":
            return "palette";
        case "url":
            return "link";
        }
        return "notes";
    }

    // A COLOUR, which is the one kind that is purely a shape in the text and is
    // here anyway: copying a hex value out of a palette is common enough, and a
    // swatch answers "which green was that" in a way six characters never do.
    readonly property var hex: /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/

    // A URL, deliberately strict about the scheme: `foo:bar` is a valid URI and
    // is almost never what someone copied on purpose, while a bare `www.` is not
    // a URI at all and always is.
    readonly property var url: /^(https?|ftp|magnet|mailto|ssh|git):/i

    // WHAT AN ENTRY IS, from what the recorder saw.
    //
    // The type list wins wherever it exists, because it is what the application
    // said about its own data. Sniffing the text is the fallback for entries
    // that arrived without one, which today means the imported clipse history
    // and nothing else.
    function classify(e: var): string {
        const paths = e.paths ?? [];
        const mimes = e.mimes ?? [];
        const types = e.types ?? [];

        // A COPIED FILE is decided by what the file IS, not by what the
        // clipboard called it. Every one of them arrives as text/uri-list, so
        // the uri-list type says only "these are files"; libmagic on the far end
        // of the URI is what makes a .flac audio and a .pdf a document.
        //
        // A NAMED KIND HAS TO BE TRUE OF ALL OF THEM, and an unknown member is
        // not a member that agrees. Dropping the blanks first and letting the
        // survivors vote was the first version and it is wrong twice over: a
        // selection of two files where one has been deleted came back "image"
        // on the strength of the one that was left, which is a claim about a
        // selection made from half of it, and the row then drew itself as a
        // picture with no picture to show, because a kind of "image" with no
        // stored file has nothing to put in the thumbnail. "files" is the honest
        // answer whenever the selection is not uniformly one thing.
        if (paths.length) {
            const kind = m => m.startsWith("image/") ? "image" : m.startsWith("audio/") ? "audio" : m.startsWith("video/") ? "video" : m.startsWith("text/") || m.startsWith("application/pdf") || m.includes("document") ? "document" : "files";
            if (mimes.length === paths.length && mimes.every(m => !!m)) {
                const all = mimes.map(kind);
                if (all.every(k => k === all[0]))
                    return all[0];
            }
            return "files";
        }

        // A picture is the one kind the recorder resolves by itself, because it
        // had to: the bytes were saved or they were not.
        if (e.file)
            return "image";

        if (types.some(t => t.startsWith("image/")))
            return "image";
        // A URI list whose paths could not be probed: the files are gone, or the
        // entry came from the import. Still files.
        if (types.includes("text/uri-list") || (e.uris ?? []).length)
            return "files";

        const text = (e.text ?? "").trim();
        if (!text)
            return "text";
        if (root.hex.test(text))
            return "colour";
        if (root.url.test(text))
            return "url";

        // A PATH THAT IS ONLY A PATH. The import's entries reach here and
        // nothing else does, so this is allowed to be a shape test: one line,
        // starts at the root or at home, no spaces around it. It cannot say what
        // KIND of file, because there is no type list and this does not stat.
        if (/^(~|\/)[^\n]*$/.test(text) && !/\s{2}/.test(text))
            return "files";

        return "text";
    }

    // WHAT THE ROW SAYS, when it is not showing the thing itself.
    function summarise(e: var): string {
        // The file first, never the kind: a kind is what this file currently
        // makes of an entry and can change under it, while what there is to show
        // cannot. Asking "is it an image" and then finding no file is how a row
        // ends up captioned "picture" with nothing behind it.
        if (e.file)
            return root.basename(e.file);
        if ((e.paths ?? []).length)
            return e.paths.length === 1 ? root.basename(e.paths[0]) : `${e.paths.length} files`;
        return (e.text ?? "").trim();
    }

    // HOW BIG, for the two kinds where the answer is worth a word: a picture,
    // which has no text to judge it by, and a file, which you may be about to
    // paste somewhere it does not fit. Rounded hard on purpose; the question a
    // row answers is "which one", never "how many bytes exactly".
    function size(bytes: real): string {
        if (!bytes || bytes <= 0)
            return "";
        // Powers of ten, matching what every file manager and every download
        // shows. Deriving the tier from the magnitude rather than listing
        // branches means adding a unit is adding a name.
        const units = ["B", "kB", "MB", "GB", "TB"];
        const tier = Math.min(units.length - 1, Math.floor(Math.log10(bytes) / 3));
        const scaled = bytes / Math.pow(1000, tier);
        // One decimal below ten, none above: 9.4 MB says something 9 MB does
        // not, and 940 MB is not improved by 940.3.
        return `${tier === 0 || scaled >= 10 ? Math.round(scaled) : scaled.toFixed(1)} ${units[tier]}`;
    }

    function basename(p: string): string {
        const cut = p.lastIndexOf("/");
        return cut < 0 ? p : p.slice(cut + 1);
    }

    // HOW LONG AGO, coarsely and on purpose.
    //
    // Clock.spanLabel is the shell's duration formatter and is the wrong one
    // here: it counts in hours and never reaches a day, so a paste from Tuesday
    // reads "72h". A clipboard is ordered by recency and the list already shows
    // that ordering, so the number's job is not precision, it is telling "a
    // minute ago" from "last week" at a glance.
    function age(recorded: real): string {
        if (!recorded)
            return "some time ago";

        const secs = Math.max(0, (Date.now() - recorded) / 1000);
        if (secs < 45)
            return "just now";

        const mins = secs / 60;
        if (mins < 60)
            return `${Math.round(mins)}m ago`;

        const hours = mins / 60;
        if (hours < 24)
            return `${Math.round(hours)}h ago`;

        const days = hours / 24;
        if (days < 7)
            return Math.round(days) === 1 ? "yesterday" : `${Math.round(days)}d ago`;

        const weeks = days / 7;
        return weeks < 5 ? `${Math.round(weeks)}w ago` : `${Math.round(days / 30)}mo ago`;
    }

    // ---- IDENTITY ----------------------------------------------------------
    //
    // WHAT MAKES TWO PASTES THE SAME PASTE, which is the whole of deduplication
    // and is not obvious.
    //
    // A picture is its bytes: the recorder names the file by content hash, so
    // the same screenshot copied twice is one file and comparing the names
    // compares megabytes for free. Everything else is its text. NOT the type
    // list as well: the same string copied out of a browser and out of a
    // terminal arrives with different type lists and is plainly the same thing,
    // and keying on the list would put it in the history twice with no visible
    // difference between the rows.
    function identity(e: var): string {
        if (e.file)
            return `file:${e.file}`;
        if ((e.paths ?? []).length)
            return `paths:${e.paths.join(" ")}`;
        return `text:${e.text ?? ""}`;
    }

    // ---- RECORDING ---------------------------------------------------------

    // One line off the watcher. Everything about what to KEEP is decided here.
    function absorb(line: string): void {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (err) {
            // A line that is not JSON is the script having gone wrong, which is
            // worth saying once rather than swallowing: silence here looks
            // exactly like a clipboard nobody used.
            console.warn("Clipboard: unreadable line from the recorder:", line);
            return;
        }

        // NOT DATA, so there is nothing to store and something to forget. A
        // clear means the selection is gone and the row that was current is not
        // current any more; a sensitive selection means wl-clipboard has asked
        // us not to keep it, and the right answer to that is to comply silently
        // rather than to record that a secret happened.
        if (ev.state !== "data") {
            root.current = "";
            return;
        }

        // The bytes were past a ceiling, or the type was one nothing here can
        // hold. Both are real events with nothing to show, and a row that says
        // "8 GB of video" and cannot produce it would be a row that lies when
        // pressed.
        if (ev.dropped || (!ev.text && !ev.file && !(ev.paths ?? []).length))
            return;

        const now = Date.now();
        const entry = {
            id: `${now}-${root.entries.length}`,
            recorded: now,
            text: ev.text ?? "",
            file: ev.file ?? "",
            bytes: ev.bytes ?? 0,
            // A picture's own pixels, when the recorder could read them off the
            // header. Zero means unknown, never "square".
            w: ev.w ?? 0,
            h: ev.h ?? 0,
            types: ev.types ?? [],
            paths: ev.paths ?? [],
            mimes: ev.mimes ?? [],
            pinned: false
        };
        entry.kind = root.classify(entry);

        root.push(entry);
    }

    // ADD, or MOVE TO THE TOP if it is already here.
    //
    // Moved rather than added, and the old one's pin and id carried forward:
    // copying something a second time is not a new thing, and a history that
    // grew a duplicate every time you re-copied the same command would bury
    // everything else within a day. The pin especially, because losing a pin by
    // re-copying the pinned thing is the exact opposite of what a pin is for.
    function push(entry: var): void {
        const key = root.identity(entry);
        const had = root.entries.find(e => root.identity(e) === key);

        if (had) {
            entry.id = had.id;
            entry.pinned = had.pinned;
        }

        const rest = root.entries.filter(e => root.identity(e) !== key);
        root.entries = [entry, ...rest];
        root.current = entry.id;
        root.prune();
        root.save();
    }

    // THE CAP, which pinned entries do not count against and are never dropped
    // by. A pin is a promise that a thing stays; a cap that could break it would
    // make the promise conditional on how much has been copied since, which is
    // precisely the thing nobody can see coming.
    function prune(): void {
        const max = Math.max(1, Config.values.clipboard.maxEntries);
        const loose = root.entries.filter(e => !e.pinned);
        if (loose.length <= max)
            return;

        const doomed = new Set(loose.slice(max).map(e => e.id));
        root.entries = root.entries.filter(e => !doomed.has(e.id));
    }

    // ---- WHAT A ROW CAN DO -------------------------------------------------

    // BACK ONTO THE CLIPBOARD.
    //
    // Through wl-copy rather than by asking the recorder to replay it, because
    // the clipboard is owned by whoever last set it and there is no way to
    // "restore" one except by setting it again. The watcher then sees our own
    // write and pushes it back to the top, which is correct and is why nothing
    // here reorders the list itself.
    function copy(entry: var): void {
        if (!entry)
            return;

        if (entry.file) {
            // The type is read back off the stored name rather than remembered,
            // so a file that was saved as a png is offered as a png even if the
            // type list it arrived with said something more exotic.
            //
            // BOTH the type and the path travel as ARGUMENTS, never spliced into
            // the script text. The path was always an argument; the type was not,
            // and that was a real hole rather than a theoretical one. A recorded
            // picture's extension is safe because clip-record.sh strips it to
            // `[a-zA-Z0-9]` before naming the file, but an IMPORTED one's name
            // comes verbatim out of clipse's history, which is a file this shell
            // neither writes nor validates. A basename crafted there put its own
            // text into an `sh -c` string that runs when the row is pasted back.
            // Passing it as `$1` ends the question rather than answering it with
            // a second sanitiser that has to stay in step with the first.
            const ext = entry.file.slice(entry.file.lastIndexOf(".") + 1).toLowerCase();
            paste.command = ["sh", "-c", 'exec wl-copy -t "$1" < "$2"', "sh", `image/${ext === "jpg" ? "jpeg" : ext}`, entry.file];
        } else if ((entry.paths ?? []).length) {
            // PUT BACK AS A FILE, not as its path. Offering only text would make
            // a copied song paste into a file manager as a sentence. The URI
            // list is rebuilt from the paths rather than replaying the stored
            // text, because the stored text is what the SOURCE offered and its
            // escaping is its own business; this is ours, and it round-trips
            // with the decoder in the recorder.
            const uris = entry.paths.map(p => `file://${encodeURI(p)}`).join("\r\n");
            paste.command = ["wl-copy", "-t", "text/uri-list", "--", uris];
        } else {
            // `--` so a value that begins with a dash is content and not a flag,
            // and `-n` so the trailing newline the shell would add is not
            // silently appended to everything that goes back.
            paste.command = ["wl-copy", "-n", "--", entry.text ?? ""];
        }

        paste.running = true;
    }

    // WHAT SHAPE A PICTURE IS, for the ones whose pixel count nobody recorded.
    //
    // Entries this shell captured carry `w` and `h` straight off the file
    // header. Imported ones do not, and the only thing here that can find out is
    // a decode, which returns the size of the copy it asked for rather than the
    // size of the picture. That copy is scaled with the aspect preserved, so the
    // RATIO it reports is true even though the numbers are not.
    //
    // Kept as a ratio and NOT written into `w`/`h` for exactly that reason: a
    // row captions itself with those, and a caption reading "132 × 108" for a
    // screenshot that is nothing of the sort would be the interface stating a
    // measurement it did not make.
    //
    // Written down rather than re-measured, the way AppIcons records what shape
    // each application's icon turned out to be, and for the same reason: it is a
    // fact about a file, it cannot change, and the list deliberately does not
    // reuse delegates, so without this a row scrolled out and back starts square
    // and settles again on every sighting.
    function noteAspect(id: string, ratio: real): void {
        if (!id || !(ratio > 0))
            return;
        const had = root.entries.find(e => e.id === id);
        // Nothing to add if the true size is already known, and nothing to do if
        // this is the answer already stored: both would be a write per decode.
        if (!had || had.w > 0 || Math.abs((had.aspect ?? 0) - ratio) < 0.001)
            return;
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
                    aspect: ratio
                }) : e);
        // A screenful of pictures decodes together; save() defers through
        // Qt.callLater, which collapses repeats of one function within an
        // event-loop pass into a single write.
        root.save();
    }

    function setPinned(entry: var, pinned: bool): void {
        if (!entry)
            return;
        root.entries = root.entries.map(e => e.id === entry.id ? Object.assign({}, e, {
                    pinned: pinned
                }) : e);
        root.save();
    }

    function remove(entry: var): void {
        if (!entry)
            return;
        root.entries = root.entries.filter(e => e.id !== entry.id);
        if (root.current === entry.id)
            root.current = "";
        root.save();
        root.sweep();
    }

    // EVERYTHING LOOSE. Pinned entries survive, which is what makes a pin worth
    // making: the gesture for "keep this" has to survive the gesture for "clear
    // all of that", or it is only a bookmark.
    function clear(): void {
        root.entries = root.entries.filter(e => e.pinned);
        root.current = "";
        root.save();
        root.sweep();
    }

    // Pictures nothing points at any more. Run after anything that drops an
    // entry, because the file outlives the row that referenced it and a store
    // that only ever grew would quietly become the largest thing in the state
    // directory. The list of what to KEEP is passed in rather than the list of
    // what to delete, so a bug here cannot delete a file that is still in use.
    function sweep(): void {
        // Guarded, because a sweep that lands while a previous one is still
        // running would be `running = true` on a live Process, which is a
        // request to start a second one.
        //
        // REMEMBERED RATHER THAN DROPPED. The in-flight sweep was given the
        // list of files to keep as it stood when it started, so it knows
        // nothing about the entry deleted a moment later: returning here without
        // a note would leave that entry's picture on disk with nothing
        // referencing it and nothing that would ever look again. Mashing Delete
        // through five rows is exactly that case, and it is the one this whole
        // function exists to prevent.
        if (reaper.running) {
            root.sweepOwed = true;
            return;
        }
        root.sweepOwed = false;

        const wanted = root.entries.filter(e => !!e.file).map(e => root.basename(e.file));

        // SET MEMBERSHIP, not a nested loop.
        //
        // The obvious version compares every file against every wanted name and
        // forks basename per file, which at the 400-entry cap is a hundred and
        // sixty thousand shell string comparisons and four hundred processes,
        // for a job that runs every time a row is thrown away. grep does the
        // membership test in one pass over one process. `-x` so a name must
        // match whole (a hash is a prefix of nothing, but `imported-x.png` is a
        // suffix of plenty), `-F` so a filename full of regex characters is a
        // string rather than a pattern, and the list arrives on a file rather
        // than in the argument vector, which has a length limit this could
        // otherwise reach.
        //
        // An EMPTY wanted list deletes everything, which is correct: it means no
        // entry references a stored file at all. printf then writes one empty
        // line, and an empty pattern under -x matches only an empty filename, so
        // nothing is spared. That is the intended reading and not an accident.
        reaper.command = ["sh", "-c", `
            dir=$1; shift
            [ -d "$dir" ] || exit 0
            keep=$(mktemp) || exit 0
            printf '%s\\n' "$@" > "$keep"
            find "$dir" -maxdepth 1 -type f -printf '%f\\n' 2>/dev/null \\
                | grep -vxF -f "$keep" \\
                | while IFS= read -r n; do rm -f -- "$dir/$n"; done
            rm -f "$keep"
            exit 0
        `, "sh", root.blobs, ...wanted];
        reaper.running = true;
    }

    // ---- SEARCH ------------------------------------------------------------
    //
    // Apps.qml's shape, with the tiers that make sense for a clipboard. The
    // ranking question is different from the launcher's: there is no frecency
    // here, because you do not paste a thing repeatedly the way you launch an
    // application repeatedly, and RECENCY is what a clipboard is ordered by.
    // Which is why time is the tiebreak and the list is already in it.

    readonly property int tierExact: 4
    readonly property int tierPrefix: 3
    readonly property int tierWord: 2
    readonly property int tierAnywhere: 1
    readonly property int tierNone: -1

    function tier(entry: var, needle: string): int {
        if (!needle)
            return root.tierExact;

        const q = needle.toLowerCase();

        // EVERYTHING THE ROW COULD BE CALLED, searched together: the text, the
        // filenames, and the kind. Searching only the text would make a picture
        // unfindable, which for the one kind you cannot skim is the worst place
        // to lose. `kind` in the haystack is what makes typing "audio" list the
        // sounds without a filter control existing anywhere.
        const hay = [entry.text ?? "", entry.kind ?? "", ...(entry.paths ?? []), entry.file ? root.basename(entry.file) : ""].join("\n").toLowerCase();

        if (hay === q)
            return root.tierExact;
        if (hay.startsWith(q))
            return root.tierPrefix;
        if (new RegExp(`\\b${root.escapeRegex(q)}`).test(hay))
            return root.tierWord;
        if (hay.includes(q))
            return root.tierAnywhere;

        return root.tierNone;
    }

    function escapeRegex(s: string): string {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    // PINNED FIRST, then by tier, then by recency. Pinned first unconditionally
    // and even while searching: a pin is a statement about where a thing belongs
    // in this list, and a search that scattered them back among the rest would
    // be answering a different question than the one the pin asked.
    function search(needle: string): var {
        return root.entries.map(e => ({
                    entry: e,
                    tier: root.tier(e, needle)
                })).filter(r => r.tier > root.tierNone).sort((a, b) => (b.entry.pinned ? 1 : 0) - (a.entry.pinned ? 1 : 0) || b.tier - a.tier || b.entry.recorded - a.entry.recorded).map(r => r.entry);
    }

    // ---- THE WATCHER -------------------------------------------------------

    // ORPHANS ONLY, and that distinction is the whole of this.
    //
    // A blanket `pkill -f` on the script's path was the first version and it is
    // wrong on a session with two shells on it, which this shell already expects
    // to happen (see the note on `watchChanges`, and Usage.qml's). The second
    // shell to start would kill the FIRST one's perfectly healthy watcher, and
    // the first would then never record again: its Process saw its child die and
    // dropped `running`, and nothing restarts it. One shell silently stops
    // keeping history the moment another one starts.
    //
    // So the test is parentage, not pattern. A watcher whose parent is a live
    // `qs` belongs to a running shell and is left alone; anything else was
    // reparented when its shell was killed rather than asked to quit, and is the
    // leak this exists to clear. Reparenting does NOT reliably land on pid 1
    // here (a user systemd is a subreaper and picks them up instead), so the
    // parent is asked what it IS rather than what number it has.
    //
    // The pattern is matched with pgrep rather than acted on with pkill so the
    // decision happens per process, and the `[c]` trick keeps pgrep's own
    // command line from matching itself.
    Process {
        id: stale

        command: ["sh", "-c", `
            script=$1
            for p in $(pgrep -f "wl-paste --watch $script" 2>/dev/null); do
                ppid=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
                [ -n "$ppid" ] || continue
                owner=$(ps -o comm= -p "$ppid" 2>/dev/null | tr -d ' ')
                # BOTH NAMES. The binary is invoked as \`qs\` and reports itself
                # as \`quickshell\`, and which one \`comm\` shows is not this
                # file's business to predict: testing only the short one meant
                # every live shell's watcher looked ownerless and got killed,
                # which is precisely the failure this parentage test exists to
                # prevent, arrived at from the other side.
                case "$owner" in
                qs | quickshell) continue ;;
                esac
                kill "$p" 2>/dev/null
            done
            exit 0
        `, "sh", Quickshell.shellPath("scripts/clip-record.sh")]

        onExited: root.reaped = true
    }

    Process {
        id: watcher

        // Started only once the history has been read, so a selection made
        // during startup cannot land in an empty list and be saved over the
        // file before it was loaded; and only once the previous life's watchers
        // are gone, so there is exactly one.
        running: root.loaded && root.reaped && Config.values.clipboard.record

        command: ["wl-paste", "--watch", Quickshell.shellPath("scripts/clip-record.sh")]

        // The ceilings and the store are the shell's settings, so they are
        // handed down rather than defaulted twice. A number that lives in
        // config.json and ALSO in a script's fallback is one fact in two places,
        // and the copy in the script would be the one to go stale.
        environment: ({
                BANDITSHELL_CLIP_STORE: root.blobs,
                BANDITSHELL_CLIP_MAXTEXT: `${Config.values.clipboard.maxText}`,
                BANDITSHELL_CLIP_MAXBLOB: `${Config.values.clipboard.maxBlob}`
            })

        // One event per line, which is exactly what the script promises.
        stdout: SplitParser {
            onRead: line => {
                if (line.trim())
                    root.absorb(line);
            }
        }

        stderr: SplitParser {
            onRead: line => console.warn("clip-record:", line)
        }

        // A WATCHER THAT DIED IS A CLIPBOARD THAT STOPPED, SILENTLY, which is
        // the failure this whole service is least able to notice by itself: the
        // history simply stops growing and looks like a quiet afternoon. So it
        // is said out loud, and `running` above is a binding, so the next change
        // to `loaded` or the setting restarts it. It is not restarted on a timer
        // from here: wl-paste exits when the compositor goes away, and a service
        // that respawned it forever would spin through a session ending.
        onExited: (code, status) => {
            if (Config.values.clipboard.record)
                console.warn(`Clipboard: the recorder exited (${code}); nothing new will be recorded until the shell restarts it.`);
        }
    }

    Process {
        id: paste

        // stderr only. wl-copy says nothing on success and the failure worth
        // hearing about is a compositor that would not take the selection.
        stderr: SplitParser {
            onRead: line => console.warn("wl-copy:", line)
        }
    }

    // Whether an entry was dropped while a sweep was already running, and its
    // picture therefore still has nothing pointing at it.
    property bool sweepOwed: false

    Process {
        id: reaper

        onExited: if (root.sweepOwed)
            root.sweep()
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.blobs]
        // The history's own directory is this one's parent, so -p makes both.
        onExited: {
            stale.running = true;
            store.reload();
        }
    }

    // ---- THE FILE ----------------------------------------------------------

    FileView {
        id: store

        path: root.path
        // WATCHED, for the same reason Usage.qml watches its own: a second shell
        // on the session writes this too, and without the reload each of them
        // would save the whole history from its own startup snapshot and they
        // would delete each other's. Our own writes come back through here as
        // well and land as a no-op, which is steadier than keeping a
        // just-wrote-it flag in step with an asynchronous write.
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            const raw = text();

            // OUR OWN WRITE, COMING BACK. Watching a file this service also
            // writes means most reloads are echoes, and an echo has nothing to
            // say: the bytes just read are the bytes just sent. Compared as
            // TEXT rather than tracked with a just-wrote-it flag, because the
            // text is the evidence itself and cannot fall out of step with the
            // asynchronous write the way a flag can.
            if (root.loaded && raw === root.lastWritten)
                return;

            let disk = [];
            try {
                const data = JSON.parse(raw);
                disk = Array.isArray(data?.entries) ? data.entries : [];
            } catch (err) {
                // ON A RELOAD, CHANGE NOTHING. Every reload is somebody else's
                // write arriving, and the likeliest unparseable thing is that
                // write caught halfway rather than a file gone bad. Answering it
                // by emptying the history would be this shell inventing the loss
                // the watch exists to prevent, over a condition that fixes
                // itself when the write finishes and fires this again.
                if (root.loaded)
                    return;

                console.warn(`Clipboard: ${root.path} is not valid JSON; running from memory and leaving the file alone.`, err);
                root.keep = false;
            }

            // Taken guardedly: this is a state file, and state files get
            // truncated by full disks and edited by hand. An entry with no
            // identity at all cannot be shown, copied or deduplicated, so it is
            // dropped rather than left to poison every walk over the list.
            disk = disk.filter(e => e && (e.text || e.file || (e.paths ?? []).length));

            // Re-classified on the way in rather than trusted, so that changing
            // what counts as audio changes the history that is already recorded
            // and not only what arrives after. The type list is what was
            // recorded; the kind is what this file currently makes of it.
            for (const e of disk)
                e.kind = root.classify(e);

            // A RELOAD IS NEWS, NOT A BEGINNING. Only the first read may seed,
            // and only the first read may import: a second import would re-add
            // every clipse entry that has since been deleted here.
            //
            // AND NEWS IS MERGED, NEVER TAKEN WHOLE. Replacing the list with
            // what is on disk looks right and loses pastes, because the reload
            // being answered is usually OUR OWN write echoing back and the
            // snapshot in it is older than the list in memory. `write` is
            // deferred a turn and the write/inotify/reload round trip is several
            // more, so anything copied inside that window exists here and not
            // yet there: copy twice quickly and the echo of the first write
            // would delete the second copy from memory, after which the next
            // write persists its absence. The exact-text check above catches the
            // common case; this is what makes the rest safe, and it is the
            // property that makes Usage.qml's identical watch correct (its
            // absorb only ever ADDS).
            if (root.loaded) {
                root.entries = root.reconcile(disk);
                return;
            }

            root.entries = disk;
            root.loaded = true;

            if (Config.values.clipboard.importClipse)
                clipse.reload();
        }

        onLoadFailed: err => {
            if (root.loaded)
                return;

            if (err === FileViewError.FileNotFound) {
                // No history yet is a session this shell has not recorded
                // before. Make the directory, then start.
                root.loaded = true;
                if (Config.values.clipboard.importClipse)
                    clipse.reload();
                return;
            }

            console.warn(`Clipboard: could not read ${root.path} (${err}); running from memory.`);
            root.keep = false;
            root.loaded = true;
        }
    }

    // ANOTHER SHELL'S WRITE, folded into this one's list.
    //
    // A UNION keyed by id, never an intersection: the two sides disagree only
    // about entries one of them has not seen yet, and the cost of the two
    // readings is not symmetric. Keeping an entry the other shell deleted
    // shows a row that comes back once; dropping an entry the other shell has
    // not been told about yet loses a paste for good. Usage.qml makes the same
    // trade for the same reason.
    //
    // Sorted by when each was recorded, which IS the list's order: newest
    // first, with no separate opinion about position to keep in step.
    function reconcile(disk: var): var {
        const theirs = new Set(disk.map(e => e?.id));
        const unseen = root.entries.filter(e => !theirs.has(e.id));
        return [...disk, ...unseen].sort((a, b) => b.recorded - a.recorded);
    }

    // The exact bytes last handed to the file, so the reload they cause can be
    // recognised as an echo rather than as somebody else's news.
    property string lastWritten: ""

    function save(): void {
        if (!root.keep || !root.loaded)
            return;
        // Deferred, because save() is reached from inside FileView's own signal
        // handlers on the import path, and a FileView handed setText from inside
        // the signal it is still emitting drops the operation it is in the
        // middle of and logs about it. Config.qml and Usage.qml both wrap a
        // write for exactly this.
        Qt.callLater(root.write);
    }

    function write(): void {
        if (!root.keep || !root.loaded)
            return;
        root.lastWritten = JSON.stringify({
            version: 1,
            entries: root.entries
        });
        store.setText(root.lastWritten);
    }

    Component.onCompleted: mkdir.running = true

    // ---- THE IMPORT --------------------------------------------------------
    //
    // clipse's history, read ONCE, so that turning this shell on is not turning
    // the last hundred things you copied off. Read-only in both directions:
    // nothing is written to clipse and nothing of its is deleted, so the two can
    // sit side by side and the old menu still works if this one is not wanted.

    FileView {
        id: clipse

        path: `${Quickshell.env("HOME")}/.config/clipse/clipboard_history.json`
        printErrors: false
        // NOT watched. This is a one-time read of somebody else's file; watching
        // it would make every later clipse write re-import entries that have
        // since been deleted here.
        watchChanges: false

        onLoaded: {
            if (!Config.values.clipboard.importClipse)
                return;

            let old = [];
            try {
                old = JSON.parse(text())?.clipboardHistory ?? [];
            } catch (err) {
                console.warn("Clipboard: clipse's history could not be read; importing nothing.", err);
            }

            root.adopt(old);
        }

        // Nothing to import is not a failure. clipse may simply never have run.
        onLoadFailed: root.settleImport()
    }

    // Where an imported picture ENDS UP, which is in this shell's own store and
    // not in clipse's.
    //
    // Referencing clipse's files in place was the obvious thing and it is wrong:
    // it would leave a third of the imported history owned by the tool being
    // replaced, so `clipse -clean` (whose whole job is reaping exactly these
    // files, and which finds 68 orphans on this machine today) would quietly
    // empty twenty-eight rows of somebody's history months later. Importing
    // means taking a copy, or it is not importing.
    //
    // The name is prefixed rather than hashed, because the copy happens in the
    // background and the row needs a path NOW: this is derivable on both sides
    // without waiting to be told. Entries recorded by this shell are named by
    // content hash and this is deliberately not, so the two can never collide.
    function importedPath(from: string): string {
        return `${root.blobs}/imported-${root.basename(from)}`;
    }

    // clipse's four fields, in this shell's shape.
    function adopt(old: var): void {
        // OLDEST LAST, which is the order both files already use, so the import
        // goes on the END of whatever this shell has recorded rather than in
        // front of it. Anything recorded here is by definition newer than a file
        // that stopped being written when clipse's daemon stopped.
        const mine = new Set(root.entries.map(e => root.identity(e)));
        const brought = [];

        for (const item of old) {
            if (!item || typeof item.value !== "string")
                continue;

            // clipse's own sentinel for "no file" is the four-character STRING
            // "null", not JSON null. Testing against null would make every text
            // entry look like a picture with a path of "null".
            const isImage = item.filePath && item.filePath !== "null";

            const entry = {
                id: `clipse-${brought.length}`,
                // Go's layout, which Date can parse once the space is a T. A
                // failure here is not worth losing the entry over: an entry with
                // no time still pastes, so it lands at the bottom instead.
                recorded: root.parseClipseTime(item.recorded),
                // An imported picture keeps clipse's own caption as its text,
                // which is the emoji and the filename, and that is not something
                // to show or to search. The path carries everything.
                text: isImage ? "" : item.value,
                file: isImage ? root.importedPath(item.filePath) : "",
                bytes: 0,
                // EMPTY, and honestly so: clipse recorded no types, and an
                // invented list would be indistinguishable later from one a real
                // application offered. classify() falls back to sniffing exactly
                // when this is empty.
                types: [],
                paths: [],
                mimes: [],
                pinned: !!item.pinned
            };
            entry.kind = root.classify(entry);

            const key = root.identity(entry);
            if (mine.has(key))
                continue;
            mine.add(key);
            brought.push(entry);
        }

        if (brought.length) {
            root.entries = [...root.entries, ...brought];
            root.prune();
            // WRITTEN NOW, not on the next turn, and this is the one call site
            // where that matters. settleImport below flips a Config key, and
            // Config.save() reaches the file SYNCHRONOUSLY while save() here
            // defers a turn, so the deferred version let "already imported" land
            // on disk before the imported entries did. Killed in that window,
            // the next start would find the flag false, never retry, and the
            // hundred entries would be gone from both stores. This is not
            // nested inside its own FileView's signal (we are in clipse's), so
            // the deferral that exists for that hazard is not needed here.
            root.write();
        }

        // THE PICTURES, COPIED, in one pass rather than one process per file.
        // Taken from the SURVIVING entries and not from everything read, so the
        // cap above decides what is worth the disk. `-n` never overwrites, so
        // running this twice cannot clobber a file already in the store.
        const pics = root.entries.filter(e => e.file && e.file.startsWith(`${root.blobs}/imported-`));
        if (pics.length) {
            adopter.command = ["sh", "-c", `
                dir=$1; shift
                for f in "$@"; do
                    [ -e "$f" ] || continue
                    cp -n -- "$f" "$dir/imported-$(basename "$f")" 2>/dev/null
                done
                exit 0
            `, "sh", root.blobs, ...pics.map(e => `${Quickshell.env("HOME")}/.config/clipse/tmp_files/${root.basename(e.file).replace("imported-", "")}`)];
            adopter.running = true;
        }

        console.log(`Clipboard: imported ${brought.length} entries from clipse (${pics.length} pictures copied).`);
        root.settleImport();
    }

    Process {
        id: adopter
    }

    function parseClipseTime(recorded: string): real {
        if (typeof recorded !== "string")
            return 0;
        const t = Date.parse(recorded.replace(" ", "T"));
        return isNaN(t) ? 0 : t;
    }

    // The flag flips itself off, so a later clipse session cannot re-seed over
    // history this shell has since collected. Written through Config rather than
    // held here, because it has to survive a restart to mean anything.
    function settleImport(): void {
        if (Config.values.clipboard.importClipse)
            Config.set("clipboard.importClipse", false);
    }
}
