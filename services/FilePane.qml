pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config

// ONE VIEW ONTO ONE DIRECTORY: what is in it, what is selected, and how you got
// there.
//
// This used to be the Files singleton itself, which was correct while there was
// exactly one of everything. Tabs and splits end that: two panes are two
// directories, two selections and two histories at once, and a singleton cannot
// hold two of anything.
//
// WHAT IS NOT HERE IS THE SHELL. A pane cannot `cd` itself - the browser's whole
// model is that the shell owns the directory (see Files.qml), and there is one
// shell for the window rather than one per pane. So a pane ASKS, by emitting
// `wantsCd`, and Files decides which tmux pane the command goes to. The
// alternative - a pane holding a reference back to the service - would make the
// two impossible to reason about separately, which is the thing this split is
// for.
QtObject {
    id: root

    // Where the browser is. Written by Files when the shell reports a move, or
    // directly when there is no shell to ask.
    property string cwd: ""

    property var entries: []
    property bool loading: false
    // Why a directory is empty, when it is not empty. A listing that failed and
    // a listing with nothing in it look identical on screen and mean completely
    // different things.
    property string error: ""

    // WHERE THE KEYBOARD IS, as an index into `visible`.
    property int cursor: -1

    // WHAT IS SELECTED, as NAMES rather than indices.
    //
    // The listing is retaken whenever anything might have changed it, and an
    // index into the previous listing is a different file in the next one -
    // which is how a multi-file delete ends up deleting the wrong multiple
    // files. A name survives a re-list, and one that has genuinely gone simply
    // stops matching.
    property var picked: []

    // Where a range starts. Shift-click extends from here, not from the cursor,
    // so shift-clicking twice re-picks the range rather than growing it by
    // whatever the last click happened to leave behind.
    property int anchor: -1

    property string search: ""
    property bool searching: false

    // Where bs-ls lives. Handed in rather than worked out, because a pane should
    // not have an opinion about where the shell was installed.
    property string lister: ""

    signal wantsCd(string path)

    readonly property bool showHidden: Config.values.files.hidden
    readonly property string sort: Config.values.files.sort

    // WHAT IS ACTUALLY DRAWN: the entries, filtered and ordered. Kept here
    // rather than in the grid because the search and the arrow keys index into
    // the SAME list, and two copies of "which row is third" is the bug that puts
    // the selection on the wrong file.
    readonly property var visible: {
        const all = root.entries.filter(e => root.showHidden || !e.hidden);
        const query = root.search.toLowerCase();
        const matched = query === "" ? all : all.filter(e => e.name.toLowerCase().includes(query));

        // Directories first, always. A folder is a place and a file is a thing;
        // interleaving them by size is a sort nobody asked for. Within each
        // half, whatever the setting says.
        const key = root.sort;
        return matched.slice().sort((a, b) => {
            if ((a.kind === "dir") !== (b.kind === "dir"))
                return a.kind === "dir" ? -1 : 1;
            if (key === "size" && a.size !== b.size)
                return b.size - a.size;
            if (key === "mtime" && a.mtime !== b.mtime)
                return b.mtime - a.mtime;
            if (key === "kind" && a.class !== b.class)
                return a.class < b.class ? -1 : 1;
            return a.name.localeCompare(b.name, undefined, {numeric: true, sensitivity: "base"});
        });
    }

    readonly property var current: root.cursor >= 0 && root.cursor < root.visible.length ? root.visible[root.cursor] : null
    readonly property string currentPath: root.current ? root.join(root.cwd, root.current.name) : ""

    // WHAT AN ACTION ACTS ON. The selection, or - when nothing is selected - the
    // thing the cursor is on, because "delete" with a cursor on a file and no
    // selection is not an ambiguous request.
    readonly property var picks: {
        const names = root.picked;
        if (names.length === 0)
            return root.current ? [root.current] : [];
        return root.visible.filter(e => names.includes(e.name));
    }

    readonly property var pickedPaths: root.picks.map(e => root.join(root.cwd, e.name))

    // The path as its parts, for a breadcrumb. Root is a crumb of its own, so
    // there is always something to press to get all the way out.
    readonly property var crumbs: {
        const parts = root.cwd.split("/").filter(p => p.length > 0);
        const out = [{name: "/", path: "/"}];
        let path = "";
        for (const part of parts) {
            path += `/${part}`;
            out.push({name: part, path: path});
        }
        return out;
    }

    function join(dir: string, name: string): string {
        return dir === "/" ? `/${name}` : `${dir}/${name}`;
    }

    function parentOf(path: string): string {
        if (path === "/")
            return "/";
        const cut = path.lastIndexOf("/");
        return cut <= 0 ? "/" : path.slice(0, cut);
    }

    // ------------------------------------------------------------ selection

    function isPicked(name: string): bool {
        return root.picked.includes(name);
    }

    // ONE THING, and it becomes the anchor for whatever range comes next.
    function setCursor(index: int): void {
        if (index < 0 || index >= root.visible.length)
            return;
        root.cursor = index;
        root.anchor = index;
        root.picked = [root.visible[index].name];
    }

    // Ctrl-click: add or remove one, leaving the rest alone.
    function togglePick(index: int): void {
        if (index < 0 || index >= root.visible.length)
            return;
        const name = root.visible[index].name;
        root.picked = root.isPicked(name) ? root.picked.filter(n => n !== name) : [...root.picked, name];
        root.cursor = index;
        root.anchor = index;
    }

    // Shift-click: everything between the anchor and here, inclusive.
    function extendTo(index: int): void {
        if (index < 0 || index >= root.visible.length)
            return;
        const from = root.anchor < 0 ? index : root.anchor;
        const lo = Math.min(from, index);
        const hi = Math.max(from, index);
        root.picked = root.visible.slice(lo, hi + 1).map(e => e.name);
        root.cursor = index;
    }

    // A rubber band's result, handed in as indices.
    function pickRange(indices: var, add: bool): void {
        const names = indices.filter(i => i >= 0 && i < root.visible.length).map(i => root.visible[i].name);
        root.picked = add ? [...new Set([...root.picked, ...names])] : names;
    }

    function pickAll(): void {
        root.picked = root.visible.map(e => e.name);
    }

    function clearPicked(): void {
        root.picked = [];
    }

    // ------------------------------------------------------------ the listing

    function refresh(): void {
        if (!root.lister || !root.cwd)
            return;
        list.running = false;
        list.command = [root.lister, root.cwd];
        list.running = true;
    }

    onCwdChanged: {
        root.cursor = -1;
        root.anchor = -1;
        root.picked = [];
        root.search = "";
        root.searching = false;
        root.refresh();
    }

    property Process listing: Process {
        id: list

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const answer = JSON.parse(text);
                    // A LISTING FOR SOMEWHERE ELSE IS THROWN AWAY. Two moves in
                    // quick succession start two of these, and the slower one
                    // finishing last would repaint the grid with the previous
                    // directory's contents under the new directory's name.
                    if (answer.path !== root.cwd)
                        return;
                    root.error = answer.ok ? "" : answer.error;
                    root.entries = answer.ok ? answer.entries : [];

                    // A RE-LIST MUST NOT MOVE THE CURSOR. This runs after every
                    // command the terminal ran, and a cursor that jumped back to
                    // the first row each time would make the grid unusable while
                    // anything was happening in the shell. Only a listing that
                    // has nowhere to put the cursor moves it.
                    root.picked = root.picked.filter(n => root.visible.some(e => e.name === n));
                    if (root.cursor < 0 || root.cursor >= root.visible.length)
                        root.cursor = root.visible.length > 0 ? 0 : -1;
                } catch (e) {
                    root.error = "unreadable listing";
                    root.entries = [];
                }
            }
        }

        onRunningChanged: if (running)
            root.loading = true
    }

    // ------------------------------------------------------------ navigation

    property var back: []
    property var forward: []

    function go(path: string): void {
        if (path === root.cwd)
            return;
        root.back = [...root.back, root.cwd];
        root.forward = [];
        root.wantsCd(path);
    }

    function goBack(): void {
        if (root.back.length === 0)
            return;
        const to = root.back[root.back.length - 1];
        root.back = root.back.slice(0, -1);
        root.forward = [root.cwd, ...root.forward];
        root.wantsCd(to);
    }

    function goForward(): void {
        if (root.forward.length === 0)
            return;
        const to = root.forward[0];
        root.forward = root.forward.slice(1);
        root.back = [...root.back, root.cwd];
        root.wantsCd(to);
    }
}
