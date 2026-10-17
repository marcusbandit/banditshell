pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "notes.js" as Logic
import "projects.js" as Paths

Singleton {
    id: root

    readonly property var settings: Config.values.launcher.powerTools
    readonly property var roots: Paths.listFrom(root.settings.noteFolders, System.home)
    readonly property string chosenVault: root.settings.noteVault

    property string registry: ""
    property string flatpakRegistry: ""
    property string discovered: ""

    readonly property var vaults: Logic.withoutSkipped(Logic.vaultsFrom([root.registry, root.flatpakRegistry], root.discovered), root.settings.noteSkip, System.home)
    readonly property var vault: Logic.defaultVault(root.vaults, root.chosenVault)

    property var notes: []
    property double indexedAt: 0
    property string indexedFor: ""

    property bool obsidian: false
    property double foundAt: 0

    readonly property int limit: 20000
    readonly property int staleMs: 60000

    property bool asked: false

    onVaultsChanged: {
        root.indexedAt = 0;
        if (root.asked)
            root.index();
    }

    function refresh(): void {
        root.asked = true;
        if (!finder.running && Date.now() - root.foundAt > root.staleMs) {
            finder.command = Logic.findCommand(root.roots);
            finder.running = true;
        }
        if (!handler.running && !root.obsidian)
            handler.running = true;
        root.index();
    }

    function index(): void {
        const signature = root.vaults.map(v => v.path).join("\n");
        if (indexer.running || !root.vaults.length || root.indexedFor === signature && Date.now() - root.indexedAt < root.staleMs)
            return;
        indexer.vaultList = root.vaults;
        indexer.signature = signature;
        indexer.command = Logic.indexCommand(root.vaults, root.limit);
        indexer.running = true;
    }

    FileView {
        id: registryFile

        path: `${Quickshell.env("XDG_CONFIG_HOME") || `${System.home}/.config`}/obsidian/obsidian.json`
        printErrors: false
        watchChanges: true
        onFileChanged: registryFile.reload()
        onLoaded: root.registry = registryFile.text()
    }

    FileView {
        id: flatpakFile

        path: `${System.home}/.var/app/md.obsidian.Obsidian/config/obsidian/obsidian.json`
        printErrors: false
        watchChanges: true
        onFileChanged: flatpakFile.reload()
        onLoaded: root.flatpakRegistry = flatpakFile.text()
    }

    Process {
        id: finder

        stdout: StdioCollector {
            onStreamFinished: {
                root.discovered = text;
                root.foundAt = Date.now();
            }
        }
    }

    Process {
        id: indexer

        property var vaultList: []
        property string signature: ""

        stdout: StdioCollector {
            onStreamFinished: {
                root.notes = Logic.readIndex(text, indexer.vaultList);
                root.indexedFor = indexer.signature;
                root.indexedAt = Date.now();
                if (root.vaults.map(v => v.path).join("\n") !== indexer.signature)
                    Qt.callLater(root.index);
            }
        }
    }

    Process {
        id: handler

        running: true
        command: ["sh", "-c", "command -v xdg-mime >/dev/null 2>&1 && xdg-mime query default x-scheme-handler/obsidian"]
        stdout: StdioCollector {
            onStreamFinished: root.obsidian = text.trim().length > 0
        }
    }

    function open(note: var): void {
        const vault = root.vaults.find(v => v.path === note.vault);
        if (root.obsidian && vault?.registered)
            Quickshell.execDetached(["xdg-open", Logic.openUri(vault.name, note.relative)]);
        else
            Quickshell.execDetached(["xdg-open", note.path]);
    }

    function create(title: string): void {
        const vault = root.vault;
        const name = Logic.fileNameFor(title);
        if (!vault || !name)
            return;
        if (root.obsidian && vault.registered) {
            Quickshell.execDetached(["xdg-open", Logic.newUri(vault.name, name)]);
            return;
        }
        Quickshell.execDetached(["sh", "-c", '[ -e "$1" ] || printf "# %s\\n\\n" "$2" > "$1"; exec xdg-open "$1"', "sh", `${vault.path}/${name}.md`, name]);
        root.indexedAt = 0;
    }
}
