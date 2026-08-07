pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// THE NIAGARA CONCEPT: everything installed, in one sectioned column, indexed by
// an alphabet rail.
//
// After the Android launcher of the same name. Its argument is not that icons
// are bad, it is that a GRID is: several hundred squares in an arbitrary order
// is a filing cabinet you have to read left to right. So it keeps the icons and
// throws away the grid. One column, alphabetical, each letter announced in the
// margin, and a rail down the edge that jumps to any of them.
//
// Three things carry it across to a desktop:
//
//   THE STAR. The list does not begin at A. It begins with the handful of things
//   you actually reach for, under a star, and the alphabet follows underneath.
//
//   THE RAIL IS AN INDEX, NOT A FILTER. Everything is in the column the whole
//   time; running down the rail scrolls to a letter rather than replacing what
//   is on screen, so the list being looked at is always the same list.
//
//   THE MARGIN. Letters sit outside the column of icons rather than in it, so
//   every name starts at one x and the sections read as annotations on a
//   continuous list instead of as headings that chop it into blocks.
//
// It rises out of the BOTTOM band and the search sits at the bottom, where a
// phone puts what it expects to be reached.
//
// THE STAR IS CHOSEN, NOT COMPUTED, and that was the one place this file argued
// with the launcher it is named after. Niagara asks you to pick your favourites;
// this took the frecency table's first seven instead, on the grounds that the
// shell already knew. It did know, and the section still read as random, because
// a ranking is not a choice: the order changed under you as the week went on,
// nothing you had done put anything there, and there was no way to say "not
// that one" about a row you were looking straight at. A list nobody chose is a
// list nobody trusts, however good the sort is. So the star is a list you write
// now (see services/Apps.qml), ranking keeps the jobs it is actually good at,
// which are ordering a letter and answering a query, and the machine's guess
// stands in only until you have starred your first thing.
//
// WHAT A ROW CAN HAVE DONE TO IT is asked for by holding it down or by the right
// button, and it opens modules/launcher/AppMenu.qml. Hiding used to be a disc on
// the right end of every row and is one line in there now; the disc could not
// have grown a second action, and it was invisible to a finger besides.
//
// AND A ROW CARRIES ITS APPLICATION'S NOTIFICATIONS, because the launcher is
// where you go when you are looking for an application and "three unread" is
// part of what you are looking for. A swipe across the row is the answer to
// them: left throws them away, right opens the row if the row is a folder and
// otherwise throws them away too, which is the whole rule and the reason the
// gesture needs no legend. Inside a folder there is nothing left to open, so
// both directions clear.
Item {
    id: root

    required property real originX
    required property real inset

    readonly property bool open: shown
    property bool shown: false

    readonly property real panelWidth: Config.values.launcher.niagara.width
    readonly property real railWidth: Config.values.launcher.niagara.rail
    readonly property int favouriteCount: Config.values.launcher.niagara.favourites
    readonly property real iconSize: Config.values.launcher.niagara.icon
    readonly property real bowDepth: Config.values.launcher.niagara.bow
    readonly property real bowSpread: Config.values.launcher.niagara.bowSpread
    readonly property real badgeSize: Config.values.launcher.niagara.badge

    // The letter's column, outside the icons'. Wide enough for the character and
    // no wider, so the names sit as close to the edge as the annotation allows.
    readonly property real gutter: Appearance.font.size.large + Appearance.padding.normal

    readonly property real rowPitch: root.iconSize + Appearance.padding.normal
    readonly property real sectionPitch: Appearance.font.size.large + Appearance.padding.large

    // The mark for the favourites section. Not a letter, because they are not
    // filed under one.
    //
    // Held as a KEY, drawn as an icon: Monocraft is a pixel face with no star in
    // it, so setting one as text renders the missing-glyph box, which is a
    // perfectly good way to make a launcher look broken. The key is what the
    // sections and the rail agree on; what gets drawn for it is a separate
    // question and belongs to the icon font.
    readonly property string star: "favourites"
    readonly property string starIcon: "star"

    // The last mark on the rail: everything you have put away. Held the same way
    // the star is, and for the same reason, and it appears only when there is
    // something in it, exactly like a letter.
    //
    // A drawer rather than a delete. Hiding an application you use twice a year
    // has to be a cheap decision or nobody makes it, and it is only cheap if
    // undoing it is one gesture away rather than a config file away.
    readonly property string vault: "hidden"
    readonly property string vaultIcon: "visibility_off"

    // A section key drawn as a GLYPH rather than as itself, or "" when the key
    // is already the thing to draw.
    //
    // The letters are text. The two keys that are not letters are icons: the
    // star because Monocraft is a pixel face with no star in it and setting one
    // renders the missing-glyph box, and the drawer because "hidden" is a word
    // and the rail is a ruler with single marks on it.
    function keyIcon(key: string): string {
        if (key === root.star)
            return root.starIcon;
        if (key === root.vault)
            return root.vaultIcon;
        return "";
    }

    readonly property Item maskItem: catcher

    // The blob the chassis melts in. This concept draws no background of its
    // own, exactly like every other panel in the shell.
    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large
        }
    ]

    // The alphabet, as the applications actually installed make it. Everything
    // non-alphabetic lands under "#". Built from the data rather than from a
    // hardcoded A-Z, so the rail has no dead letters on it.
    //
    // WITHIN a letter, most-used first rather than alphabetical.
    //
    // The initial is the whole of what the rail asked for, so sorting by the
    // rest of the name adds nothing: it is a second alphabetical sort applied to
    // a set that was chosen alphabetically. Ranking by use makes the top of
    // every letter the answer you probably wanted, which is what lets the first
    // row under a letter be the selected one (see markSection).
    readonly property var byLetter: {
        const out = {};
        for (const entry of Apps.visible) {
            const name = (entry.name ?? "").trim();
            if (!name)
                continue;
            const first = name[0].toUpperCase();
            const key = first >= "A" && first <= "Z" ? first : "#";
            if (!out[key])
                out[key] = [];
            out[key].push(entry);
        }
        for (const key in out)
            out[key] = Apps.byUse(out[key]);
        return out;
    }

    readonly property var letters: Object.keys(root.byLetter).sort()

    // WHAT IS IN THE STAR: folders and loose applications, in the order you
    // pinned them. Apps owns the merge, because the two halves are stored
    // separately and only that file knows the rules that keep them agreeing.
    readonly property var pinned: Apps.pinned

    // THE MACHINE'S GUESS, and only until the star is yours. The moment
    // anything is starred this is empty for good, so a first run opens on
    // something useful and never quietly competes with a list you built.
    readonly property var standIns: Apps.starred ? [] : Apps.search("").slice(0, root.favouriteCount)

    // What the rail offers: the star, then whatever letters exist, then the
    // drawer if anything is in it. Nothing at all inside a folder, where there
    // is no alphabet to index.
    readonly property var keys: root.opened ? [] : [root.star, ...root.letters, ...(Apps.buried.length ? [root.vault] : [])]

    // ------------------------------------------------------------------
    // WHICH FOLDER IS OPEN, "" for the column itself.
    //
    // A MODE OF THE ONE COLUMN rather than a second panel sliding over it. A
    // folder holds a handful of things you chose; giving that its own surface
    // would be a whole window's worth of ceremony for six rows, and it would
    // break the one thing the concept is built on, which is that there is only
    // ever one list and everything moves it rather than replacing it.
    property string opened: ""

    readonly property var openedFolder: root.opened ? Apps.folders[root.opened] : null

    // IN THE ORDER YOU FILED THEM, not by use. Inside a folder every row is
    // something you put there by hand, so re-sorting them by this week's habits
    // would undo the only thing a folder is: an arrangement.
    readonly property var openedApps: root.opened ? Apps.folderApps(root.opened) : []

    function enterFolder(key: string): void {
        if (!key || !Apps.folders[key])
            return;
        root.closeMenu();
        root.opened = key;
        query.text = "";
        root.marked = "";
        list.reset();
        root.selected = root.firstPick(0, 1);
    }

    // BACK TO WHERE THE FOLDER IS, not to the top of the column. Leaving a
    // folder should put you looking at the row you opened, the same way closing
    // anything in this shell puts you back where you opened it from; the star
    // is where every folder lives, so marking it is exactly that.
    function leaveFolder(): void {
        if (!root.opened)
            return;
        root.closeMenu();
        root.opened = "";
        list.reset();
        root.markSection(root.star);
    }

    // How long a row waits before it travels to a new place. See the list's
    // `displaced` transition, which is the whole reason this exists.
    readonly property int moveDelay: Config.values.launcher.niagara.moveDelay

    // ROW OBJECTS THAT SURVIVE A KEYSTROKE.
    //
    // ScriptModel's entire value is that it DIFFS: a query that narrows the list
    // keeps the delegates of everything still in it, and what is kept is what can
    // be MOVED to its new place rather than destroyed and built again somewhere
    // else. It can only tell what survived if the objects it is handed are the
    // same objects it was handed last time.
    //
    // This built fresh `{section, entry}` literals on every evaluation, and an
    // object literal is not equal to its own previous self. So every row was new,
    // every delegate was torn down and rebuilt, and there was nothing left in
    // place for a transition to animate: typing was a series of cuts, which is
    // exactly what it looked like. The rows are the same data either way; the
    // identity is the whole difference.
    //
    // Keyed rather than kept one-per-entry, because an application is TWO rows
    // when it is both a favourite and filed under its letter, and a list holding
    // one object twice has no diff either. `app:` is deliberately shared between
    // the alphabet and the search results, so the first letter you type keeps
    // whatever was already on screen instead of replacing all of it.
    property var rowKeys: ({})

    // A ROW IS FIVE FIELDS, and every caller supplies all five, because the
    // identity test above is an equality check per field and `undefined` is not
    // `""`: a row built with three of them would never match itself on the next
    // evaluation and would be rebuilt on every keystroke, which is precisely the
    // failure this cache exists to prevent. So the shape is filled in HERE
    // rather than trusted to the six places that build one.
    //
    //   section  which section this row heads, "" for a row that is content
    //   title    a heading drawn as text, for the letters
    //   icon     a heading drawn as a glyph, for the star, the drawer, the way
    //            back out of a folder
    //   entry    an application
    //   folder   a folder, by key
    function rowFor(key: string, spec: var): var {
        const want = {
            section: spec.section ?? "",
            title: spec.title ?? "",
            icon: spec.icon ?? "",
            entry: spec.entry ?? null,
            folder: spec.folder ?? ""
        };

        const had = root.rowKeys[key];
        if (had && had.section === want.section && had.title === want.title && had.icon === want.icon && had.entry === want.entry && had.folder === want.folder)
            return had;
        return root.rowKeys[key] = want;
    }

    function entryKey(entry: var): string {
        return entry?.id || entry?.name || "";
    }

    // Something a selection can land on, which a heading is not. Folders count:
    // Return on one opens it, the same as Return on an application launches it.
    function pickable(row: var): bool {
        return !!row && (!!row.entry || !!row.folder);
    }

    // ONE FLAT LIST of rows, sections included, rather than a list of lists.
    //
    // A ListView cannot scroll to something it has no row for, and the rail's
    // whole job is to scroll to a letter. Flattening puts the sections in the
    // same coordinate space as the applications, so "where is T" is arithmetic
    // rather than a search through nested delegates.
    readonly property var rows: {
        if (query.text)
            return Apps.search(query.text).map(entry => root.rowFor(`app:${root.entryKey(entry)}`, {
                    entry: entry
                }));

        // INSIDE A FOLDER the column is the folder, and its heading is the way
        // back out. One row rather than a chrome bar above the list, because
        // the heading slot already exists, already sits in the margin, and is
        // already the thing that says where in the column you are.
        if (root.opened) {
            const out = [root.rowFor(`open:${root.opened}`, {
                    section: root.opened,
                    icon: "arrow_back",
                    title: root.openedFolder?.name ?? ""
                })];
            for (const entry of root.openedApps)
                out.push(root.rowFor(`in:${root.opened}:${root.entryKey(entry)}`, {
                    entry: entry
                }));
            return out;
        }

        const out = [];
        if (root.pinned.length || root.standIns.length) {
            out.push(root.rowFor(`section:${root.star}`, {
                section: root.star,
                icon: root.starIcon
            }));
            for (const pin of root.pinned)
                out.push(pin.kind === "folder" ? root.rowFor(`folder:${pin.key}`, {
                    folder: pin.key
                }) : root.rowFor(`fav:${pin.key}`, {
                    entry: pin.entry
                }));
            // KEYED THE SAME as a real favourite, deliberately: the row a guess
            // put there and the row your star puts there are the same
            // application in the same place, so starring it should keep the row
            // rather than swap one for an identical one.
            for (const entry of root.standIns)
                out.push(root.rowFor(`fav:${root.entryKey(entry)}`, {
                    entry: entry
                }));
        }
        for (const key of root.letters) {
            out.push(root.rowFor(`section:${key}`, {
                section: key,
                title: key
            }));
            for (const entry of root.byLetter[key])
                out.push(root.rowFor(`app:${root.entryKey(entry)}`, {
                    entry: entry
                }));
        }
        if (Apps.buried.length) {
            out.push(root.rowFor(`section:${root.vault}`, {
                section: root.vault,
                icon: root.vaultIcon
            }));
            for (const entry of Apps.buried)
                out.push(root.rowFor(`app:${root.entryKey(entry)}`, {
                    entry: entry
                }));
        }
        return out;
    }

    // Where each section starts and how tall it is WITH its applications, in the
    // list's own coordinates. Accumulated once per change rather than measured
    // off the delegates, which only exist for the part of the list currently on
    // screen.
    //
    // The height is the whole point: a section is a BLOCK, not a heading, and
    // centring a letter means centring the letter and everything filed under it.
    readonly property var sectionSpan: {
        const out = {};
        let y = 0;
        let key = "";
        for (const row of root.rows) {
            if (row.section) {
                key = row.section;
                out[key] = {
                    y: y,
                    h: root.sectionPitch
                };
                y += root.sectionPitch;
            } else {
                if (key)
                    out[key].h += root.rowPitch;
                y += root.rowPitch;
            }
        }
        return out;
    }

    // How tall the whole column wants to be. From the COUNT, never measured off
    // the list: contentHeight is an estimate until every delegate has been
    // built, and this is what decides whether the list is tall enough to need
    // scrolling at all.
    readonly property real needed: root.rowY(root.rows.length)

    // SLACK UNDER THE LAST SECTION, so the last letter can sit in the middle of
    // the view like every other one.
    //
    // Without it the bottom of the list is the bottom of the list: scrolling to
    // Z pins Z's two applications to the floor, and the one section that cannot
    // be centred is the one you reach by running the rail all the way down.
    // Half a view minus half the block is exactly the room that costs.
    readonly property real tail: {
        if (root.needed <= list.height)
            return 0;
        for (let i = root.rows.length - 1; i >= 0; i--) {
            const key = root.rows[i].section;
            if (!key)
                continue;
            // GUARDED, because `rows` and `sectionSpan` are two separate
            // bindings and this is a third that reads both of them. There is a
            // window, at startup and after anything changes the set of installed
            // applications, in which the rows have been rebuilt and the spans
            // have not, and a key taken out of the new list has no entry in the
            // old map: reading `.h` off that threw a TypeError into the log
            // every time, for a state that corrects itself on the very next
            // evaluation. No span means there is nothing to measure and so no
            // room to leave, and this runs again the moment the map catches up.
            const span = root.sectionSpan[key];
            return span ? Math.max(0, (list.height - span.h) / 2) : 0;
        }
        return 0;
    }

    // Which section the rail is pointing at, and where the HANDLE is: how far
    // down the rail, and how far out of it.
    //
    // Both axes come from the drag, which is the whole gesture. Hover did the
    // job with one axis and a constant for the other, and that is a different,
    // worse gesture wearing the same picture: the curve was always the same
    // depth, so there was nothing to feel. How far you pull it out is how far
    // you have committed to the rail, and it is yours to vary.
    property string marked: ""
    property real scrubY: 0
    property real depth: 0
    property bool grabbing: false

    // WHICH ROW THE POINTER IS OVER, which is a different question from which
    // row is selected, and this is the whole of the difference.
    //
    // Hover used to move the selection, guarded by a "has the pointer moved
    // yet" flag. The guard could not work, because the pointer is not the only
    // thing that moves: type a letter and the list under a perfectly still
    // cursor is a different list, so a row you never pointed at arrives under
    // the pointer, reports an enter, and takes the selection you were about to
    // press Return on. The launcher opened whatever the mouse happened to be
    // parked on.
    //
    // So hover is now only a LOOK. Selection moves for the keyboard, for the
    // rail, and for a click, all of which are things you did on purpose.
    property int hovered: -1

    // Being pulled out of the bottom edge by hand, and how far.
    //
    // While this is true the panel's height is the POINTER'S, not the reveal
    // animation's: the top edge has to be where the finger is or the gesture is
    // a switch with a picture of a drag on it. The animation takes over at the
    // moment of release, from wherever the drag left it.
    property bool dragging: false
    property real dragProgress: 0

    function dragTo(fraction: real): void {
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        root.dragging = false;
        // Hand the animation the position the drag ended at, so it carries on
        // from there instead of snapping back to start the journey again.
        rise.value = root.dragProgress;
        // ONLY show what is not already shown, which matters now that this call
        // arrives from two different gestures. The bottom edge pulling a closed
        // launcher out wants everything show() does; the panel's own put-away
        // push, reversed mid-flight, wants none of it. show() clears the query,
        // the marked section and the selection, and deciding NOT to close
        // something must not also throw away what you had typed into it and
        // where you had scrubbed to. A launcher that is already shown has `rise`
        // pointed at 1 anyway, so letting go simply walks it back up.
        if (open) {
            if (!root.shown)
                root.show();
        } else {
            root.hide();
        }
        // Back to nothing, so the NEXT press starts from the bottom. Left at the
        // last drag's depth, a plain click would hand the animation a starting
        // point half way up and the panel would appear already half open.
        root.dragProgress = 0;
    }

    // Held out by the CLI rather than by a cursor.
    //
    // The rail answers to hover, and hover is the one input that cannot be
    // scripted: a warped pointer delivers no motion inside a surface it is
    // already in, so nothing about the bow can be seen from the terminal
    // without this. Same reason `banditshell menu open` exists.
    // A LATCH, because the CLI has no release: a terminal hands over a position
    // and walks away, so something has to decide when the hold is over. A real
    // hand arriving on the rail is that something, and so is the panel closing.
    // Left latched, the bow never falls back to straight after a drag, because
    // the drag was not what was holding it out.
    property bool scrubbing: false

    function scrubTo(fraction: real): void {
        root.scrubbing = fraction >= 0;
        if (!root.scrubbing)
            return;
        root.scrubY = Math.max(0, Math.min(fraction, 1)) * rail.height;
        root.depth = root.bowDepth * 0.55;
        root.scrubAt(root.scrubY);
    }

    // The handle, from a point on the rail. x is measured INWARD from the rail's
    // own centre, so dragging toward the middle of the panel deepens the curve
    // and letting the pointer drift back toward the edge flattens it.
    function grabAt(x: real, y: real): void {
        root.scrubY = Math.max(0, Math.min(y, rail.height));
        root.depth = Math.max(0, Math.min(rail.width / 2 - x, root.bowDepth));
        root.scrubAt(root.scrubY);
    }

    property int selected: 0

    // For `banditshell status`.
    readonly property real drawnHeight: panel.height
    readonly property int resultCount: root.rows.filter(r => !!r.entry).length
    // The VIEW and the TAIL as well as the position, because the whole question
    // about this list is whether a section is in the middle of it, and that
    // cannot be read off a scroll offset alone.
    readonly property string scrollInfo: `${query.text ? `search "${query.text}"` : root.opened ? `folder "${root.openedFolder?.name ?? root.opened}"` : root.marked || "top"}, row ${root.selected} of ${root.rows.length}, at ${Math.round(list.contentY)}/${Math.round(list.maxScroll)}, view ${Math.round(list.height)}px, tail ${Math.round(root.tail)}px, section at ${Math.round(root.sectionSpan[root.marked]?.y ?? -1)}+${Math.round(root.sectionSpan[root.marked]?.h ?? 0)}${root.menuOpen ? ", menu open" : ""}`

    // What had the keyboard before this took it; see ListLauncher, same reason.
    property string restoreTo: ""

    function show(): void {
        root.restoreTo = Hypr.focusedAddress;
        root.shown = true;
        query.text = "";
        root.marked = "";
        root.hovered = -1;
        root.scrubbing = false;
        root.grabbing = false;
        // AT THE TOP OF THE COLUMN, whatever folder was open last time. A
        // launcher opens on the star; being dropped back inside a folder you
        // finished with is the same surprise as opening on the letter A.
        root.opened = "";
        root.closeMenu();
        root.selected = root.firstPick(0, 1);
        list.reset();
        Qt.callLater(query.forceActiveFocus);
        // ARRIVED AT, not travelled to. Closing does not clear the query, so a
        // panel last left showing three results would otherwise open at three
        // results tall and grow to full height inside itself while the panel is
        // also rising: two animations, one of them meaning nothing. Deferred
        // because the size being snapped to follows from the line above.
        Qt.callLater(grow.snap);
    }

    function hide(): void {
        root.shown = false;
        query.focus = false;
        root.scrubbing = false;
        root.grabbing = false;
        root.closeMenu();
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    // ESCAPE UNWINDS ONE THING AT A TIME, innermost first, which is the only
    // reading of the key that is ever wrong to nobody: a sheet over a folder
    // over a launcher is three states deep and closing all three because the
    // outermost one heard the key is a launcher that throws away work.
    function back(): void {
        if (root.menuOpen)
            root.closeMenu();
        else if (root.opened)
            root.leaveFolder();
        else
            root.hide();
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function accept(): void {
        const row = root.rows[root.selected];

        // A FOLDER IS OPENED, NOT LAUNCHED, and the launcher stays up: you
        // asked to look inside something, which is the opposite of being done
        // with the launcher.
        if (row?.folder) {
            root.enterFolder(row.folder);
            return;
        }

        if (row?.entry) {
            Apps.launch(row.entry);
            root.restoreTo = "";
            Hypr.claimNextWindow();
        }
        root.hide();
    }

    // The next row a selection can land on, because a section is a label and
    // selecting one would mean pressing Return on a letter.
    function firstPick(from: int, step: int): int {
        const n = root.rows.length;
        for (let i = 0; i < n; i++) {
            const at = ((from + i * step) % n + n) % n;
            if (root.pickable(root.rows[at]))
                return at;
        }
        return 0;
    }

    function move(delta: int): void {
        if (root.rows.length)
            root.selectRow(root.firstPick(root.selected + delta, delta >= 0 ? 1 : -1));
    }

    // Where a row starts, accumulated. NOT GlideList.reveal, which divides the
    // content height by the count and so assumes every row is the same size:
    // true of a plain list and false the moment sections are in it, where it
    // would put the selection progressively further off the further down you
    // went.
    function rowY(index: int): real {
        let y = 0;
        for (let i = 0; i < index && i < root.rows.length; i++)
            y += root.rows[i].section ? root.sectionPitch : root.rowPitch;
        return y;
    }

    function selectRow(index: int): void {
        root.selected = index;

        const top = root.rowY(index);
        const height = root.rows[index]?.section ? root.sectionPitch : root.rowPitch;
        // A section is worth scrolling to WITH its row, so arrowing into the
        // first application under a letter brings the letter along.
        const lead = index > 0 && root.rows[index - 1]?.section ? root.sectionPitch : 0;

        if (top - lead < list.anchor)
            list.scrollTo(top - lead);
        else if (top + height > list.anchor + list.height)
            list.scrollTo(top + height - list.height);
    }

    // GO TO A SECTION: put its block in the middle of the view, and put the
    // selection on the first thing in it.
    //
    // Centred rather than scrolled-to-top because a heading pinned to the top
    // edge reads as the end of the list above it rather than as the start of the
    // one below, and because the eye is already in the middle of the panel: that
    // is where the rail's own handle is. Short sections then sit where you are
    // looking instead of two hundred pixels above it.
    //
    // The selection follows because the sections are ranked by use now. The
    // first row under a letter is the one you most likely meant, so arriving at
    // the letter and pressing Return should open it without an arrow key in
    // between.
    function markSection(key: string): void {
        root.marked = key;

        const span = root.sectionSpan[key];
        if (!span)
            return;
        list.scrollTo(span.y - Math.max(0, (list.height - span.h) / 2));

        // The row straight after the heading, which is the first application
        // filed under it. No search needed: the flat list puts them adjacent.
        const at = root.rows.findIndex(row => row.section === key);
        if (at >= 0 && root.pickable(root.rows[at + 1]))
            root.selected = at + 1;
    }

    // Which key a point on the rail is, computed from where it falls rather than
    // from a stack of hit areas: one area, one division, and it stays right
    // whatever the alphabet turns out to contain.
    function scrubAt(y: real): void {
        const n = root.keys.length;
        if (n <= 0 || query.text || root.opened)
            return;
        const index = Math.max(0, Math.min(Math.floor(y / rail.height * n), n - 1));
        const key = root.keys[index];
        if (key === root.marked)
            return;
        root.markSection(key);
    }

    // A new set of rows is a new selection, but not necessarily a new PLACE: a
    // section still marked is where you are, so hiding something while browsing
    // K leaves you in K rather than throwing you back to the favourites.
    function reselect(): void {
        // The row that WAS under the pointer is a different row now, or gone.
        // Whatever the pointer is over, it will say so on the next enter.
        root.hovered = -1;

        if (root.marked && root.sectionSpan[root.marked])
            root.markSection(root.marked);
        else
            root.selected = root.firstPick(0, 1);
    }

    onRowsChanged: root.reselect()

    // THE FOLDER YOU ARE IN CAN STOP EXISTING while you are standing in it: its
    // own menu offers to break it up, and config.json is watched, so a hand
    // editing that file out from under the shell does the same thing. Either
    // way the column would go on showing a heading with nothing under it and no
    // way back, so leaving is not a decision here, it is the only state left.
    onOpenedFolderChanged: if (root.opened && !root.openedFolder)
        root.leaveFolder()

    // ------------------------------------------------------------------
    // THE CONTEXT SHEET: which row asked for it, and where that row was.
    //
    // Held HERE rather than inside the delegate, for the reason every menu in
    // this shell is held one level up from what opened it: a delegate is torn
    // down when the list changes, and the list changes on the very first thing
    // the sheet does. A menu owned by the row that opened it would destroy
    // itself the moment you starred anything.
    property var menuEntry: null
    property string menuFolder: ""
    property real menuAt: 0

    readonly property bool menuOpen: !!root.menuEntry || !!root.menuFolder

    // WHERE THE ROW WAS, in the panel's coordinates, so the sheet can sit
    // beside it. Taken once, at the moment of asking: the list is free to
    // scroll afterwards and the sheet stays where it was put, which is what
    // every other menu on every other desktop does and what stops a sheet from
    // chasing a row through a flick.
    //
    // A NUMBER rather than the row itself, because the keyboard has no row to
    // hand over. A delegate knows exactly where it is and says so; the key
    // below has only an index, and works the position out from the same
    // arithmetic the scrolling already uses.
    function openMenuAt(y: real, entry: var, folder: string): void {
        root.menuAt = y;
        root.menuEntry = entry;
        root.menuFolder = folder;
    }

    // THE SHEET, FROM THE KEYBOARD, because everything else in this launcher is
    // reachable without leaving the home row and a list you drive with the
    // arrow keys should not need a hand on the mouse to say "not that one, star
    // this one". The Menu key and Shift+F10 are what the toolkits already agree
    // this means, so there is nothing here to learn.
    function openMenuForSelection(): void {
        const row = root.rows[root.selected];
        if (!root.pickable(row))
            return;

        // The row's middle, in the list's own coordinates, then in the panel's.
        // rowY is the accumulator the selection already scrolls by, so the sheet
        // lands beside the row for the same reason the row is on screen at all.
        const mid = root.rowY(root.selected) + root.rowPitch / 2 - list.contentY;
        root.openMenuAt(list.mapToItem(panel, 0, mid).y, row.entry, row.folder);
    }

    function closeMenu(): void {
        root.menuEntry = null;
        root.menuFolder = "";
        // The sheet's name field takes the keyboard while it is up, and the
        // launcher is a search box first: without this the next thing typed
        // after closing a sheet goes into a field that is no longer on screen.
        // Guarded on the launcher still being open, because hide() closes the
        // sheet on its way out and has just dropped the focus on purpose.
        if (root.shown)
            Qt.callLater(query.forceActiveFocus);
    }

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // How far out the rail is bowed, 0 to 1. Eased rather than snapped, so
    // arriving on the rail draws the curve out and leaving lets it fall back.
    // How tall the column WANTS to be, chased rather than cut to.
    //
    // Same split, and the same speed, as a menu resizing: implicit is where it is
    // going, the Follow is where it is. Every keystroke changes the result count,
    // and because the list is centred in its well, a change in height moves
    // everything on screen. Snapping that was most of what "snappy but not
    // smooth" meant.
    //
    // The target is the CONTENT's height, not the well's. Opening is the panel's
    // own animation and the list should sit exactly inside it the whole way up;
    // only what the query does to the count is worth easing.
    Follow {
        id: grow

        target: root.needed
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.5
    }

    Follow {
        id: bow

        // Held out while the handle is held, eased back when it is let go. The
        // DEPTH itself is never animated: that is the pointer's own position,
        // and smoothing it would put the handle behind the finger dragging it.
        target: root.grabbing || root.scrubbing ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // Under the panel, so a click anywhere else puts it away.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: {
            root.hide();
        }
    }

    // THE WAY BACK IN. Push the column down and it goes back into the bottom
    // edge it rose out of, which is the shell's one rule for getting rid of
    // anything (DESIGN.md 15): everything goes back into the edge or corner it
    // came out of, by the gesture that brought it out, reversed.
    //
    // It has to be HERE rather than on the bottom edge, because the bottom edge
    // is not reachable once the launcher is up: LaunchEdge is armed only while
    // the launcher is closed, and it clamps its own reported fraction at zero, so
    // it can say "opening" and nothing else. The panel is what is on the screen,
    // so the panel is what you push.
    //
    // AND IT FIXES A SECOND, WORSE THING while it is here. The panel's frame is
    // `padding.large` down every side, and the frame, the room around the field
    // and the strip beside the rail are all bare Items with no MouseArea in
    // them. Every press that landed on any of that fell straight through to the
    // `catcher` declared above and CLOSED the launcher. A cursor hits that frame
    // occasionally; a nine-millimetre fingertip aiming at a row or at the field
    // hits it constantly, so the launcher was dismissing itself on the way to
    // being used. Covering the panel with this catches those presses here
    // instead.
    //
    // `onTapped` is deliberately UNWIRED. A tap on the panel's own padding
    // should do nothing at all: it was aimed at something and it missed, and the
    // answer to a miss is to leave the screen alone rather than to guess. A tap
    // OUTSIDE the panel still closes it via the catcher, which is the correct
    // dismissal and the discoverable one.
    Pull {
        id: putAway

        // A SIBLING of the panel wearing the panel's geometry, rather than a
        // child filling it, and that is a correctness question rather than a
        // preference.
        //
        // Pull measures the gesture in its PARENT's coordinates, because the
        // parent is the frame that stays still while the pull item's own
        // top-left is moved about by the thing it is driving (components/Pull.qml
        // and DESIGN.md 15). Make it a child of the panel and the parent IS the
        // thing being dragged: the panel's top edge tracks the finger by design,
        // so a press origin measured against that edge never moves at all, every
        // delta reported is only the frame-to-frame remainder, and the gesture
        // collapses into noise. Out here the parent is this screen-sized item,
        // which does not move, and the pull item's own y is exactly the panel's,
        // so `y + mouse.y` is the finger's position on the screen and nothing
        // else.
        //
        // It still sits UNDER the panel's contents, which is the other half of
        // what the primitive asks for over a panel: declaration order is input
        // order in QML, so declared before the panel it covers the same
        // rectangle and gets only the presses the rail, the rows and the field
        // did not want. The rail in particular must go on winning, because a run
        // down the rail is a downward drag too and it is emphatically not a
        // request to put the launcher away.
        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        // Nothing to push away that is not up. `armed` rather than `enabled`,
        // which is the mechanism the primitive provides for exactly this: an
        // unarmed Pull refuses the press and lets it fall through, where a
        // disabled MouseArea would have to be torn down mid-gesture to become
        // one.
        armed: root.open

        // Straight down, back into the edge it rose from, written as the vector
        // it is. These two numbers are the whole of what says which way this
        // gesture runs.
        dirX: 0
        dirY: 1

        // An EDGE's tolerance, not a corner's. A corner has ninety degrees of
        // "into the screen" to divide between its gestures and an edge has a
        // hundred and eighty, so the same number that is generous in a corner is
        // stingy here.
        angle: Appearance.sizes.pullAngleEdge

        // The panel's own settled height, so one finger-length of panel is one
        // finger-length of travel and the top edge stays under the hand.
        //
        // `fullHeight` rather than `height`, and that is not a detail: `height`
        // is `fullHeight * dragProgress`, which this very gesture is collapsing,
        // so the scale would shrink as you pushed and the panel would accelerate
        // away from the finger measuring it. fullHeight is where the panel
        // SETTLES, which is a fact about the screen rather than about how far
        // through the gesture you are, and it is never zero.
        travel: panel.fullHeight

        // TWO INVERSIONS, and both are real rather than bookkeeping.
        //
        // `dragTo` takes how far OPEN the panel is and this gesture reports how
        // far PUT AWAY it is, so the two are one minus each other: a push that
        // has travelled a quarter of the panel's height leaves three quarters of
        // it showing.
        onPulled: fraction => root.dragTo(1 - fraction)

        // And `finished(true)` means the push CARRIED ON in its direction, which
        // for a dismissal means gone, which is `open: false` to dragEnd. Reverse
        // it mid-push and `finished(false)` arrives instead, and the launcher
        // stays up with the query and the marked section exactly as they were.
        onFinished: gone => root.dragEnd(!gone)
    }

    Item {
        id: panel

        readonly property real bandY: root.height - root.inset
        readonly property real fullHeight: root.height - root.inset * 2

        x: (root.width - width) / 2
        width: root.panelWidth

        // Grows UPWARD out of the bottom band and stays joined to it the whole
        // way: a column rising out of the shell rather than a sheet arriving
        // over it.
        height: fullHeight * (root.dragging ? root.dragProgress : rise.value)
        y: bandY - height

        visible: height > 0

        Item {
            anchors.fill: parent
            clip: true

            // THE RAIL. Down the right edge, full height, the only thing in the
            // panel that is always in the same place.
            MouseArea {
                id: rail

                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.rightMargin: Appearance.padding.normal
                anchors.topMargin: Appearance.padding.large
                anchors.bottomMargin: Appearance.padding.large

                // NOTHING TO INDEX INSIDE A FOLDER, so the ruler goes and the
                // column takes the width back. Eased rather than switched,
                // because the well is anchored to this edge: a rail that
                // vanished on one frame would snap every row in the list a
                // finger's width to the right, and entering a folder is already
                // a change of contents without also being a jump.
                width: root.opened ? 0 : root.railWidth
                enabled: !root.opened

                hoverEnabled: true
                preventStealing: true
                cursorShape: Qt.SizeVerCursor

                Behavior on width {
                    NumberAnimation {
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                // PRESS AND DRAG, not hover. Passing a cursor over the rail is
                // not a request to go anywhere, and treating it as one made the
                // list bolt away from under anyone who crossed the right edge on
                // their way somewhere else. Grabbing it is unambiguous, it is
                // the gesture the phone has, and it is what lets the pull depth
                // mean anything.
                onPressed: mouse => {
                    // The hand takes the rail off the CLI; see root.scrubbing.
                    root.scrubbing = false;
                    root.grabbing = true;
                    root.grabAt(mouse.x, mouse.y);
                }

                onPositionChanged: mouse => {
                    if (root.grabbing)
                        root.grabAt(mouse.x, mouse.y);
                }

                onReleased: root.grabbing = false
                onCanceled: root.grabbing = false

                // A SCROLL OVER THE RAIL IS SWALLOWED, and it has to be said
                // out loud here or the rail becomes the one place two fingers
                // close the launcher.
                //
                // The put-away Pull is a sibling declared BEFORE the panel
                // wearing the panel's whole rectangle, so it lies under every
                // pixel of this rail, and its direction is straight DOWN. A
                // wheel event a MouseArea does not accept falls past it to
                // whatever is underneath, so without this line a two-finger
                // push down the rail, which is exactly the motion that scrubs
                // toward the end of the alphabet, would clear the Pull's angle
                // gate and dismiss the launcher out from under the hand. The
                // invariant is already written on that Pull for the press path,
                // "a run down the rail is a downward drag too and it is
                // emphatically not a request to put the launcher away", and the
                // press path keeps it by owning the press; input order alone
                // does not keep it for a scroll, because owning a press is not
                // owning a wheel.
                //
                // SWALLOWED rather than answered, which is the other half of
                // the rule and not a gap in it. The rail scrubs to a POSITION:
                // grabAt is handed where on the rail the pointer is, so the
                // list goes to the letter under the finger rather than moving by
                // however far it travelled. A scroll reports motion and never a
                // position, so there is nothing here for it to be given, which
                // is the same answer a Slider's bead and the volume rail reach
                // for the same reason. Faking an origin, taking the first event
                // of a stream as the grab point and stepping from there, was
                // rejected outright: the grab point would be wherever the
                // pointer happened to rest rather than where the hand aimed, so
                // the first flick would snap the list to a letter nobody chose.
                onWheel: wheel => wheel.accepted = true

                Repeater {
                    model: root.keys

                    delegate: Item {
                        id: mark

                        required property string modelData
                        required property int index

                        readonly property string glyph: root.keyIcon(modelData)
                        readonly property bool active: modelData === root.marked
                        readonly property color tint: active ? Appearance.colour.accent : rail.containsMouse ? Appearance.colour.textDim : Appearance.colour.textFaint

                        // Evenly divided by count, so the rail fills its height
                        // whether it carries twelve marks or twenty-eight.
                        readonly property real slot: rail.height / root.keys.length

                        // THE BOW. Marks are pulled toward the middle of the
                        // panel, furthest under the cursor and less either side,
                        // so the rail reads as a line being dragged rather than
                        // as a column with one item highlighted. A Gaussian
                        // rather than a linear falloff: the taper has to have no
                        // corner in it, or the curve looks like a tent.
                        readonly property real fromCursor: (index + 0.5) * slot - root.scrubY

                        x: -root.depth * bow.value * Math.exp(-Math.pow(fromCursor / (slot * root.bowSpread), 2))
                        y: index * slot
                        width: rail.width
                        height: slot

                        // Centred on the INK, not on the line box: a rail is a
                        // ruler, and marks that are level with each other by
                        // luck of which letters have descenders is not a ruler.
                        StyledText {
                            id: letter

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: letter.inkOffsetX
                            anchors.verticalCenterOffset: letter.inkOffsetY
                            visible: !mark.glyph
                            text: mark.modelData
                            font.pixelSize: Appearance.font.size.small
                            color: mark.tint
                        }

                        Icon {
                            id: markGlyph

                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: markGlyph.inkOffsetX
                            anchors.verticalCenterOffset: markGlyph.inkOffsetY
                            visible: !!mark.glyph
                            size: Appearance.font.size.small
                            name: mark.glyph
                            color: mark.tint
                        }
                    }
                }
            }

            // The mark you are on, on a disc, at the far end of the bow. It is
            // the one thing in this concept drawn in the accent: the rail is a
            // scrubber, and a scrubber needs a handle you can see without
            // looking away from the list it is moving.
            G2Rect {
                id: disc

                // NOT `parent.isStar` down in the children. G2Rect's default
                // property is `content`, so anything declared inside it is a
                // child of an inner item and `parent` is that item, not this
                // one. The lookup silently yielded undefined, and an undefined
                // binding on `visible` leaves the property at its default, which
                // is true: the star was drawn over every letter, always.
                readonly property string glyph: root.keyIcon(root.marked)

                // BEYOND the deepest letter, not on top of it. The disc is the
                // handle and the letters are the line it is pulling, so it has
                // to lead them: parked at the same depth it simply covered the
                // one letter you were reading.
                x: rail.x + rail.width / 2 - (root.depth + width / 2 + Appearance.padding.normal) * bow.value - width / 2
                y: rail.y + root.scrubY - height / 2
                width: root.badgeSize
                height: width
                radius: width / 2

                visible: bow.value > 0.01 && !!root.marked
                opacity: bow.value
                color: Appearance.colour.accent

                // In the middle of the DISC, which means the middle of the
                // letter, not the middle of the box the letter is delivered in.
                // See StyledText.inkOffsetX.
                StyledText {
                    id: discLetter

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: discLetter.inkOffsetX
                    anchors.verticalCenterOffset: discLetter.inkOffsetY
                    visible: !disc.glyph
                    text: root.marked
                    font.pixelSize: Appearance.font.size.large
                    color: Appearance.colour.accentText
                }

                Icon {
                    id: discGlyph

                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: discGlyph.inkOffsetX
                    anchors.verticalCenterOffset: discGlyph.inkOffsetY
                    visible: !!disc.glyph
                    size: Appearance.font.size.large
                    name: disc.glyph
                    color: Appearance.colour.accentText
                }
            }

            // The search, at the BOTTOM, where a phone puts the thing you reach
            // for. Everything else stacks upward off it.
            Item {
                id: field

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.normal
                anchors.bottomMargin: Appearance.padding.large
                height: Appearance.font.size.normal + Appearance.padding.normal

                Icon {
                    id: searchGlyph

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.gutter
                    size: Appearance.font.size.normal
                    name: "search"
                    color: query.text ? Appearance.colour.accent : Appearance.colour.textGhost
                }

                StyledText {
                    anchors.left: searchGlyph.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !query.text
                    text: "Search, or run the rail"
                    font.pixelSize: Appearance.font.size.normal
                    color: Appearance.colour.textGhost
                }

                TextInput {
                    id: query

                    anchors.left: searchGlyph.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    font.family: Appearance.font.family
                    // The BODY size. It was set as a headline, which is what a
                    // search field is on a phone where it is the only thing on
                    // the screen. Here it sits under a hundred and forty rows
                    // set smaller than it, and it was shouting over all of them.
                    font.pixelSize: Appearance.font.size.normal
                    renderType: Text.NativeRendering
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText
                    clip: true

                    // Typing means you have stopped browsing. The column is a
                    // new column, so it starts at its own top rather than at
                    // whatever offset the last letter left behind.
                    //
                    // AND IT LEAVES THE FOLDER, because a search is over
                    // everything installed and always has been. Searching
                    // inside a folder is the wrong shape of question for a
                    // place that holds six things you chose: you can already
                    // see all of them.
                    onTextChanged: {
                        if (text) {
                            root.marked = "";
                            root.opened = "";
                            root.closeMenu();
                        }
                        list.reset();
                    }

                    Keys.onPressed: event => {
                        const page = Math.max(1, Math.floor(list.height / root.rowPitch) - 1);

                        // THE SHEET TAKES THE KEYS WHILE IT IS UP, and it has to,
                        // because it is over the list it would otherwise be
                        // scrolling: arrowing "down the menu" while the column
                        // behind it moved instead is a control that answers
                        // somewhere you are not looking. The field keeps the keys
                        // it is the field for, so you can still type, and Escape
                        // goes on unwinding one layer at a time.
                        //
                        // The naming face is not here: it has a TextInput of its
                        // own which takes the focus, so these handlers are not
                        // reached at all while a folder is being named.
                        if (root.menuOpen) {
                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.back();
                                break;
                            case Qt.Key_Down:
                            case Qt.Key_Tab:
                                sheet.step(1);
                                break;
                            case Qt.Key_Up:
                            case Qt.Key_Backtab:
                                sheet.step(-1);
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                sheet.activate();
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                            return;
                        }

                        switch (event.key) {
                        case Qt.Key_Escape:
                            root.back();
                            break;
                        // under the selection, left leaves the one you are in:
                        // the same two directions the finger has, so neither
                        // input has to be learned separately.
                        case Qt.Key_Right:
                            root.enterFolder(root.rows[root.selected]?.folder ?? "");
                            break;
                        case Qt.Key_Left:
                            root.leaveFolder();
                            break;
                        // THE HOLD, ON THE KEYBOARD. Both spellings, because
                        // the dedicated key is missing from most of the
                        // keyboards that have shipped this decade.
                        case Qt.Key_Menu:
                            root.openMenuForSelection();
                            break;
                        case Qt.Key_F10:
                            if (!(event.modifiers & Qt.ShiftModifier))
                                return;
                            root.openMenuForSelection();
                            break;
                        case Qt.Key_Return:
                        case Qt.Key_Enter:
                            root.accept();
                            break;
                        case Qt.Key_Down:
                        case Qt.Key_Tab:
                            root.move(1);
                            break;
                        case Qt.Key_Up:
                        case Qt.Key_Backtab:
                            root.move(-1);
                            break;
                        case Qt.Key_PageDown:
                            root.move(page);
                            break;
                        case Qt.Key_PageUp:
                            root.move(-page);
                            break;
                        default:
                            return;
                        }
                        event.accepted = true;
                    }
                }
            }

            // THE ROOM the column has. The list is placed inside it rather than
            // stretched to it; see list.height for why.
            Item {
                id: well

                anchors.left: parent.left
                anchors.right: rail.left
                anchors.top: parent.top
                anchors.bottom: field.top
                anchors.leftMargin: Appearance.padding.large
                anchors.rightMargin: Appearance.padding.normal
                anchors.topMargin: Appearance.padding.large
                anchors.bottomMargin: Appearance.padding.large

                StyledText {
                    anchors.centerIn: parent
                    visible: !root.rows.length
                    text: query.text ? "nothing matches" : "no applications found"
                    font.pixelSize: Appearance.font.size.normal
                    color: Appearance.colour.textGhost
                }

                // EVERYTHING, in one column. The rail moves this; it never
                // replaces it.
                GlideList {
                    id: list

                    width: well.width
                    anchors.verticalCenter: well.verticalCenter

                    // AS TALL AS IT NEEDS, up to the room available, and CENTRED
                    // in what is left over.
                    //
                    // A search that returns three things used to leave them
                    // pinned to the top of a panel the height of the screen,
                    // with two feet of nothing under them: the results were as
                    // far from the field you typed into as it is possible to put
                    // them, and the panel read as mostly empty rather than as
                    // mostly answer. Sized to the content, the three sit in the
                    // middle of the column, where the eye already is.
                    //
                    // From the row COUNT, never from contentHeight: a ListView's
                    // is an estimate until every delegate has been built, so
                    // binding the height to it is a height that changes as you
                    // scroll.
                    height: Math.max(0, Math.min(well.height, grow.value))

                    clip: true
                    model: ScriptModel {
                        values: root.rows
                    }
                    // NOT REUSED, and this is the price of the transitions below.
                    //
                    // Recycling is the right default for a long list and it is
                    // incompatible with animating one. A row being removed has to
                    // stay alive and visible while it fades, and a recycling view
                    // wants that same item back immediately to hand it the
                    // content of a row further down. Both happened: the item was
                    // handed new text while its own removal was still running, so
                    // it sat in the new row's place drawing the new row's name
                    // over the top of it. Two names on one line, and not
                    // transiently either, because whichever animation finished
                    // last left it wherever it had got to.
                    //
                    // So the view builds and drops rows instead. Only the window
                    // plus the buffer ever exists either way; what is lost is the
                    // saving on CONSTRUCTION during a long flick, which is a real
                    // cost and a smaller one than a permanently doubled row.
                    reuseItems: false
                    // A deeper buffer to spend some of that back: rows within
                    // this much of the edge are kept rather than rebuilt, so
                    // ordinary scrolling churns nothing.
                    cacheBuffer: root.rowPitch * 8

                    // WHAT A KEYSTROKE LOOKS LIKE.
                    //
                    // A row that stops matching fades out where it stands, a row
                    // that starts matching fades in, and every row that survived
                    // travels to its new place instead of being somewhere else on
                    // the next frame. That last one is the whole effect: it is the
                    // survivors moving that makes a narrowing list read as the
                    // same list narrowing, rather than as one list replaced by
                    // another. It is also the one that does nothing at all unless
                    // the model can tell what survived, which is what the row
                    // cache above is for.
                    //
                    // The fades start AT ONCE, on the keystroke, with no pause in
                    // front of them. They are what makes the list feel like it is
                    // keeping up, and they are cheap to watch because a row
                    // changing opacity in place asks nothing of the eye.
                    //
                    // Out steeper than in, the same asymmetry the menus cross-fade
                    // with: a leaver holds its line until it is gone, so if both
                    // were linear there would be a moment of two legible names on
                    // one line. OutCubic on the way to zero is steep first and
                    // flat last, so the leaver is invisible well before the
                    // arrival is readable.
                    add: Transition {
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Appearance.anim.fast
                        }
                    }

                    remove: Transition {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Appearance.anim.fast
                            easing.type: Easing.OutCubic
                        }
                    }

                    // MOVEMENT WAITS. Nothing else does.
                    //
                    // The results are never held back: fades run the instant a
                    // keystroke lands, so the column is always telling the truth
                    // about what matches. What is buffered is the TRAVEL, and
                    // only the travel, because that is the part that costs
                    // something to watch. Every keystroke restarts this pause, so
                    // while your hands are moving no row ever gets far enough
                    // through it to take a step: the column holds still, fading,
                    // and settles into its new order the moment you stop. Type
                    // "firefox" at speed and nothing slides at all; type it and
                    // pause, and it glides once.
                    //
                    // The alternative was delaying the SEARCH, and that is the
                    // one thing a launcher must not do. Waiting to tell you what
                    // it found reads as the machine being slow, however little it
                    // waits.
                    displaced: Transition {
                        SequentialAnimation {
                            PauseAnimation {
                                duration: root.moveDelay
                            }

                            NumberAnimation {
                                property: "y"
                                duration: Appearance.anim.normal
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    // The room under the last section, so it can be centred like
                    // every other one. See root.tail.
                    footer: Item {
                        width: list.width
                        height: root.tail
                    }

                    delegate: Item {
                        id: row

                        required property var modelData
                        required property int index

                        readonly property bool isSection: !!modelData.section
                        readonly property var entry: modelData.entry
                        readonly property string glyph: modelData.icon
                        readonly property string folder: modelData.folder
                        readonly property var folderData: row.folder ? Apps.folders[row.folder] : null
                        readonly property var inside: row.folder ? Apps.folderApps(row.folder) : []

                        // SOMETHING THE ROW CAN DO, which is what decides whether
                        // it answers a press at all. An application launches, a
                        // folder opens; a letter is a label and a press on it is
                        // a press on nothing.
                        readonly property bool actionable: !!row.entry || !!row.folder

                        // THE WAY BACK OUT, which is the folder's own heading and
                        // nothing else. A heading is not usually pressable; this
                        // one is the only chrome the folder view has, so it is.
                        readonly property bool isBack: row.isSection && modelData.section === root.opened

                        // THE THREE STATES, and they are three, not two. Chosen
                        // is what Return opens; under is where the pointer
                        // happens to be; away is filed in the drawer.
                        readonly property bool chosen: index === root.selected
                        readonly property bool under: index === root.hovered
                        readonly property bool away: !!entry && Apps.isHidden(entry)
                        readonly property color ring: Appearance.colour.accent

                        // WHAT IS WAITING ON THIS ROW.
                        //
                        // A folder carries its members' notifications, added up,
                        // because a folder is closed by definition and a count
                        // that only appeared once you had opened it would be a
                        // count you could only find by looking for it. That is
                        // also what makes the swipe honest on a folder: left
                        // clears everything the folder is holding, which is
                        // exactly what the number said it was holding.
                        readonly property int unread: row.folder ? AppNotifs.countForAll(row.inside) : row.entry ? AppNotifs.countFor(row.entry) : 0
                        readonly property var newest: row.entry ? AppNotifs.newestFor(row.entry) : null

                        // rather than a table: RIGHT OPENS A FOLDER IF THERE IS
                        // ONE, AND OTHERWISE CLEARS, LEFT ALWAYS CLEARS. Inside a
                        // folder every row is an application, so nothing there
                        // has a folder to open and both directions clear, which
                        // is the behaviour asked for and falls out of the rule
                        // rather than being a second case written next to it.
                        //
                        // A direction with nothing to do does not move. Rubber
                        // banding an inert row is a promise the release then has
                        // to break, and a row that simply does not budge says
                        // "nothing that way" in the only language a finger reads.
                        readonly property bool canOpen: !!row.folder
                        readonly property bool canClear: row.unread > 0

                        // HOW FAR THE ROW HAS BEEN DRAGGED ACROSS, in pixels,
                        // signed the way the finger went.
                        //
                        // The row's CONTENTS move and the row does not: the
                        // marks the swipe uncovers have to stay where they are
                        // while the thing over them slides off them, and a row
                        // that moved as a whole would carry them along and
                        // uncover nothing. So everything drawn sits on `sled`
                        // below and this is its x.
                        property real slide: 0
                        property bool swiping: false

                        // HOW FAR IS FAR ENOUGH, from the row's own width rather
                        // than from a number in the config, so the gesture asks
                        // for the same PROPORTION of the row on every panel
                        // width and at every scale. `dragDismissFraction` is the
                        // shell's existing answer to "how much of a thing counts
                        // as throwing it away", which is the question being
                        // asked here.
                        readonly property real commitAt: Math.max(1, list.width * Appearance.sizes.dragDismissFraction)

                        readonly property bool past: Math.abs(row.slide) >= row.commitAt

                        // WHAT THE ROW WOULD DO IF YOU LET GO NOW. Read by the
                        // marks under the sled, so the row is always showing the
                        // answer to the question the hand is in the middle of
                        // asking rather than announcing it afterwards.
                        readonly property bool willOpen: row.slide > 0 && row.canOpen
                        readonly property bool willClear: row.canClear && (row.slide < 0 || (row.slide > 0 && !row.canOpen))

                        function armed(dx: real): bool {
                            return dx > 0 ? row.canOpen || row.canClear : row.canClear;
                        }

                        // Freely as far as the commit point, and grudgingly past
                        // it. The resistance is not decoration: it is where the
                        // hand is told it has arrived, on a gesture with no
                        // detent and no edge to hit.
                        function resist(dx: real): real {
                            if (!row.armed(dx))
                                return 0;
                            const far = Math.abs(dx);
                            const over = far - row.commitAt;
                            const travel = over <= 0 ? far : row.commitAt + over * Appearance.sizes.dragResistance;
                            return dx < 0 ? -travel : travel;
                        }

                        function settleSwipe(): void {
                            const acting = row.past;
                            const open = row.willOpen;
                            const clear = row.willClear;

                            row.swiping = false;
                            row.slide = 0;

                            if (!acting)
                                return;
                            if (open)
                                root.enterFolder(row.folder);
                            else if (clear)
                                row.clear();
                        }

                        function clear(): void {
                            if (row.folder)
                                AppNotifs.dismissForAll(row.inside);
                            else
                                AppNotifs.dismissFor(row.entry);
                        }

                        width: list.width
                        height: isSection ? root.sectionPitch : root.rowPitch

                        // DECLARED FIRST, deliberately: declaration order is
                        // input order in QML, so a row-wide target that comes
                        // last sits on top of the control inside it and eats its
                        // clicks.
                        MouseArea {
                            id: pointer

                            anchors.fill: parent
                            enabled: row.actionable || row.isBack
                            // NO hoverEnabled, deliberately, and it must stay
                            // that way: a MouseArea reports itself hovered from
                            // the moment a press lands on it, whatever produced
                            // the press, so a finger looked exactly like a
                            // cursor. See the HoverHandler below. The hover is
                            // its now, and only a pointer can move it.
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            // WHETHER THE PRESS ALREADY DID SOMETHING, so the
                            // release does not do a second thing on top of it.
                            property bool held: false

                            // WHERE THE PRESS LANDED, and whether this is still
                            // anybody's gesture. `deciding` is true from the
                            // press until the motion is big enough to be read as
                            // horizontal, which is the whole of the arbitration
                            // between this row and the list it is in.
                            property real fromX: 0
                            property real fromY: 0
                            property bool deciding: false

                            onPressed: mouse => {
                                pointer.held = false;
                                pointer.fromX = mouse.x;
                                pointer.fromY = mouse.y;
                                pointer.deciding = true;
                                row.swiping = false;
                            }

                            // A HORIZONTAL DRAG IS THIS ROW'S; A VERTICAL ONE IS
                            // THE LIST'S, and nobody has to be told which.
                            //
                            // A ListView is a Flickable, and a Flickable filters
                            // its children's presses and takes them the moment
                            // the finger has travelled far enough ALONG ITS OWN
                            // AXIS. That is the arbitration already, for free and
                            // in the right direction: scroll the column and the
                            // list takes the press off this row mid-gesture,
                            // exactly as it should.
                            //
                            // What it cannot do is the other half. Once the
                            // motion is decidedly sideways this row has to KEEP
                            // the press, or a swipe with any slope in it is stolen
                            // partway across by the list and the row snaps back
                            // under a finger that was still moving. So the steal
                            // is refused, but only from the moment there is
                            // something to refuse it for: `preventStealing` set
                            // from the press would make every drag on a row the
                            // row's and the column would stop scrolling.
                            preventStealing: row.swiping

                            onPositionChanged: mouse => {
                                if (!pointer.pressed)
                                    return;

                                if (pointer.deciding) {
                                    const dx = mouse.x - pointer.fromX;
                                    const dy = mouse.y - pointer.fromY;
                                    if (Math.abs(dx) < Appearance.sizes.dragThreshold)
                                        return;
                                    // STRICTLY sideways: a tie goes to the list,
                                    // because a diagonal that is genuinely
                                    // ambiguous is far more often a scroll that
                                    // wandered than a swipe that did.
                                    if (Math.abs(dx) <= Math.abs(dy))
                                        return;
                                    pointer.deciding = false;
                                    row.swiping = true;
                                    // The hold was aimed at a stationary finger.
                                    // Qt does not cancel it on movement, so a
                                    // slow swipe would open the sheet halfway
                                    // across; the same trap NotificationCard
                                    // records for its own throw.
                                    pointer.held = true;
                                }

                                row.slide = row.resist(mouse.x - pointer.fromX);
                            }

                            onReleased: row.settleSwipe()
                            onCanceled: row.settleSwipe()

                            // A LONG PRESS IS THE TOUCH RIGHT-CLICK, and both of
                            // them now open the sheet rather than doing one fixed
                            // thing. Touch has no second button and no hover, so
                            // a press and hold is the only way a finger can ask a
                            // row a question; it used to answer with the single
                            // action the row happened to have, which was fine
                            // while there was one and is exactly what stopped
                            // there being two.
                            onPressAndHold: {
                                if (row.swiping)
                                    return;
                                pointer.held = true;
                                root.openMenuAt(row.mapToItem(panel, 0, row.height / 2).y, row.entry, row.folder);
                            }

                            onClicked: mouse => {
                                // The press already acted, or turned into a
                                // swipe. Whether Qt still delivers `clicked`
                                // after `pressAndHold` is a detail of
                                // QQuickMouseArea's release path, and this row
                                // should not depend on the answer either way: on
                                // the build that does deliver it, holding a row
                                // would open the sheet and then launch the
                                // application underneath it.
                                if (pointer.held)
                                    return;

                                // Right anywhere on the row asks the same
                                // question the hold does, without the wait.
                                if (mouse.button === Qt.RightButton) {
                                    if (row.actionable)
                                        root.openMenuAt(row.mapToItem(panel, 0, row.height / 2).y, row.entry, row.folder);
                                    return;
                                }

                                if (row.isBack) {
                                    root.leaveFolder();
                                    return;
                                }

                                root.selected = row.index;
                                root.accept();
                            }
                        }

                        // WHERE THE POINTER IS, and only ever the pointer.
                        //
                        // Passive by construction: a HoverHandler is offered
                        // hover events and nothing else, so it cannot take a
                        // press off the MouseArea above it and, which is the
                        // whole point, it cannot be fooled by one either.
                        //
                        // THAT IS A TOUCH FIX rather than a tidy-up, and it is
                        // worth keeping the reason. QQuickMouseArea::mousePressEvent
                        // calls setHovered(true) itself, so a press synthesised
                        // from a touch made `containsMouse` true the instant a
                        // finger landed, and every hover-gated affordance on the
                        // row lit up mid-press and then acted on the release. The
                        // rule it left behind: hover belongs to exactly ONE
                        // mechanism per item, and here it has to belong to the
                        // mechanism that only a pointer can drive.
                        HoverHandler {
                            id: hover

                            // Whatever the press area answers to, including the
                            // folder's heading: it is a control now, and a
                            // control that does not light up under the pointer
                            // reads as a label somebody made clickable by
                            // accident.
                            enabled: pointer.enabled

                            // A LOOK, and only a look. See root.hovered.
                            onHoveredChanged: {
                                if (hover.hovered)
                                    root.hovered = row.index;
                                else if (root.hovered === row.index)
                                    root.hovered = -1;
                            }
                        }

                        // is while the row slides off it.
                        //
                        // Under the sled rather than beside it, so the marks are
                        // revealed rather than pushed in from the edge: a drawer
                        // being opened, which is a thing the hand understands
                        // without being told, instead of two more objects
                        // arriving on a row that already has enough on it.
                        //
                        // Both are drawn from what the row WOULD DO, not from
                        // which way the finger went, so the mark that appears is
                        // always the promise the release will keep: a row with
                        // no folder shows the same clear mark whichever way you
                        // pull it, which is the rule saying itself.
                        Item {
                            id: marks

                            anchors.fill: parent

                            // How far through the gesture, 0 to 1, off the SLED's
                            // own position rather than off `slide`. They differ
                            // for the length of the snap back, and that is
                            // precisely the moment the marks have to still be
                            // there: taken from `slide` they would blink out on
                            // release and leave the row sliding home over
                            // nothing.
                            readonly property real reach: Math.min(1, Math.abs(sled.x) / row.commitAt)
                            readonly property bool ready: Math.abs(sled.x) >= row.commitAt

                            visible: marks.reach > 0.001

                            Icon {
                                id: leadMark

                                anchors.left: parent.left
                                anchors.leftMargin: root.gutter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: leadMark.inkOffsetY

                                visible: sled.x > 0
                                size: root.iconSize / 2
                                name: row.canOpen ? "folder_open" : "clear_all"
                                opacity: marks.reach
                                color: marks.ready ? Appearance.colour.accent : Appearance.colour.textFaint

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            Icon {
                                id: trailMark

                                anchors.right: parent.right
                                anchors.rightMargin: root.gutter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: trailMark.inkOffsetY

                                visible: sled.x < 0
                                size: root.iconSize / 2
                                name: "clear_all"
                                opacity: marks.reach
                                color: marks.ready ? Appearance.colour.accent : Appearance.colour.textFaint

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }
                        }

                        // EVERYTHING THE ROW DRAWS, on one sled, so the swipe is
                        // one x rather than an offset threaded through six
                        // anchors.
                        //
                        // Geometry rather than `anchors.fill`, because filling
                        // sets x and this is the one property the gesture owns.
                        Item {
                            id: sled

                            x: row.slide
                            width: row.width
                            height: row.height

                            // OFF DURING THE DRAG, on for the way home. While a
                            // finger is on the row its position IS the row's
                            // position and smoothing it would put the sled behind
                            // the hand, which is the same argument the rail's bow
                            // makes about its own depth. The snap back is a
                            // one-shot A to B with nothing to track, so it takes
                            // a duration rather than the shell's usual chase.
                            //
                            // `swiping` is cleared BEFORE `slide` in settleSwipe,
                            // so by the time this binding fires on release the
                            // Behavior is already armed.
                            Behavior on x {
                                enabled: !row.swiping

                                NumberAnimation {
                                    duration: Appearance.anim.fast
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // The letter, in the MARGIN. Outside the icons rather
                            // than above them, so every name in the list starts at
                            // one x and the sections annotate a continuous column
                            // instead of chopping it into blocks.
                            StyledText {
                                id: heading

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: heading.inkOffsetY
                                width: root.gutter

                                visible: row.isSection && !row.glyph
                                text: row.modelData.title
                                font.pixelSize: Appearance.font.size.large
                                color: row.modelData.section === root.marked ? Appearance.colour.accent : Appearance.colour.textDim

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            Icon {
                                id: headingGlyph

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: headingGlyph.inkOffsetY
                                width: root.gutter

                                visible: row.isSection && !!row.glyph
                                size: Appearance.font.size.large
                                name: row.glyph
                                color: row.isBack && row.under ? Appearance.colour.text : row.modelData.section === root.marked ? Appearance.colour.accent : Appearance.colour.textDim

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            // A NAME BESIDE A HEADING GLYPH, which only the open
                            // folder has. The star and the drawer are one mark
                            // each and say everything they need to; a folder is
                            // called something, and the arrow beside it would be
                            // an unlabelled back button without this.
                            StyledText {
                                id: headingLabel

                                anchors.left: parent.left
                                anchors.leftMargin: root.gutter
                                anchors.right: parent.right
                                anchors.rightMargin: Appearance.padding.normal
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: headingLabel.inkOffsetY

                                visible: row.isSection && !!row.glyph && !!row.modelData.title
                                text: row.modelData.title
                                font.pixelSize: Appearance.font.size.large
                                color: row.under ? Appearance.colour.text : Appearance.colour.textDim
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            G2Rect {
                                id: badge

                                anchors.left: parent.left
                                anchors.leftMargin: root.gutter
                                anchors.verticalCenter: parent.verticalCenter
                                width: root.iconSize
                                height: width
                                // Half the width: the squircle at its roundest, which is
                                // a circle that was never cut from one.
                                radius: width / 2

                                visible: !row.isSection
                                // The fill ladder is HOVER, and the ring is
                                // SELECTION. They have to be told apart at a
                                // glance now that they are no longer the same
                                // thing: one step along a fill ladder is not a
                                // difference you can see, and a boundary is the
                                // one way to mark a control without painting a
                                // disc that shouts.
                                color: row.under ? Appearance.colour.fillStrong : Appearance.colour.fill
                                // The ring is always THERE and only sometimes
                                // visible: a stroke is drawn inside the bounds
                                // and takes its width off the radius, so
                                // switching the width on and off would resize the
                                // squircle every time the selection moved. Held
                                // at one width and faded by its alpha, the
                                // geometry never moves and there is something for
                                // a colour animation to cross.
                                stroke: row.chosen ? row.ring : Qt.rgba(row.ring.r, row.ring.g, row.ring.b, 0)
                                strokeWidth: 2

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }

                                Behavior on stroke {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }

                                Image {
                                    id: art

                                    anchors.fill: parent
                                    anchors.margins: Appearance.padding.small
                                    visible: !row.folder && status === Image.Ready
                                    source: row.entry?.icon ? Quickshell.iconPath(row.entry.icon, true) : ""
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    sourceSize.width: width * Screen.devicePixelRatio
                                    sourceSize.height: height * Screen.devicePixelRatio
                                }

                                // A FOLDER WEARS WHAT IS IN IT, which is the only
                                // honest picture of a thing whose whole content
                                // is a choice you made. A generic folder glyph
                                // would make every folder identical in a column
                                // whose entire premise is that you scan it by
                                // icon.
                                //
                                // THE GRID IS COMPUTED, not enumerated. One app
                                // fills the badge, two sit side by side, four
                                // make a square, and nothing here mentions the
                                // numbers one, two or four: the column count is
                                // the square root of however many are being
                                // drawn, the row count follows from it, and the
                                // block is centred in whatever is left. Add a
                                // fifth to the folder and the arrangement is
                                // already right.
                                Item {
                                    id: stack

                                    anchors.fill: parent
                                    anchors.margins: Appearance.padding.small
                                    visible: !!row.folder

                                    // FOUR AT MOST. Beyond that every tile is
                                    // smaller than the mark it is trying to be,
                                    // and a folder of thirty would be a grey
                                    // square either way.
                                    readonly property var shown: row.inside.slice(0, 4)
                                    readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(stack.shown.length)))
                                    readonly property int lines: Math.max(1, Math.ceil(stack.shown.length / stack.cols))
                                    readonly property real cell: stack.width / stack.cols
                                    readonly property real gridY: (stack.height - stack.cell * stack.lines) / 2

                                    Repeater {
                                        model: stack.shown

                                        delegate: Image {
                                            required property var modelData
                                            required property int index

                                            x: (index % stack.cols) * stack.cell
                                            y: stack.gridY + Math.floor(index / stack.cols) * stack.cell
                                            width: stack.cell
                                            height: stack.cell

                                            source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            sourceSize.width: width * Screen.devicePixelRatio
                                            sourceSize.height: height * Screen.devicePixelRatio
                                        }
                                    }
                                }

                                Icon {
                                    id: fallbackGlyph

                                    anchors.centerIn: parent
                                    anchors.horizontalCenterOffset: fallbackGlyph.inkOffsetX
                                    anchors.verticalCenterOffset: fallbackGlyph.inkOffsetY
                                    // An empty folder is a folder you have just
                                    // made, and it has to look like something
                                    // between making it and filling it.
                                    visible: row.folder ? stack.shown.length === 0 : !art.visible
                                    size: root.iconSize / 2
                                    name: row.folder ? "folder" : "apps"
                                    color: Appearance.colour.textDim
                                }

                                // HOW MANY ARE WAITING, on the mark rather than
                                // beside it.
                                //
                                // A count belongs ON the thing it counts, which
                                // is the one convention every phone and every
                                // dock already shares, and it is the reason this
                                // is worth having at all: the launcher is where
                                // you go to reach an application, so it is where
                                // "there are three" is free to read and anywhere
                                // else is a second place to look.
                                //
                                // Drawn over the badge's own corner, so it is
                                // legible against the artwork rather than tinted
                                // by it. The accent is spent here on purpose: the
                                // shell reserves colour for state that earns it,
                                // and something unread is exactly that.
                                G2Rect {
                                    id: unread

                                    x: badge.width - width * 0.78
                                    y: -height * 0.22
                                    width: root.iconSize * 0.46
                                    height: width
                                    radius: width / 2

                                    visible: row.unread > 0
                                    color: Appearance.colour.accent

                                    StyledText {
                                        id: unreadCount

                                        anchors.centerIn: parent
                                        anchors.horizontalCenterOffset: unreadCount.inkOffsetX
                                        anchors.verticalCenterOffset: unreadCount.inkOffsetY

                                        // CAPPED, because the disc is a circle and
                                        // three digits in it is a pill wearing a
                                        // circle's radius. Past nine the exact
                                        // number has stopped being the point.
                                        text: row.unread > 9 ? "9+" : `${row.unread}`
                                        font.pixelSize: Appearance.font.size.small
                                        color: Appearance.colour.accentText
                                    }
                                }
                            }

                            StyledText {
                                id: label

                                anchors.left: badge.right
                                anchors.leftMargin: Appearance.padding.large
                                // Stops where the notice starts, and the notice
                                // is nothing wide when there is nothing waiting,
                                // so an ordinary row gives the name the whole
                                // width it always had.
                                anchors.right: notice.left
                                anchors.rightMargin: Appearance.padding.normal
                                anchors.verticalCenter: parent.verticalCenter

                                visible: !row.isSection
                                text: row.folder ? (row.folderData?.name ?? "") : (row.entry?.name ?? "")
                                font.pixelSize: Appearance.font.size.normal
                                color: row.chosen || row.under ? Appearance.colour.text : Appearance.colour.textDim
                                elide: Text.ElideRight

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Appearance.anim.fast
                                    }
                                }
                            }

                            // WHAT THE NEWEST ONE SAID, at the row's other end.
                            //
                            // A count says there is something; the summary says
                            // whether it is worth stopping for, and it costs no
                            // height because it sits beside the name rather than
                            // under it. That is the same trade MenuRow makes for
                            // its inline detail and for the same reason: a
                            // launcher has width to spare and hundreds of rows,
                            // and stacking a second line would double every one
                            // of them to carry a line most rows do not have.
                            //
                            // NOT ON A FOLDER. The disc already says how many are
                            // in there, and whose they are is the question
                            // opening it answers.
                            StyledText {
                                id: notice

                                anchors.right: parent.right
                                anchors.rightMargin: Appearance.padding.normal
                                anchors.verticalCenter: parent.verticalCenter

                                // A THIRD OF THE ROW at the outside, and nothing
                                // at all when there is nothing to say, so the
                                // name is never squeezed by a column that is not
                                // there.
                                //
                                // MEASURED BESIDE ITSELF, not off its own
                                // implicitWidth, and that is a loop rather than
                                // a preference. An eliding Text works its
                                // implicit width out from the width it was
                                // given, so `width: f(implicitWidth)` is a
                                // binding that reads what it is about to set:
                                // Qt breaks the cycle by leaving the width at
                                // zero, silently, and the row simply had no
                                // second column at all. A TextMetrics is the
                                // same string measured by something with no
                                // width of its own to be confused by, which is
                                // what StyledText and Icon already use it for.
                                width: notice.visible ? Math.min(noticeInk.width, list.width * 0.34) : 0
                                horizontalAlignment: Text.AlignRight

                                visible: !row.isSection && !row.folder && !!row.newest
                                text: row.newest?.summary ?? ""
                                font.pixelSize: Appearance.font.size.small
                                color: Appearance.colour.textFaint
                                elide: Text.ElideRight

                                TextMetrics {
                                    id: noticeInk

                                    font: notice.font
                                    text: notice.text
                                }
                            }
                        }
                    }
                }
            }

            // THE SHEET, AND WHAT PUTS IT AWAY.
            //
            // At the PANEL's level rather than inside the list, for two reasons
            // that are both the list being the wrong owner. A delegate is torn
            // down when the rows change and the rows change on the first thing
            // the sheet does, so a sheet parented to its row would destroy
            // itself mid-action; and the list clips, so a sheet opened on a row
            // near either end would be cut off by the edge of the column it came
            // out of.
            //
            // DECLARED AFTER the well, which is what puts it over the rows:
            // there is no z anywhere in this shell, and declaration order is
            // both paint order and input order.
            MouseArea {
                anchors.fill: parent
                enabled: root.menuOpen
                visible: root.menuOpen
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                // A TAP ANYWHERE ELSE CLOSES THE SHEET AND DOES NOTHING ELSE,
                // which is why this is a surface rather than a handler on the
                // launcher's own catcher. Without it, the tap that dismissed the
                // sheet would land on whatever row happened to be under it and
                // launch an application, which is an expensive way to change
                // your mind.
                onClicked: root.closeMenu()

                // And the same for the wheel, or scrolling to see the rest of a
                // long list of folders would scroll the column behind the sheet
                // instead, leaving it pointing at a row that has moved on.
                onWheel: wheel => wheel.accepted = true
            }

            AppMenu {
                id: sheet

                // BESIDE THE ICONS, not at the pointer. The sheet is about a row
                // and every row starts at the gutter, so lining the two up says
                // which row it belongs to with no line drawn between them, and
                // it lands in the same place whether it was opened by a finger,
                // a right button, or a key.
                x: well.x + root.gutter
                width: Math.min(panel.width * 0.62, well.width - root.gutter)

                // CENTRED ON THE ROW, then pushed back inside the panel. A sheet
                // hanging off the top of the surface it belongs to is a sheet
                // with lines nobody can reach, and the rows nearest both ends are
                // exactly the ones a star gets used on.
                y: Math.max(Appearance.padding.large, Math.min(root.menuAt - sheet.implicitHeight / 2, panel.height - sheet.implicitHeight - Appearance.padding.large))
                height: sheet.implicitHeight

                shown: root.menuOpen
                entry: root.menuEntry
                folder: root.menuFolder

                onActed: root.closeMenu()
                onOpenFolder: key => root.enterFolder(key)

                // The name field has let go. The sheet may still be up (Escape
                // out of naming goes back to the actions rather than out), so
                // this is not closeMenu's job: somebody has to hold the keyboard
                // and while the launcher is open it is always the search field.
                onReleaseKeys: if (root.shown)
                    Qt.callLater(query.forceActiveFocus)
            }
        }
    }
}
