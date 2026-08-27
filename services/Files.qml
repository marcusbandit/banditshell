pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../components/vt.js" as Vt
import "../components/base64.js" as B64

// THE FILE BROWSER'S WHOLE MIND: where it is, what is there, and the shell
// session it is having.
//
// A singleton for the same reason Settings is one. The browser is a real window,
// there is exactly one of it, and the thing inside it that must not be rebuilt
// is the terminal: a shell session with a directory, an environment and a
// history in it is not a widget's state, it is a conversation, and a panel that
// is toggled shut and opened again must find the same one still going.
//
// THE SHELL OWNS THE DIRECTORY, and that is the central decision here. Clicking
// a folder does not set a path and then tell the terminal about it; it types
// `cd` into the shell, and the browser moves when the shell reports that it
// moved (src/bs-pty.c reads that off the kernel). So there is exactly one answer
// to "where am I" and the two halves of the window cannot drift apart, which is
// the failure every file-manager-with-a-terminal has: two ideas of the current
// directory that agree until the moment one of them is used.
//
// It also means `cd` typed by hand, `z`, an alias, a script that changes
// directory, and a folder clicked in the grid are all the SAME event as far as
// this file is concerned. None of them is a special case, and nothing had to be
// taught about zsh's jump plugins for them to work.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? "/home"
    // WHERE THE COMPILED HELPERS ARE, asked of Quickshell rather than guessed
    // from $HOME. `shellDir` is the directory this shell was loaded from, so a
    // checkout somewhere other than ~/banditshell finds its own binaries, and a
    // preview instance run out of the same tree finds them too.
    //
    // A FUNCTION, NOT A PROPERTY, and that is not a style preference - it is a
    // bug that took a while to see. A Process's `command` is a binding, and a
    // binding is evaluated when the object is CONSTRUCTED: during this
    // singleton's own construction, before the property bindings above it have
    // necessarily run. It read an empty string, built "/bs-ls", and then never
    // re-evaluated, because `Quickshell.shellDir` is declared constant and so
    // emits no change signal for the binding to hear. The property was correct
    // by the time anything looked at it and the command was wrong forever.
    //
    // A function has no such moment: it answers when it is called, and every
    // caller below calls it as it starts the process.
    function helper(name: string): string {
        return `${Quickshell.shellDir}/bin/${name}`;
    }

    // WHERE THE BROWSER IS. Written only by the pty's report, never by the UI:
    // see the header. `pending` is the one exception's escape hatch - the
    // directory asked for before the shell was running to be asked.
    property string cwd: root.home
    property string pending: ""

    property var entries: []
    property bool loading: false
    // Why a directory is empty, when it is not empty. A listing that failed and
    // a listing with nothing in it look identical on screen and mean completely
    // different things.
    property string error: ""

    // WHICH PANEL HAS THE KEYBOARD: "grid", "preview" or "terminal". One at a
    // time, and every key in the window is routed by it.
    property string focus: "grid"
    property bool terminalOpen: false
    property bool previewOpen: true

    // WHERE THE KEYBOARD IS, as an index into `visible`.
    property int cursor: -1

    // WHAT IS SELECTED, as NAMES rather than indices.
    //
    // The listing is retaken whenever anything might have changed it (see
    // restat), and an index into the previous listing is a different file in the
    // next one - which is how a multi-file delete ends up deleting the wrong
    // multiple files. A name survives a re-list, and one that has genuinely gone
    // simply stops matching.
    property var picked: []

    // Where a range starts. Shift-click extends from here, not from the cursor,
    // so shift-clicking twice re-picks the range rather than growing it by
    // whatever the last click happened to leave behind.
    property int anchor: -1

    property string search: ""
    property bool searching: false

    readonly property bool showHidden: Config.values.files.hidden
    readonly property string sort: Config.values.files.sort

    // WHICH SHAPE THE FILES ARE DRAWN IN: "icons" or "list". Remembered, because
    // it is a preference about the folder you are in as much as about the
    // window, and having to set it again every time is what makes people stop
    // using the one they prefer.
    readonly property string view: Config.values.files.view

    function toggleView(): void {
        Config.set("files.view", root.view === "list" ? "icons" : "list");
    }

    // THE KEYMAPS, straight off Config rather than through Appearance: a chord
    // is a preference, not a design token. See the note in Appearance's sizes.
    readonly property var chords: Config.values.files.keys
    readonly property var gridKeys: Config.values.files.grid

    // The window's own state, in the shape SettingsFloat's is: the CLI and the
    // compositor both need to reach it from outside any window.
    readonly property string windowTitle: "banditshell-files"
    property bool windowOpen: false

    // ------------------------------------------------------------ the listing

    // WHAT IS ACTUALLY DRAWN: the entries, filtered and ordered. Kept here
    // rather than in the grid because the terminal panel's `/` search and the
    // grid's own arrow keys index into the SAME list, and two copies of "which
    // row is third" is the bug that puts the selection on the wrong file.
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

    function join(dir: string, name: string): string {
        return dir === "/" ? `/${name}` : `${dir}/${name}`;
    }

    function parentOf(path: string): string {
        if (path === "/")
            return "/";
        const cut = path.lastIndexOf("/");
        return cut <= 0 ? "/" : path.slice(0, cut);
    }

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

    function refresh(): void {
        lister.running = false;
        lister.command = [root.helper("bs-ls"), root.cwd];
        lister.running = true;
    }

    onCwdChanged: {
        root.cursor = -1;
        root.anchor = -1;
        root.picked = [];
        root.search = "";
        root.searching = false;
        root.refresh();
    }

    Process {
        id: lister

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const answer = JSON.parse(text);
                    // A LISTING FOR SOMEWHERE ELSE IS THROWN AWAY. Two `cd`s in
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

    // WHETHER THE HELPERS ARE THERE AT ALL. They are build output and are not
    // committed (see .gitignore), so the first run after a clone has none, and
    // "the grid is empty" is a terrible way to say "run `banditshell build`".
    property bool helpersMissing: false

    Process {
        id: probe

        onExited: (code, status) => {
            root.helpersMissing = code !== 0;
            if (!root.helpersMissing)
                root.refresh();
        }
    }

    // WHETHER THE HELPERS ARE THERE, asked ONCE and on the first open rather
    // than at startup. The browser is one window among the shell's surfaces and
    // most sessions never ask for it; spending a process at boot to find out
    // whether a binary exists, for a window that may never be shown, is the
    // eager work DESIGN.md section 2.1 is about.
    //
    // `test -x` rather than trying to run the helper and watching it fail:
    // failing to START is not an exit code, it is a warning on the log and a
    // process that never reports anything, so "missing" and "returned nothing"
    // would be the same event.
    function checkHelpers(): void {
        probe.command = ["test", "-x", root.helper("bs-ls")];
        probe.running = true;
    }

    Connections {
        target: root

        function onWindowOpenChanged(): void {
            if (root.windowOpen && root.entries.length === 0)
                root.checkHelpers();
        }
    }

    // ------------------------------------------------------------ formatting

    // HOW A NUMBER IS WRITTEN, once, for the same reason arithmetic is written
    // once in Calc.qml: the grid, the preview panel and anything added later are
    // all answering the same question, and the one thing they must not do is
    // give a file two different sizes.
    //
    // Powers of 1024 with the units they actually go with. Computed by exponent
    // rather than by a ladder of if-statements, so the list of units IS the
    // range and there is no branch to forget.
    function humanSize(bytes: real): string {
        if (bytes < 1024)
            return `${bytes} B`;

        const units = ["kB", "MB", "GB", "TB", "PB"];
        const step = Math.min(units.length, Math.floor(Math.log(bytes) / Math.log(1024)));
        const value = bytes / Math.pow(1024, step);
        // One decimal below ten, none above: "9.4 MB" carries information and
        // "947.3 MB" carries a digit nobody reads.
        return `${value < 10 ? value.toFixed(1) : Math.round(value)} ${units[step - 1]}`;
    }

    // WHEN, at the resolution that is actually useful. Today is a clock, this
    // year is a date without one, and anything older is a year: the point of a
    // timestamp in a file list is telling recent things from old ones, and a
    // full date on every row buries that in digits.
    function humanTime(epoch: real): string {
        const when = new Date(epoch * 1000);
        const now = new Date();

        if (when.toDateString() === now.toDateString())
            return Qt.formatTime(when, "HH:mm");
        if (when.getFullYear() === now.getFullYear())
            return Qt.formatDate(when, "d MMM");
        return Qt.formatDate(when, "MMM yyyy");
    }

    // The mode as the nine characters everybody already reads. Built from the
    // bits rather than looked up, which is nine lines shorter than the table and
    // cannot disagree with itself.
    function humanMode(mode: int): string {
        const letters = "rwx";
        let out = "";
        for (let bit = 8; bit >= 0; bit--)
            out += (mode >> bit) & 1 ? letters.charAt((8 - bit) % 3) : "-";
        return out;
    }

    // A position in a track. Hours only when there are hours, because a
    // three-minute song does not need to be told it is not three hours long.
    function humanDuration(ms: real): string {
        const total = Math.max(0, Math.round(ms / 1000));
        const seconds = String(total % 60).padStart(2, "0");
        const minutes = Math.floor(total / 60) % 60;
        const hours = Math.floor(total / 3600);
        return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")}:${seconds}` : `${minutes}:${seconds}`;
    }
    // ------------------------------------------------------------ the shell

    // The emulator. Made once, lives as long as the shell does, and is handed to
    // whatever view is currently drawing it.
    property var term: null
    property int revision: 0

    // Whether the shell and the browser have agreed on a directory yet. See
    // frame()'s handling of the first report.
    property bool synced: false

    // WHICH SHELL IT IS, and WHETHER IT IS BUSY. Both reported by the helper;
    // see src/bs-pty.c for how it works out the second one.
    property string shellName: ""
    property bool shellBusy: false

    // The browser has moved somewhere the shell has not been told about, because
    // it was busy when we went. Its next directory report is therefore STALE and
    // must not drag the grid back; it gets a `cd` the moment it is free instead.
    property bool desynced: false

    // WHERE WE HAVE JUST ASKED THE SHELL TO GO, while it is on its way.
    //
    // This is what makes clicking a folder instant. The honest sequence - type
    // `cd`, wait for the shell to run it, wait for the helper's next poll to
    // notice, then list - is up to a third of a second of nothing happening
    // after a double click, and it FEELS like the third of a second it is.
    //
    // So the grid moves at once and the shell catches up behind it. The report
    // that then arrives says the OLD directory, and would drag the browser back
    // if it were believed; this is how it is recognised and ignored. The timer
    // is the other half: a `cd` that FAILED (no permission, gone) never sends
    // the expected report at all, and after it expires the shell's word is final
    // again, which puts the browser back where the shell really is.
    property string expecting: ""

    Timer {
        id: expiry

        interval: 1500
        onTriggered: root.expecting = ""
    }

    function ensureTerminal(): void {
        if (root.term)
            return;

        pty.command = [root.helper("bs-pty"), "80", String(Appearance.sizes.filesTerminalRows)];
        // Where the shell is born. Silent and exact when it is honoured; under
        // tmux it is not, because attaching to a session inherits that session's
        // directory instead, which is what the first-report handshake is for.
        pty.workingDirectory = root.cwd;
        root.synced = false;
        root.term = Vt.create(80, Appearance.sizes.filesTerminalRows, {
            palette: Appearance.colour.terminalPalette,
            scrollback: Appearance.sizes.filesScrollback,
            foreground: String(Appearance.colour.text),
            background: String(Appearance.colour.surfaceSolid)
        });
        pty.running = true;
    }

    // TYPE INTO THE SHELL.
    //
    // Takes text and does the encoding here, so nothing above this line has to
    // think about the wire. It matters more than it looks: a filename with an
    // accent in it is one character to QML and two bytes to a shell, and a
    // caller that forgot would move a file whose name is not the one on screen.
    // Escape sequences are ASCII, so the same path is a no-op for them.
    function send(text: string): void {
        if (!pty.running)
            return;
        pty.write(`i ${B64.encode(B64.utf8(text))}\n`);
    }

    // RUN A COMMAND AS IF IT HAD BEEN TYPED, which is what a click on a folder
    // and a file dropped on another folder both do.
    //
    // Through the shell WHEN THERE IS ONE, and that is a deliberate trade: it is
    // slower, and it puts the command in the history where it can be read,
    // repeated, or reversed by hand. A move that happens invisibly is a move you
    // cannot check.
    //
    // AND DIRECTLY WHEN THERE IS NOT. Starting a shell in order to run one `mv`
    // is a strange amount of machinery for the job, and it is a race as well:
    // Process.running does not go true until the child is actually up, so the
    // obvious version - start the shell, then type into it - typed into a
    // process that did not exist yet and the move was silently dropped. Which is
    // exactly what happened, on the first drag that ever landed.
    function run(command: string): void {
        // NOT INTO A RUNNING PROGRAM. Typing `mv` at a prompt uses the shell;
        // typing it into an open vim corrupts a file, and from outside the two
        // look identical unless somebody asks. So when the shell is busy the
        // command is run beside it instead of through it: it loses its place in
        // the history, which is a smaller loss than the alternative.
        if (!pty.running || root.shellBusy) {
            runner.exec(["sh", "-c", `cd ${root.quote(root.cwd)} && ${command}`]);
            root.restat();
            return;
        }

        root.send(root.clearLine() + `${command}\r`);
        root.restat();
    }

    // WHAT TO SEND BEFORE A GENERATED COMMAND, so it does not land on top of
    // something half-typed.
    //
    // Without this, typing `swsw` and then double-clicking a folder produced
    // `swswcd 'folder'` and an error - the browser was appending to a line it
    // could not see.
    //
    // zsh gets PUSH-LINE, which is the good answer: the half-typed line is set
    // aside and comes back on the prompt after ours has run, so navigating in
    // the middle of composing a command costs nothing at all. Anything else gets
    // "go to the end and kill backwards", which clears the line in both bash and
    // zsh whatever mode they are in, and leaves the text in the kill ring where
    // Ctrl+Y can still reach it.
    function clearLine(): string {
        return root.shellName === "zsh" ? "\x1bq" : "\x05\x15";
    }

    Process {
        id: runner
    }

    // LOOK AGAIN, shortly.
    //
    // Nothing tells this window that a directory changed: there is no watcher,
    // and the shell that just moved a file has no way to say so. So the listing
    // is retaken a moment after anything that might have changed it, and the
    // delay is what makes it one listing rather than one per keystroke of a
    // command still being typed.
    //
    // It is also why the terminal's own output restarts it (see frame()): a `rm`
    // typed by hand, a `git checkout`, a build that drops files in the directory
    // you are looking at - none of those come through this file at all, and all
    // of them should move the grid.
    function restat(): void {
        settle.restart();
    }

    Timer {
        id: settle

        interval: 400

        onTriggered: root.refresh()
    }

    function cd(path: string): void {
        // BUSY MEANS THE BROWSER GOES ON ITS OWN. Navigating should never be
        // refused because something is running in the panel below, and the one
        // place `cwd` may be written by the interface is when there is nobody to
        // ask. The shell is told where we went as soon as it is listening again.
        if (pty.running && root.shellBusy) {
            root.desynced = true;
            root.cwd = path;
            return;
        }

        if (!pty.running) {
            // Before the shell exists there is nobody to ask, so the browser
            // moves on its own and hands the destination over when the session
            // starts. The alternative is a browser that cannot navigate until
            // its terminal has been opened once, which is a strange thing to
            // explain to somebody who never wanted the terminal.
            root.pending = path;
            root.cwd = path;
            return;
        }

        // OPTIMISTIC: the grid moves now, the shell follows. See `expecting`.
        root.expecting = path;
        expiry.restart();
        root.cwd = path;
        root.run(`cd ${root.quote(path)}`);
    }

    // A path as one shell word. Single quotes take everything literally, which
    // leaves exactly one character to handle - the single quote itself - and the
    // usual trick handles it: close, escape one, reopen.
    function quote(path: string): string {
        return `'${path.replace(/'/g, "'\\''")}'`;
    }

    function move(from: string, to: string): void {
        root.run(`mv -i -- ${root.quote(from)} ${root.quote(to)}`);
    }

    Process {
        id: pty

        // The command is set in ensureTerminal, not here: see the note over
        // helper() for why a path in a `command` binding is a path frozen at
        // construction.
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.frame(line)
        }
    }

    // One frame off the helper. The protocol is in src/bs-pty.c's header.
    function frame(line: string): void {
        const kind = line.charAt(0);
        const body = line.slice(2);

        if (kind === "o") {
            root.term.write(B64.decode(body));
            root.revision = root.term.revision;
            // Anything the shell prints might be the tail of something that
            // changed this directory. See restat().
            root.restat();

            // ANSWERS THE SHELL IS WAITING FOR. A cursor-position report or a
            // device attributes query is asked mid-draw and blocked on, so an
            // emulator that collects replies and never sends them is an
            // emulator that hangs the first program to ask one.
            const reply = root.term.takeReply();
            if (reply)
                root.send(reply);
            return;
        }

        if (kind === "s") {
            root.shellName = B64.decode(body);
            return;
        }

        if (kind === "b") {
            const busy = body.charAt(0) === "1";
            root.shellBusy = busy;

            // Free again, and behind: catch it up rather than being dragged back
            // by the directory it never left.
            if (!busy && root.desynced) {
                root.desynced = false;
                root.run(`cd ${root.quote(root.cwd)}`);
            }
            return;
        }

        if (kind === "c") {
            const path = B64.decode(body);
            if (!path)
                return;

            // A report from a shell that has not been told where we went is a
            // report about the past.
            if (root.desynced)
                return;

            // Nor is one from a shell still on its way to where we already are.
            if (root.expecting) {
                if (path === root.expecting) {
                    root.expecting = "";
                    expiry.stop();
                }
                return;
            }

            // THE FIRST REPORT GOES THE OTHER WAY. Every report after this one
            // moves the browser to the shell; this one moves the SHELL to the
            // browser, because at birth it is the browser that knows where the
            // user is and the shell that has just been started somewhere.
            //
            // Without it, opening the terminal for the first time yanked the
            // grid to wherever the shell happened to land - which under a
            // .zshrc that attaches to an existing tmux session is not even the
            // directory the process was started in, it is wherever that session
            // was last left.
            if (!root.synced) {
                root.synced = true;
                if (path !== root.cwd) {
                    root.run(`cd ${root.quote(root.cwd)}`);
                    return;
                }
            }

            // The shell has moved. This is the ONLY writer of `cwd` once the
            // session is up, which is what keeps the two halves of the window
            // from ever disagreeing.
            if (path !== root.cwd)
                root.cwd = path;
            return;
        }

        if (kind === "x") {
            // The shell exited - `exit` typed, or a crash. The session is over
            // and the next thing that needs one starts a fresh shell rather than
            // finding a dead panel.
            root.term = null;
            root.terminalOpen = false;
            root.synced = false;
            pty.running = false;
        }
    }

    function resizeTerminal(cols: int, rows: int): void {
        if (!root.term || cols < 1 || rows < 1)
            return;
        if (cols === root.term.cols && rows === root.term.rows)
            return;
        root.term.resize(cols, rows);
        root.revision = root.term.revision;
        if (pty.running)
            pty.write(`r ${cols} ${rows}\n`);
    }

    // ------------------------------------------------------------ doing things

    // Every one of these goes through run(), which types it into the shell when
    // there is one. That is the whole reason a file manager built on a terminal
    // is worth having: `mkdir`, `mv` and `rm` are not hidden behind a menu that
    // did something to your disk and told you nothing - they are in the history,
    // where you can read what happened, run it again, or undo it by hand.

    function makeFolder(name: string): void {
        if (name)
            root.run(`mkdir -p -- ${root.quote(root.join(root.cwd, name))}`);
    }

    function makeFile(name: string): void {
        if (name)
            root.run(`touch -- ${root.quote(root.join(root.cwd, name))}`);
    }

    function renameTo(path: string, name: string): void {
        if (!path || !name)
            return;
        const to = root.join(root.parentOf(path), name);
        if (to !== path)
            root.run(`mv -i -- ${root.quote(path)} ${root.quote(to)}`);
    }

    // TO THE TRASH, not to /dev/null. `gio trash` puts it where every desktop
    // agrees to look for it, so a mistake costs a trip to the trash rather than
    // a backup. Permanent deletion is a separate verb below, and the interface
    // asks first.
    function trash(paths: var): void {
        if (paths.length > 0)
            root.run(`gio trash -- ${paths.map(root.quote).join(" ")}`);
    }

    function deleteForever(paths: var): void {
        if (paths.length > 0)
            root.run(`rm -rf -- ${paths.map(root.quote).join(" ")}`);
    }

    function copyInto(paths: var, dir: string): void {
        if (paths.length > 0)
            root.run(`cp -ri -- ${paths.map(root.quote).join(" ")} ${root.quote(dir)}`);
    }

    function moveInto(paths: var, dir: string): void {
        if (paths.length > 0)
            root.run(`mv -i -- ${paths.map(root.quote).join(" ")} ${root.quote(dir)}`);
    }

    // THE BROWSER'S OWN CLIPBOARD, which is not the system one.
    //
    // Copying a FILE and copying its PATH are different requests, and the second
    // is the one wl-copy is for (see copyText below). This holds what a paste
    // will act on, and whether the paste should leave the original behind.
    property var clipboard: []
    property bool clipboardCut: false

    function clip(paths: var, cut: bool): void {
        root.clipboard = paths;
        root.clipboardCut = cut;
    }

    function paste(): void {
        if (root.clipboard.length === 0)
            return;
        if (root.clipboardCut) {
            root.moveInto(root.clipboard, root.cwd);
            // A cut is spent once. Pasting it twice would move what is no longer
            // there and fail on the second go for a reason nobody would guess.
            root.clipboard = [];
        } else {
            root.copyInto(root.clipboard, root.cwd);
        }
    }

    // The system clipboard, for text: a path, or a list of them.
    function copyText(text: string): void {
        copier.exec(["wl-copy", "--", text]);
    }

    Process {
        id: copier
    }

    function openWith(path: string): void {
        opener.exec(["xdg-open", path]);
    }

    // ------------------------------------------------------------ navigation

    property var back: []
    property var forward: []

    function go(path: string): void {
        if (path === root.cwd)
            return;
        root.back = [...root.back, root.cwd];
        root.forward = [];
        root.cd(path);
    }

    function goBack(): void {
        if (root.back.length === 0)
            return;
        const to = root.back[root.back.length - 1];
        root.back = root.back.slice(0, -1);
        root.forward = [root.cwd, ...root.forward];
        root.cd(to);
    }

    function goForward(): void {
        if (root.forward.length === 0)
            return;
        const to = root.forward[0];
        root.forward = root.forward.slice(1);
        root.back = [...root.back, root.cwd];
        root.cd(to);
    }

    function open(entry: var): void {
        if (!entry)
            return;
        const path = root.join(root.cwd, entry.name);
        if (entry.kind === "dir")
            root.go(path);
        else
            opener.exec(["xdg-open", path]);
    }

    Process {
        id: opener
    }

    // ------------------------------------------------------------ the window

    function show(path: string): void {
        if (path)
            root.cd(path);
        root.windowOpen = true;
    }

    function hide(): void {
        root.windowOpen = false;
    }

    function toggle(path: string): void {
        if (root.windowOpen)
            root.hide();
        else
            root.show(path);
    }

    // HOW THE COMPOSITOR SHOULD FRAME IT.
    //
    // Without this the browser opens TILED, because that is what Hyprland does
    // with a new window, and a file grid squeezed into whatever the layout had
    // left is not the window that was designed. `implicitWidth` is a hint the
    // compositor is free to ignore, and it does.
    //
    // Same machinery as the settings window (services/Settings.qml), including
    // the two dialects: the Lua parser takes a whole named spec at once and
    // refuses `keyword`, the legacy one has no `eval`. NOT centred, for the
    // reason Settings is not: the window is kept alive and re-shown, so the
    // compositor re-applies the rules on every open, and a window that jumped
    // back to the middle of the screen each time you toggled it would be
    // throwing away the place you put it.
    readonly property var rules: [
        {
            lua: "float = true",
            legacy: "float on"
        },
        {
            lua: `size = { ${Appearance.sizes.filesWidth}, ${Appearance.sizes.filesHeight} }`,
            legacy: `size ${Appearance.sizes.filesWidth} ${Appearance.sizes.filesHeight}`
        },
        {
            lua: "no_anim = true",
            legacy: "no_anim on"
        }
    ]

    function installRules(): void {
        // Not before the compositor has said which language it speaks: `lua`
        // reads false while the question is still in flight, and false is also a
        // real answer. See Hypr.parserKnown.
        if (!Compositor.isHyprland || !Hypr.parserKnown)
            return;

        const title = `^(${root.windowTitle})$`;

        if (Hypr.lua) {
            ruler.exec(["hyprctl", "eval", `hl.window_rule({ name = "${root.windowTitle}", match = { title = "${title}" }, ${root.rules.map(r => r.lua).join(", ")} })`]);
            return;
        }

        ruler.exec(["hyprctl", "--batch", root.rules.map(r => `keyword windowrule ${r.legacy}, match:title ${title}`).join(" ; ")]);
    }

    Process {
        id: ruler
    }

    Connections {
        target: Hypr

        // A compositor reload drops every rule that was set with hyprctl, so
        // they go back on afterwards.
        function onConfigReloaded(): void {
            root.installRules();
        }

        // The compositor has just said which language it speaks, which is the
        // last thing the rules were waiting for.
        function onParserKnownChanged(): void {
            root.installRules();
        }
    }

    Component.onCompleted: root.installRules()

    // WHAT A CHORD DOES. One place, because the keymap is data and every panel
    // routes through here rather than each having its own opinion.
    function act(action: string): bool {
        if (action.startsWith("focus:")) {
            const to = action.slice(6);
            if (to === "terminal")
                root.ensureTerminal();
            if (to !== "terminal" || root.terminalOpen)
                root.focus = to;
            return true;
        }

        switch (action) {
        case "terminal":
            root.terminalOpen = !root.terminalOpen;
            if (root.terminalOpen) {
                root.ensureTerminal();
                // OPENING IT FOCUSES IT. A terminal you have just asked for and
                // then have to click on is a terminal that has wasted the
                // keystroke you opened it with.
                root.focus = "terminal";
            } else if (root.focus === "terminal") {
                root.focus = "grid";
            }
            return true;
        case "preview":
            root.previewOpen = !root.previewOpen;
            if (!root.previewOpen && root.focus === "preview")
                root.focus = "grid";
            return true;
        case "hidden":
            Config.set("files.hidden", !root.showHidden);
            return true;
        case "back":
            root.goBack();
            return true;
        case "forward":
            root.goForward();
            return true;
        case "parent":
            root.go(root.parentOf(root.cwd));
            return true;
        case "home":
            root.go(root.home);
            return true;
        }

        return false;
    }
}
