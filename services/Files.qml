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

    property int selected: -1
    property string search: ""
    property bool searching: false

    readonly property bool showHidden: Config.values.files.hidden
    readonly property string sort: Config.values.files.sort

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

    readonly property var current: root.selected >= 0 && root.selected < root.visible.length ? root.visible[root.selected] : null
    readonly property string currentPath: root.current ? root.join(root.cwd, root.current.name) : ""

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
        root.selected = -1;
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
                    root.selected = root.visible.length > 0 ? 0 : -1;
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
        if (pty.running) {
            root.send(`${command}\r`);
            root.restat();
            return;
        }

        runner.exec(["sh", "-c", command]);
        root.restat();
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

        if (kind === "c") {
            const path = B64.decode(body);
            if (!path)
                return;

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
