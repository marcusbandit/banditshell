pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "projects.js" as Logic

Singleton {
    id: root

    readonly property var settings: Config.values.launcher.powerTools
    readonly property var roots: Logic.listFrom(root.settings.projectFolders, Files.home)
    readonly property int depth: root.settings.projectDepth
    readonly property string skip: root.settings.projectSkip

    readonly property string cachePath: `${Config.cacheDir}/projects.json`
    readonly property string openedPath: `${Config.stateDir}/projects.json`

    property var projects: []
    property var opened: ({})
    property double scannedAt: 0
    property bool openedLoaded: false

    property var editors: []
    readonly property var editor: Logic.editorFor(Quickshell.env("VISUAL"), Quickshell.env("EDITOR"), root.editors)

    readonly property int staleMs: 60000

    onRootsChanged: root.scannedAt = 0
    onDepthChanged: root.scannedAt = 0
    onSkipChanged: root.scannedAt = 0

    function refresh(): void {
        if (scanner.running || Date.now() - root.scannedAt < root.staleMs)
            return;
        scanner.command = Logic.scanCommand(root.roots, root.depth, root.skip);
        scanner.running = true;
    }

    Process {
        id: scanner

        stdout: StdioCollector {
            onStreamFinished: {
                root.projects = Logic.readScan(text);
                root.scannedAt = Date.now();
                cache.setText(JSON.stringify(root.projects) + "\n");
            }
        }
    }

    FileView {
        id: cache

        path: root.cachePath
        printErrors: false
        onLoaded: {
            if (root.scannedAt)
                return;
            try {
                const disk = JSON.parse(cache.text());
                if (Array.isArray(disk))
                    root.projects = disk.filter(p => p && typeof p.path === "string");
            } catch (e) {}
        }
    }

    FileView {
        id: openedStore

        path: root.openedPath
        printErrors: false
        onLoaded: {
            try {
                const disk = JSON.parse(openedStore.text());
                root.opened = disk && typeof disk === "object" && !Array.isArray(disk) ? disk : {};
            } catch (e) {
                root.opened = {};
            }
            root.openedLoaded = true;
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.openedLoaded = true;
        }
    }

    function touch(path: string): void {
        const next = Object.assign({}, root.opened);
        next[path] = Date.now();
        root.opened = next;
        if (root.openedLoaded)
            openedStore.setText(JSON.stringify(next, null, 4) + "\n");
    }

    Process {
        id: editorProbe

        running: true
        command: ["sh", "-c", 'for c in "$@"; do command -v "$c" >/dev/null 2>&1 && echo "$c"; done', "sh", ...Logic.GUI_EDITORS, ...Logic.FALLBACK_TERMINAL_EDITORS]
        stdout: StdioCollector {
            onStreamFinished: root.editors = text.split("\n").filter(Boolean)
        }
    }

    readonly property string terminalScript: `${Quickshell.shellDir}/scripts/in-terminal.sh`

    function openInEditor(path: string): void {
        root.touch(path);
        root.edit(path, path);
    }

    function edit(target: string, folder: string): void {
        const chosen = root.editor;
        if (!chosen) {
            Quickshell.execDetached(["xdg-open", target]);
            return;
        }
        if (chosen.terminal)
            Quickshell.execDetached([root.terminalScript, Logic.terminalLine(folder, chosen.command, target === folder ? "" : target)]);
        else
            Quickshell.execDetached({
                command: [...chosen.command, target],
                workingDirectory: folder
            });
    }

    function openTerminal(path: string): void {
        root.touch(path);
        Quickshell.execDetached({
            command: [root.terminalScript, Logic.shellLine(path)],
            workingDirectory: path
        });
    }
}
