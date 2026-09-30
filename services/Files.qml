pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../components/vt.js" as Vt
import "../components/base64.js" as B64

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") ?? "/home"

    function helper(name: string): string {
        return `${Quickshell.shellDir}/bin/${name}`;
    }

    property var panes: []
    property int activePane: 0

    readonly property var pane: root.panes.length > 0 ? root.panes[Math.min(root.activePane, root.panes.length - 1)] : null

    property Component paneMaker: Component {
        FilePane {}
    }

    function addPane(path: string): var {
        const made = root.paneMaker.createObject(root, {
            lister: root.helper("bs-ls"),
            cwd: path || root.home
        });

        made.wantsCd.connect(where => root.cd(where, made));
        root.panes = [...root.panes, made];
        return made;
    }

    property string pending: ""

    readonly property string cwd: root.pane ? root.pane.cwd : root.home
    readonly property var entries: root.pane ? root.pane.entries : []
    readonly property bool loading: root.pane ? root.pane.loading : false
    readonly property string error: root.pane ? root.pane.error : ""
    readonly property var visible: root.pane ? root.pane.visible : []
    readonly property int cursor: root.pane ? root.pane.cursor : -1
    readonly property var picked: root.pane ? root.pane.picked : []
    readonly property var current: root.pane ? root.pane.current : null
    readonly property string currentPath: root.pane ? root.pane.currentPath : ""
    readonly property var picks: root.pane ? root.pane.picks : []
    readonly property var pickedPaths: root.pane ? root.pane.pickedPaths : []
    readonly property var crumbs: root.pane ? root.pane.crumbs : []
    readonly property var back: root.pane ? root.pane.back : []
    readonly property var forward: root.pane ? root.pane.forward : []
    readonly property string search: root.pane ? root.pane.search : ""
    readonly property bool searching: root.pane ? root.pane.searching : false

    function setSearch(text: string): void {
        if (root.pane)
            root.pane.search = text;
    }

    function setSearching(on: bool): void {
        if (root.pane)
            root.pane.searching = on;
    }

    function isPicked(name: string): bool {
        return root.pane ? root.pane.isPicked(name) : false;
    }

    function setCursor(index: int): void {
        root.pane?.setCursor(index);
    }

    function togglePick(index: int): void {
        root.pane?.togglePick(index);
    }

    function extendTo(index: int): void {
        root.pane?.extendTo(index);
    }

    function pickRange(indices: var, add: bool): void {
        root.pane?.pickRange(indices, add);
    }

    function pickAll(): void {
        root.pane?.pickAll();
    }

    function clearPicked(): void {
        root.pane?.clearPicked();
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

    function go(path: string): void {
        root.pane?.go(path);
    }

    function goBack(): void {
        root.pane?.goBack();
    }

    function goForward(): void {
        root.pane?.goForward();
    }

    function open(entry: var): void {
        if (!entry || !root.pane)
            return;
        const path = root.join(root.pane.cwd, entry.name);
        if (entry.kind === "dir")
            root.pane.go(path);
        else
            opener.exec(["xdg-open", path]);
    }

    function refresh(): void {
        for (const p of root.panes)
            p.refresh();
    }

    property string focus: "grid"
    property bool terminalOpen: false
    property bool previewOpen: true

    readonly property bool showHidden: Config.values.files.hidden
    readonly property string sort: Config.values.files.sort

    readonly property string view: Config.values.files.view

    readonly property bool markdownRendered: Config.values.files.markdown !== "raw"

    function toggleMarkdown(): void {
        Config.set("files.markdown", root.markdownRendered ? "raw" : "rendered");
    }

    function toggleView(): void {
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

    function zoom(step: real): void {
        const now = Config.values.files.zoom;
        const next = step === 0 ? 1 : Math.max(0.7, Math.min(2.5, Math.round((now + step) * 20) / 20));
        if (next !== now)
            Config.set("files.zoom", next);
    }

    property var places: []

    readonly property var placeSpec: [
        {name: "Home", icon: "home", path: root.home},
        {name: "Desktop", icon: "desktop_windows", path: `${root.home}/Desktop`},
        {name: "Documents", icon: "description", path: `${root.home}/Documents`},
        {name: "Downloads", icon: "download", path: `${root.home}/Downloads`},
        {name: "Pictures", icon: "image", path: `${root.home}/Pictures`},
        {name: "Music", icon: "music_note", path: `${root.home}/Music`},
        {name: "Videos", icon: "movie", path: `${root.home}/Videos`},
        {name: "Root", icon: "hard_drive_2", path: "/"}
    ]

    property var drives: []

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
                root.places = root.placeSpec.filter(p => found.includes(p.path));
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

                    const walk = (node, removable) => {
                        const rm = removable || node.rm === true || node.rm === "1";

                        for (const where of node.mountpoints ?? []) {

                            if (!where)
                                continue;
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

                    root.drives = out;

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

                root.drives = root.drives.map(d => Object.assign({}, d, {usage: filled[d.path] ?? null}));
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
            if (!root.windowOpen)
                return;
            if (root.entries.length === 0)
                root.checkHelpers();

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
        const when = new Date(epoch * 1000);
        const now = new Date();

        if (when.toDateString() === now.toDateString())
            return Qt.formatTime(when, "HH:mm");
        if (when.getFullYear() === now.getFullYear())
            return Qt.formatDate(when, "d MMM");
        return Qt.formatDate(when, "MMM yyyy");
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

    property var expectingPane: null

    Timer {
        id: expiry

        interval: 1500

        onTriggered: {
            root.expecting = "";
            root.expectingPane = null;
        }
    }

    function ensureTerminal(): void {
        if (root.term)
            return;

        pty.command = [root.helper("bs-pty"), "80", String(Appearance.sizes.filesTerminalRows)];

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

    function send(text: string): void {
        if (!pty.running)
            return;
        pty.write(`i ${B64.encode(B64.utf8(text))}\n`);
    }

    function run(command: string): void {

        if (!pty.running || root.shellBusy) {
            runner.exec(["sh", "-c", `cd ${root.quote(root.cwd)} && ${command}`]);
            root.restat();
            return;
        }

        root.send(root.clearLine() + `${command}\r`);
        root.restat();
    }

    function clearLine(): string {
        return root.shellName === "zsh" ? "\x1bq" : "\x05\x15";
    }

    Process {
        id: runner
    }

    function restat(): void {
        settle.restart();
    }

    Timer {
        id: settle

        interval: 400

        onTriggered: root.refresh()
    }

    function cd(path: string, which: var): void {
        const target = which ?? root.pane;
        if (!target)
            return;

        if (pty.running && root.shellBusy) {
            root.desynced = true;
            target.cwd = path;
            return;
        }

        if (!pty.running) {

            root.pending = path;
            target.cwd = path;
            return;
        }

        root.expecting = path;
        root.expectingPane = target;
        expiry.restart();
        target.cwd = path;
        root.run(`cd ${root.quote(path)}`);
    }

    function quote(path: string): string {
        return `'${path.replace(/'/g, "'\\''")}'`;
    }

    function move(from: string, to: string): void {
        root.run(`mv -i -- ${root.quote(from)} ${root.quote(to)}`);
    }

    Process {
        id: pty

        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.frame(line)
        }
    }

    function frame(line: string): void {
        const kind = line.charAt(0);
        const body = line.slice(2);

        if (kind === "o") {
            root.term.write(B64.decode(body));
            root.revision = root.term.revision;

            root.restat();

            const reply = root.term.takeReply();
            if (reply)
                root.send(reply);
            return;
        }

        if (kind === "s") {
            root.shellName = B64.decode(body);
            return;
        }

        if (kind === "t") {
            root.tmuxSession = B64.decode(body);
            return;
        }

        if (kind === "w") {
            const rows = B64.decode(body).split("\n").filter(l => l.length > 0);
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
                root.run(`cd ${root.quote(root.cwd)}`);
            }
            return;
        }

        if (kind === "c") {
            const path = B64.decode(body);
            if (!path)
                return;

            if (root.desynced)
                return;

            if (root.expecting) {
                if (path === root.expecting) {
                    root.expecting = "";
                    root.expectingPane = null;
                    expiry.stop();
                }
                return;
            }

            if (!root.synced) {
                root.synced = true;
                if (path !== root.cwd) {
                    root.run(`cd ${root.quote(root.cwd)}`);
                    return;
                }
            }

            if (root.pane && path !== root.pane.cwd)
                root.pane.cwd = path;
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

            root.clipboard = [];
        } else {
            root.copyInto(root.clipboard, root.cwd);
        }
    }

    function copyText(text: string): void {
        copier.exec(["wl-copy", "--", text]);
    }

    Process {
        id: copier
    }

    function openWith(path: string): void {
        opener.exec(["xdg-open", path]);
    }

    Process {
        id: opener
    }

    function show(path: string): void {
        if (path)
            root.cd(path, root.pane);
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

    Component.onCompleted: {

        root.addPane(root.home);
        root.installRules();
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
        }

        return false;
    }
}
