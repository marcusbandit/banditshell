pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../config/files-zoom.js" as FilesZoom
import "../components/vt.js" as TerminalEmulator
import "../components/base64.js" as Base64
import "quoting.js" as Quoting
import "files-order.js" as FilesOrder
import "files-conflicts.js" as Conflicts
import "files-find.js" as Find
import "files-listing.js" as Listing
import "files-trash.js" as Trash

Singleton {
    id: root

    readonly property string home: System.home

    function helper(name: string): string {
        return `${Quickshell.shellDir}/bin/${name}`;
    }

    property string cwd: root.home

    readonly property string trashHome: `${Quickshell.env("XDG_DATA_HOME") || root.home + "/.local/share"}/Trash`
    readonly property string trashFiles: `${root.trashHome}/files`
    readonly property bool trashTop: root.cwd === root.trashFiles
    readonly property bool inTrash: Trash.within(root.cwd, root.trashFiles)

    property var entries: []
    property string error: ""

    property string cursorName: ""
    property var picked: []
    property string anchorName: ""

    property string search: ""
    property bool searching: false

    readonly property var visible: {
        const all = root.entries.filter(e => root.showHidden || !e.hidden);
        const query = root.search.trim().toLowerCase();
        const matched = query === "" ? all : all.filter(e => e.name.toLowerCase().includes(query));

        const how = root.trashTop ? FilesOrder.trashOrder(root.sort, root.reversed) : {key: root.sort, reversed: root.reversed};
        const order = list => FilesOrder.ordered(list, how.key, how.reversed);
        return FilesFind.active ? Find.grouped(matched, FilesFind.results, root.cwd, order, root.sort === "mtime") : order(matched);
    }

    onSearchChanged: FilesFind.ask(root.inTrash ? "" : root.search, root.cwd, root.showHidden)
    onShowHiddenChanged: FilesFind.ask(root.inTrash ? "" : root.search, root.cwd, root.showHidden)

    function keyOf(entry: var): string {
        return entry.key ?? entry.name;
    }

    function pathOf(entry: var): string {
        return entry.key ?? root.join(root.cwd, entry.name);
    }

    function indexOf(name: string): int {
        return root.visible.findIndex(e => root.keyOf(e) === name);
    }

    readonly property int cursor: {
        const at = root.indexOf(root.cursorName);
        return at >= 0 ? at : root.visible.length > 0 ? 0 : -1;
    }

    readonly property var current: root.cursor >= 0 ? root.visible[root.cursor] : null
    readonly property string currentPath: root.current ? root.pathOf(root.current) : ""

    readonly property var picks: {
        const names = root.picked;
        if (names.length === 0)
            return root.current ? [root.current] : [];
        return root.visible.filter(e => names.includes(root.keyOf(e)));
    }

    readonly property var pickedPaths: root.picks.map(e => root.pathOf(e))

    readonly property var crumbs: {
        const inside = root.inTrash;
        const parts = (inside ? root.cwd.slice(root.trashFiles.length) : root.cwd).split("/").filter(p => p.length > 0);
        const out = [inside ? {name: "Trash", path: root.trashFiles} : {name: "/", path: "/"}];
        let path = inside ? root.trashFiles : "";
        for (const part of parts) {
            path += `/${part}`;
            out.push({name: part, path: path});
        }
        return out;
    }

    function setSearch(text: string): void {
        root.search = text;
    }

    function setSearching(on: bool): void {
        root.searching = on;
    }

    function isPicked(name: string): bool {
        return root.picked.includes(name);
    }

    function setCursor(index: int): void {
        if (index < 0 || index >= root.visible.length)
            return;
        const name = root.keyOf(root.visible[index]);
        root.cursorName = name;
        root.anchorName = name;
        root.picked = [name];
    }

    function togglePick(index: int): void {
        if (index < 0 || index >= root.visible.length)
            return;
        const name = root.keyOf(root.visible[index]);
        root.picked = root.isPicked(name) ? root.picked.filter(n => n !== name) : [...root.picked, name];
        root.cursorName = name;
        root.anchorName = name;
    }

    function extendTo(index: int): void {
        if (index < 0 || index >= root.visible.length)
            return;
        const anchor = root.indexOf(root.anchorName);
        const from = anchor < 0 ? index : anchor;
        const lo = Math.min(from, index);
        const hi = Math.max(from, index);
        const name = root.keyOf(root.visible[index]);
        root.picked = root.visible.slice(lo, hi + 1).map(e => root.keyOf(e));
        root.cursorName = name;
    }

    function pickRange(indices: var, add: bool): void {
        const names = indices.filter(i => i >= 0 && i < root.visible.length).map(i => root.keyOf(root.visible[i]));
        root.picked = add ? [...new Set([...root.picked, ...names])] : names;
    }

    function pickAll(): void {
        root.picked = root.visible.map(e => root.keyOf(e));
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

    property var back: []
    property var forward: []

    function go(path: string): void {
        if (path === root.cwd)
            return;
        const from = root.cwd;
        if (!root.cd(path))
            return;
        root.back = [...root.back, from];
        root.forward = [];
    }

    function goBack(): void {
        if (root.back.length === 0)
            return;
        const from = root.cwd;
        if (!root.cd(root.back[root.back.length - 1]))
            return;
        root.back = root.back.slice(0, -1);
        root.forward = [from, ...root.forward];
    }

    function goForward(): void {
        if (root.forward.length === 0)
            return;
        const from = root.cwd;
        if (!root.cd(root.forward[0]))
            return;
        root.forward = root.forward.slice(1);
        root.back = [...root.back, from];
    }

    function open(entry: var): void {
        if (!entry)
            return;
        const path = root.pathOf(entry);
        if (entry.kind === "dir")
            root.go(path);
        else if (entry.key && !entry.trash)
            root.goTo(path);
        else
            System.openWith(path);
    }

    onCwdChanged: {
        root.cursorName = "";
        root.anchorName = "";
        root.picked = [];
        root.search = "";
        root.searching = false;
        root.refresh();
        root.watch();
        root.remember();
    }

    property int generation: 0
    property var latestListing: null
    property bool listing: false
    property bool listingTrash: false
    property real listingSince: 0
    property bool again: false
    property bool watched: false
    property string lastListing: ""

    function refresh(): void {
        if (!root.cwd)
            return;
        root.generation += 1;
        root.listing = true;
        root.listingTrash = root.cwd === root.trashFiles;
        root.listingSince = Date.now();
        root.again = false;
        root.watched = false;
        if (root.latestListing)
            root.latestListing.running = false;
        root.latestListing = lister.createObject(root, {
            command: root.listingTrash ? Trash.readCommand(root.helper("bs-ls"), root.trashHome, root.mounts) : [root.helper("bs-ls"), root.cwd],
            generation: root.generation,
            running: true
        });
    }

    function take(generation: int, text: string): void {
        if (generation !== root.generation)
            return;
        root.listing = false;
        const again = root.again;
        if (text !== root.lastListing) {
            root.lastListing = text;
            root.adopt(text);
        }
        if (again)
            root.relist();
        if (!root.watcher && !root.error && root.cwd !== root.unwatchable)
            root.watch();
    }

    function adopt(text: string): void {
        const began = Date.now();
        const was = root.cursor;
        try {
            const answer = root.listingTrash ? {
                path: root.cwd,
                ok: true,
                entries: Trash.entries(Trash.parse(text))
            } : JSON.parse(text);

            if (answer.path !== root.cwd)
                return;
            root.error = answer.ok ? "" : answer.error;
            root.entries = answer.ok ? Listing.reuse(root.entries, answer.entries, root.keyOf) : [];
        } catch (e) {
            root.error = "unreadable listing";
            root.entries = [];
        }

        root.picked = root.picked.filter(n => root.indexOf(n) >= 0);
        if (root.cursorName && root.indexOf(root.cursorName) < 0) {
            const at = Math.min(Math.max(was, 0), root.visible.length - 1);
            root.cursorName = at >= 0 ? root.keyOf(root.visible[at]) : "";
        }
        root.landedAt = root.watched ? Date.now() : 0;
        root.cost = Date.now() - began;
    }

    Component {
        id: lister

        Process {
            id: listing

            property int generation: 0

            stdout: StdioCollector {
                onStreamFinished: root.take(listing.generation, text)
            }

            onRunningChanged: if (!listing.running)
                listing.destroy()
        }
    }

    property real landedAt: 0
    property real cost: 0

    Timer {
        id: pace

        onTriggered: root.relist()
    }

    function relist(): void {
        const wait = root.entries.length < 5000 ? 0 : root.landedAt + root.cost * 3 - Date.now();
        if (wait > 0) {
            pace.interval = wait;
            if (!pace.running)
                pace.start();
            return;
        }
        if (root.listing && Date.now() - root.listingSince < 30000)
            root.again = true;
        else
            root.relistNow();
    }

    function relistNow(): void {
        root.refresh();
        root.watched = true;
    }

    property var watcher: null
    property bool watching: false
    property string unwatchable: ""

    function watch(): void {
        pace.stop();
        root.cost = 0;
        const old = root.watcher;
        root.watcher = null;
        root.watching = false;
        if (old) {
            old.running = false;
            old.destroy();
        }
        if (!root.windowOpen)
            root.lastListing = "";
        if (!root.windowOpen || root.helpersMissing || !root.cwd)
            return;
        root.watcher = folderWatch.createObject(root, {
            command: [root.helper("bs-ls"), "--watch", root.cwd],
            running: true
        });
    }

    function heard(from: var, line: string): void {
        if (from !== root.watcher)
            return;
        if (line === "ready")
            root.watching = true;
        else if (line === "changed")
            root.relist();
    }

    Component {
        id: folderWatch

        Process {
            id: watcherProcess

            stdinEnabled: true

            stdout: SplitParser {
                onRead: line => root.heard(watcherProcess, line)
            }

            onRunningChanged: {
                if (watcherProcess.running || root.watcher !== watcherProcess)
                    return;
                const was = root.watching;
                root.watcher = null;
                root.watching = false;
                root.unwatchable = was ? "" : root.cwd;
                watcherProcess.destroy();
                if (was)
                    root.relist();
            }
        }
    }

    property string focus: "grid"
    property bool terminalOpen: false
    property bool previewOpen: true

    readonly property bool showHidden: Config.values.files.hidden
    readonly property string sort: Config.values.files.sort
    readonly property bool reversed: Config.values.files.reversed
    readonly property var orderWords: FilesOrder.orderWords(root.sort)
    readonly property var sortWords: FilesOrder.SORT_WORDS
    readonly property string foldersNote: FilesOrder.foldersNote(root.sort)

    readonly property string view: Config.values.files.view
    readonly property string searchView: Config.values.files.searchView
    readonly property bool listed: FilesFind.active ? root.searchView === "list" : root.view === "list"

    readonly property bool markdownRendered: Config.values.files.markdown !== "raw"

    function toggleMarkdown(): void {
        Config.set("files.markdown", root.markdownRendered ? "raw" : "rendered");
    }

    function toggleView(): void {
        if (FilesFind.active)
            Config.set("files.searchView", root.searchView === "list" ? "icons" : "list");
        else
            Config.set("files.view", root.view === "list" ? "icons" : "list");
    }

    property bool sidebarOpen: true

    property int sidebarWidth: Appearance.sizes.filesSidebar
    property int previewWidth: Appearance.sizes.filesPreview

    function commitWidths(): void {
        if (root.sidebarWidth !== Appearance.sizes.filesSidebar)
            Config.set("files.sidebar", root.sidebarWidth);
        if (root.previewWidth !== Appearance.sizes.filesPreview)
            Config.set("files.preview", root.previewWidth);
    }

    readonly property real magnification: Appearance.sizes.filesZoom
    readonly property real smallest: FilesZoom.SMALLEST
    readonly property real largest: FilesZoom.LARGEST

    function zoomed(size: real): int {
        return Math.round(size * root.magnification);
    }

    function zoom(step: real): void {
        const now = root.magnification;
        const next = step === 0 ? 1 : Math.max(root.smallest, Math.min(root.largest, Math.round((now + step) * 20) / 20));
        if (next !== now)
            Config.set("files.zoom", next);
    }

    property var places: []

    readonly property var placeSpec: [
        {name: "Home", icon: "home", path: root.home},
        {name: "Desktop", icon: "desktop_windows", path: UserFolders.folders.Desktop},
        {name: "Documents", icon: "description", path: UserFolders.documents},
        {name: "Downloads", icon: "download", path: UserFolders.downloads},
        {name: "Pictures", icon: "image", path: UserFolders.pictures},
        {name: "Music", icon: "music_note", path: UserFolders.folders.Music},
        {name: "Videos", icon: "movie", path: UserFolders.folders.Videos},
        {name: "Root", icon: "hard_drive_2", path: "/"}
    ]

    property var drives: []
    property var mounts: []

    function setDrives(next: var): void {
        const shown = list => JSON.stringify(list.map(d => [d.name, d.path, d.detail, d.icon, d.usage ? [root.humanSize(d.usage.used), root.humanSize(d.usage.size), Math.round(d.usage.fraction * 100)] : null]));
        if (shown(next) !== shown(root.drives))
            root.drives = next;
    }

    onMountsChanged: if (root.trashTop)
        root.refresh()

    function refreshPlaces(): void {
        placer.running = false;
        placer.command = ["sh", "-c", root.placeSpec.map(p => `test -d ${root.quote(p.path)} && echo ${root.quote(p.path)}`).join("; ")];
        placer.running = true;

        mounter.running = false;
        mounter.command = ["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINTS,SIZE,RM,TYPE,FSTYPE"];
        mounter.running = true;
    }

    Process {
        id: placer

        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").filter(l => l.length > 0);
                const next = [...root.placeSpec.filter(p => found.includes(p.path)), {name: "Trash", icon: "delete", path: root.trashFiles}];
                if (JSON.stringify(next) !== JSON.stringify(root.places))
                    root.places = next;
            }
        }
    }

    Process {
        id: mounter

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const tree = JSON.parse(text).blockdevices ?? [];
                    const out = [];
                    const mounted = [];

                    const walk = (node, removable) => {
                        const rm = removable || node.rm === true || node.rm === "1";

                        for (const where of node.mountpoints ?? []) {
                            if (!where)
                                continue;
                            if (where.startsWith("/") && !mounted.includes(where))
                                mounted.push(where);
                            const volume = where.startsWith("/mnt/") || where.startsWith("/media/") || where.startsWith("/run/media/");
                            if (!rm && !volume)
                                continue;
                            if (out.some(d => d.path === where))
                                continue;

                            out.push({
                                name: node.label || where.split("/").pop() || node.name,
                                path: where,
                                detail: node.size ?? "",
                                icon: rm ? "usb" : "hard_drive"
                            });
                        }

                        for (const child of node.children ?? [])
                            walk(child, rm);
                    };

                    for (const device of tree)
                        walk(device, false);

                    const known = {};
                    for (const d of root.drives)
                        known[d.path] = d.usage ?? null;
                    root.setDrives(out.map(d => Object.assign(d, {usage: known[d.path] ?? null})));
                    if (mounted.join("\n") !== root.mounts.join("\n"))
                        root.mounts = mounted;

                    if (out.length > 0) {
                        usage.running = false;
                        usage.command = ["df", "-P", "-B1", ...out.map(d => d.path)];
                        usage.running = true;
                    }
                } catch (e) {
                    root.drives = [];
                }
            }
        }
    }

    readonly property var chords: Config.values.files.keys
    readonly property var gridKeys: Config.values.files.grid

    readonly property string windowTitle: "banditshell-files"
    property bool windowOpen: false

    Process {
        id: usage

        stdout: StdioCollector {
            onStreamFinished: {
                const filled = {};
                for (const line of text.split("\n").slice(1)) {
                    const parts = line.trim().split(/\s+/);
                    if (parts.length < 6)
                        continue;
                    const where = parts.slice(5).join(" ");
                    const size = parseFloat(parts[1]);
                    const used = parseFloat(parts[2]);
                    if (size > 0)
                        filled[where] = {used: used, size: size, fraction: used / size};
                }

                root.setDrives(root.drives.map(d => Object.assign({}, d, {usage: filled[d.path] ?? null})));
            }
        }
    }

    property bool helpersMissing: false

    Process {
        id: probe

        onExited: (code, status) => {
            root.helpersMissing = code !== 0;
            if (!root.helpersMissing)
                root.refresh();
        }
    }

    function checkHelpers(): void {
        probe.command = ["test", "-x", root.helper("bs-ls")];
        probe.running = true;
    }

    Connections {
        target: root

        function onWindowOpenChanged(): void {
            root.watch();
            if (!root.windowOpen)
                return;
            if (root.entries.length === 0)
                root.checkHelpers();
            else
                root.refresh();

            root.refreshPlaces();
        }
    }

    function humanSize(bytes: real): string {
        if (bytes < 1024)
            return `${bytes} B`;

        const units = ["kB", "MB", "GB", "TB", "PB"];
        const step = Math.min(units.length, Math.floor(Math.log(bytes) / Math.log(1024)));
        const value = bytes / Math.pow(1024, step);

        return `${value < 10 ? value.toFixed(1) : Math.round(value)} ${units[step - 1]}`;
    }

    function humanTime(epoch: real): string {
        return TimeFormat.recent(new Date(epoch * 1000));
    }

    function changedTime(epoch: real): string {
        return TimeFormat.changed(new Date(epoch * 1000));
    }

    function humanMode(mode: int): string {
        const letters = "rwx";
        let out = "";
        for (let bit = 8; bit >= 0; bit--)
            out += (mode >> bit) & 1 ? letters.charAt((8 - bit) % 3) : "-";
        return out;
    }

    function humanDuration(ms: real): string {
        const total = Math.max(0, Math.round(ms / 1000));
        const seconds = String(total % 60).padStart(2, "0");
        const minutes = Math.floor(total / 60) % 60;
        const hours = Math.floor(total / 3600);
        return hours > 0 ? `${hours}:${String(minutes).padStart(2, "0")}:${seconds}` : `${minutes}:${seconds}`;
    }

    property var term: null
    property int revision: 0

    property bool synced: false

    property string shellName: ""

    property string tmuxSession: ""
    property var tmuxWindows: []
    property bool shellBusy: false

    property bool desynced: false

    property string expecting: ""

    Timer {
        id: expiry

        interval: 1500

        onTriggered: root.expecting = ""
    }

    function ensureTerminal(): void {
        if (root.term)
            return;

        pty.command = [root.helper("bs-pty"), "80", String(Config.values.files.terminal.rows)];

        pty.workingDirectory = root.cwd;
        root.synced = false;
        root.term = TerminalEmulator.create(80, Config.values.files.terminal.rows, {
            palette: Appearance.colour.terminalPalette,
            scrollback: Config.values.files.terminal.scrollback,
            foreground: String(Appearance.colour.text),
            background: String(Appearance.colour.surfaceSolid)
        });
        pty.running = true;
    }

    Connections {
        target: Appearance.colour

        function onTerminalPaletteChanged(): void {
            if (!root.term)
                return;
            root.term.palette = Appearance.colour.terminalPalette;
            root.term.touch();
            root.revision = root.term.revision;
        }
    }

    function send(text: string): void {
        if (!pty.running)
            return;
        pty.write(`i ${Base64.encode(Base64.utf8(text))}\n`);
    }

    property string failure: ""

    function typed(paths: var): var {
        const out = [];
        for (const path of paths) {
            const quoted = Quoting.forShell(root.shellName, path);
            if (quoted === null)
                return null;
            out.push(quoted);
        }
        return out;
    }

    function refusal(path: string): string {
        return `cannot type this path into ${root.shellName || "the shell"}: ${Quoting.visible(path)}`;
    }

    function run(words: var, paths: var): void {
        root.failure = "";
        const quoted = pty.running && !root.shellBusy ? root.typed(paths) : null;

        if (quoted === null) {
            root.spawn([...words, ...paths], "");
            return;
        }

        root.send(root.clearLine() + `${[...words, ...quoted].join(" ")}\r`);
        root.restat();
    }

    property int working: 0

    function spawn(command: var, input: string): void {
        job.createObject(root, {
            command: command,
            input: input,
            stdinEnabled: input !== "",
            running: true
        });
    }

    function report(command: var, code: int, complaint: string): void {
        const lines = complaint.split("\n").map(line => line.trim()).filter(line => line.length > 0);
        const said = lines.length === 0 ? `${command[0]} exited with ${code}` : lines.length === 1 ? lines[0] : `${lines[0]} (+${lines.length - 1} more)`;
        root.failure = Quoting.visible(said);
    }

    Component {
        id: job

        Process {
            id: task

            property string input: ""
            property bool begun: false

            stderr: StdioCollector {
                id: complaint
            }

            onStarted: {
                task.begun = true;
                root.working += 1;
                if (task.input !== "") {
                    task.write(task.input);
                    task.stdinEnabled = false;
                }
            }

            onRunningChanged: {
                if (task.running || task.begun)
                    return;
                root.failure = `${task.command[0]} could not be started`;
                task.destroy();
            }

            onExited: (code, status) => {
                root.working -= 1;
                if (code !== 0 || status !== 0)
                    root.report(task.command, code, complaint.text);
                root.restat();
                task.destroy();
            }
        }
    }

    function typeCd(path: string): bool {
        const quoted = root.typed([path]);
        if (quoted === null) {
            root.failure = root.refusal(path);
            return false;
        }
        root.send(root.clearLine() + `cd ${quoted[0]}\r`);
        root.restat();
        return true;
    }

    function clearLine(): string {
        return root.shellName === "zsh" ? "\x1bq" : "\x05\x15";
    }

    function restat(): void {
        settle.restart();
    }

    Timer {
        id: settle

        interval: 400

        onTriggered: root.refresh()
    }

    function cd(path: string): bool {
        if (pty.running && root.typed([path]) === null) {
            root.failure = root.refusal(path);
            return false;
        }
        root.failure = "";

        if (!pty.running) {
            root.cwd = path;
            return true;
        }

        if (root.shellBusy) {
            root.desynced = true;
            root.cwd = path;
            return true;
        }

        root.expecting = path;
        expiry.restart();
        root.cwd = path;
        root.typeCd(path);
        return true;
    }

    function quote(path: string): string {
        return Quoting.posix(path);
    }

    Process {
        id: pty

        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.frame(line)
        }
    }

    function fromUtf8(bytes: string): string {
        try {
            return decodeURIComponent(escape(bytes));
        } catch (e) {
            return bytes;
        }
    }

    function frame(line: string): void {
        const kind = line.charAt(0);
        const body = line.slice(2);

        if (kind === "o") {
            root.term.write(Base64.decode(body));
            root.revision = root.term.revision;

            root.restat();

            const reply = root.term.takeReply();
            if (reply)
                root.send(reply);
            return;
        }

        if (kind === "s") {
            root.shellName = Base64.decode(body);
            return;
        }

        if (kind === "t") {
            root.tmuxSession = root.fromUtf8(Base64.decode(body));
            return;
        }

        if (kind === "w") {
            const rows = root.fromUtf8(Base64.decode(body)).split("\n").filter(l => l.length > 0);
            root.tmuxWindows = rows.map(line => {
                const parts = line.split("\t");
                return {id: parts[0], name: parts[1] ?? "", active: parts[2] === "1"};
            });
            return;
        }

        if (kind === "b") {
            const busy = body.charAt(0) === "1";
            root.shellBusy = busy;

            if (!busy && root.desynced) {
                root.desynced = false;
                root.typeCd(root.cwd);
            }
            return;
        }

        if (kind === "c") {
            const path = root.fromUtf8(Base64.decode(body));
            if (!path)
                return;

            if (root.desynced)
                return;

            if (root.expecting) {
                if (path === root.expecting) {
                    root.expecting = "";
                    expiry.stop();
                }
                return;
            }

            if (!root.synced) {
                root.synced = true;
                if (path !== root.cwd && !root.shellBusy && root.typeCd(root.cwd))
                    return;
            }

            if (path !== root.cwd)
                root.cwd = path;
            return;
        }

        if (kind === "x") {
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

    function makeFolder(name: string): void {
        if (name && !root.inTrash)
            root.run(["mkdir", "-p", "--"], [root.join(root.cwd, name)]);
    }

    function makeFile(name: string): void {
        if (name && !root.inTrash)
            root.run(["touch", "--"], [root.join(root.cwd, name)]);
    }

    function renameRefusal(path: string, name: string): string {
        return Conflicts.renameRefusal(name, path.slice(path.lastIndexOf("/") + 1), root.entries, Conflicts.folderName(root.parentOf(path), root.home));
    }

    function renameTo(path: string, name: string): void {
        if (!path || !name)
            return;
        const to = root.join(root.parentOf(path), name);
        if (to !== path && !Trash.trashed(path, root.trashFiles))
            FilesUndo.renaming(path, to, () => root.run(["mv", "-i", "--"], [path, to]));
    }

    function trash(given: var): void {
        const paths = given.filter(path => !Trash.trashed(path, root.trashFiles));
        if (paths.length === 0)
            return;
        root.run(["gio", "trash", "--"], paths);
        FilesUndo.trashed(paths);
        FilesFind.forget(paths);
    }

    function deleteForever(paths: var): void {
        if (paths.length === 0)
            return;
        const infos = root.entries.filter(e => e.trash && paths.includes(e.key)).map(e => Trash.infoPath(e.trash));
        root.run(["rm", "-rf", "--"], [...paths, ...infos]);
        FilesFind.forget(paths);
    }

    readonly property var trashItems: root.trashTop ? root.entries.filter(e => e.trash).map(e => e.trash) : []

    function emptyTrash(items: var): void {
        for (const command of Trash.emptyCommands(items, root.trashHome))
            root.spawn(command, "");
    }

    function trashFrom(entry: var): var {
        const top = Trash.topOf(entry.trash.dir);
        if (top === null)
            return {origin: root.originPlace(entry), drive: ""};
        const drive = root.drives.find(d => d.path === top);
        return {
            origin: entry.dir ? entry.dir.slice(top.length) || "/" : "",
            drive: drive ? drive.name : top
        };
    }

    function measureTrash(items: var, done: var): void {
        measurer.createObject(root, {
            command: Trash.sizeCommand(),
            input: Trash.sizeInput(items),
            done: done,
            running: true
        });
    }

    Component {
        id: measurer

        Process {
            id: measuring

            property string input: ""
            property var done: null

            stdinEnabled: true

            stdout: StdioCollector {
                onStreamFinished: measuring.done?.(Trash.sizes(text))
            }

            onStarted: {
                measuring.write(measuring.input);
                measuring.stdinEnabled = false;
            }

            onRunningChanged: if (!measuring.running)
                measuring.destroy()
        }
    }

    function copyInto(paths: var, dir: string): void {
        FilesPaste.start(paths, dir, false);
    }

    function placeOf(dir: string): string {
        const place = Find.place(dir, root.home);
        return place === "~" ? "~/" : place;
    }

    function originPlace(entry: var): string {
        return entry && entry.trash && entry.dir ? root.placeOf(entry.dir) : "";
    }

    function restore(entries: var): void {
        FilesUndo.restore(entries.filter(e => e.trash?.path).map(e => e.trash));
    }

    function moveInto(paths: var, dir: string): void {
        if (Trash.within(dir, root.trashFiles))
            return root.trash(paths);
        if (paths.some(path => Trash.trashed(path, root.trashFiles))) {
            root.failure = "Restore takes things out of the trash";
            return;
        }
        FilesPaste.start(paths, dir, true);
        FilesFind.forget(paths);
    }

    property var clipboard: []
    property bool clipboardCut: false

    function clip(paths: var, cut: bool): void {
        if (cut && paths.some(path => Trash.trashed(path, root.trashFiles)))
            return;
        root.clipboard = paths;
        root.clipboardCut = cut;
    }

    function paste(): void {
        if (root.clipboard.length === 0 || root.inTrash)
            return;
        if (root.clipboardCut) {
            const moving = root.clipboard;
            FilesFind.forget(moving);
            FilesPaste.start(moving, root.cwd, true, outcome => {
                if (root.clipboard === moving)
                    root.clipboard = Conflicts.leftover(moving, outcome);
            });
        } else {
            root.copyInto(root.clipboard, root.cwd);
        }
    }

    function copyText(text: string): void {
        root.spawn(["wl-copy"], text);
    }

    function openWith(path: string): void {
        System.openWith(path);
    }

    Connections {
        target: System

        function onRevealRequested(path: string): void {
            root.reveal(path);
        }
    }

    function show(path: string): void {
        const span = root.windowOpen ? null : Trace.begin("files open");
        if (path)
            root.cd(path);
        Trace.step("listed", span);
        root.windowOpen = true;
        Trace.step("shown", span);
    }

    function goTo(path: string): void {
        const name = path.slice(path.lastIndexOf("/") + 1);
        root.go(root.parentOf(path));
        root.cursorName = name;
        root.anchorName = name;
        root.picked = [name];
    }

    function reveal(path: string): void {
        const name = path.slice(path.lastIndexOf("/") + 1);
        root.show(root.parentOf(path));
        root.cursorName = name;
        root.anchorName = name;
        root.picked = [name];
    }

    function hide(): void {
        const span = root.windowOpen ? Trace.begin("files close") : null;
        root.windowOpen = false;
        Trace.step("hidden", span);
    }

    function toggle(path: string): void {
        if (root.windowOpen)
            root.hide();
        else
            root.show(path);
    }

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

        function onConfigReloaded(): void {
            root.installRules();
        }

        function onParserKnownChanged(): void {
            root.installRules();
        }
    }

    function remember(): void {
        Relaunch.keep("files", {
            open: root.windowOpen,
            path: root.cwd
        });
    }

    onWindowOpenChanged: {
        if (!root.windowOpen)
            FilesFind.stop();
        root.remember();
    }

    Component.onCompleted: {
        const was = Relaunch.recall("files");
        if (was?.path)
            root.cwd = was.path;
        root.refresh();
        root.installRules();
        if (was?.open)
            root.show("");
    }

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
        case "sidebar":
            root.sidebarOpen = !root.sidebarOpen;
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
        case "refresh":
            root.refresh();
            return true;
        }

        return false;
    }
}
