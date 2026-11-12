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

    readonly property string quickFolder: {
        const chosen = Paths.listFrom(root.settings.quickNoteFolder, System.home)[0];
        return chosen ?? (root.vault ? root.vault.path : `${System.home}/Notes`);
    }

    property string contentTerm: ""
    property string contentText: ""
    readonly property var contentNotes: Logic.contentHits(root.contentText, root.notes, [], 10)

    property string pendingTerm: ""
    property string lastSaved: ""

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

    function findContent(term: string): void {
        const clean = term.trim();
        if (clean.length < 3 || !root.vaults.length) {
            root.pendingTerm = "";
            root.contentTerm = "";
            root.contentText = "";
            return;
        }
        if (clean === root.contentTerm)
            return;
        root.pendingTerm = clean;
        contentDelay.restart();
    }

    function capture(text: string): void {
        const body = Logic.quickBody(text);
        if (!text.trim())
            return;
        const name = Logic.quickFileName(text, Date.now());
        root.lastSaved = `${root.quickFolder}/${name}.md`;
        Quickshell.execDetached(Logic.quickCommand(root.quickFolder, name, body));
        root.indexedAt = 0;
    }

    Timer {
        id: contentDelay

        interval: 200
        onTriggered: {
            if (!root.pendingTerm || root.pendingTerm === root.contentTerm)
                return;
            grepper.running = false;
            grepper.term = root.pendingTerm;
            grepper.command = Logic.contentCommand(root.pendingTerm, root.vaults, 40);
            grepper.running = true;
        }
    }

    Process {
        id: grepper

        property string term: ""

        stdout: StdioCollector {
            onStreamFinished: {
                root.contentTerm = grepper.term;
                root.contentText = text;
            }
        }
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
