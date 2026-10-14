pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "default-apps.js" as DefaultAppsLog

Singleton {
    id: root

    readonly property string xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property var terminalNames: DefaultAppsLog.terminalListNames(Quickshell.env("XDG_CURRENT_DESKTOP"))

    readonly property var groups: DefaultAppsLog.GROUPS

    property var answers: ({})
    property var chosen: ({})
    property var terminalLists: ({})
    property var terminalViews: ({})
    property string pendingTerminal: ""
    property bool terminalListed: false
    property bool probed: false
    property var writes: []

    readonly property bool listsTerminals: root.terminalListed
    readonly property bool terminalListsRead: Object.keys(root.terminalLists).length === root.terminalNames.length
    readonly property string terminalList: DefaultAppsLog.effectiveTerminalList(root.orderedLists())

    function orderedLists(): var {
        return root.terminalNames.map(name => Object.assign({ name, text: "", exists: false, readable: false }, root.terminalLists[name]));
    }

    function settleList(name: string, text: string, exists: bool, readable: bool): void {
        root.terminalLists = Object.assign({}, root.terminalLists, {
            [name]: { text, exists, readable }
        });
    }

    function flushTerminal(): void {
        if (!root.pendingTerminal || !root.terminalListsRead)
            return;
        const writes = DefaultAppsLog.terminalWrites(root.orderedLists(), root.pendingTerminal);
        root.pendingTerminal = "";
        for (const write of writes) {
            root.settleList(write.name, write.text, true, true);
            root.terminalViews[write.name]?.setText(write.text);
        }
    }

    onTerminalListsReadChanged: root.flushTerminal()

    function groupOf(key: string): var {
        return root.groups[key] ?? null;
    }

    function valueOf(key: string): string {
        if (root.chosen[key] !== undefined)
            return root.chosen[key];
        if (key === "defTerm" && root.listsTerminals)
            return DefaultAppsLog.terminalListFirst(root.terminalList);
        const group = root.groupOf(key);
        return group ? DefaultAppsLog.groupValue(group, root.answers) : "";
    }

    function offersFor(key: string): var {
        const group = root.groupOf(key);
        return group ? DefaultAppsLog.offers(DesktopIndex.entries, group, root.valueOf(key)) : [];
    }

    function nameFor(key: string): string {
        const id = root.valueOf(key);
        return id ? DesktopIndex.nameFor(id) : "none";
    }

    function noteFor(key: string): string {
        const group = root.groupOf(key);
        if (!group || group.types.length < 2 || (key === "defTerm" && root.listsTerminals))
            return "";
        const strays = DefaultAppsLog.strays(group, root.answers, root.valueOf(key));
        return strays.map(s => `${s.types.join(" and ")} in ${DesktopIndex.nameFor(s.id)}`).join(" · ");
    }

    function choose(key: string, id: string): void {
        const group = root.groupOf(key);
        if (!group || !id)
            return;
        root.chosen = Object.assign({}, root.chosen, {
            [key]: id
        });
        if (key === "defTerm" && root.listsTerminals) {
            root.pendingTerminal = id;
            root.flushTerminal();
            return;
        }
        root.writes = root.writes.concat([["sh", "-c", "id=$1; shift; for type; do xdg-mime default \"$id\" \"$type\"; done", "sh", id].concat(group.types)]);
        root.writeNext();
    }

    function writeNext(): void {
        if (writer.running)
            return;
        if (!root.writes.length)
            return root.ask();
        writer.command = root.writes[0];
        root.writes = root.writes.slice(1);
        writer.running = true;
    }

    function ask(): void {
        if (asker.running)
            return;
        asker.command = ["sh", "-c", "for type; do printf '%s=%s\\n' \"$type\" \"$(xdg-mime query default \"$type\" 2>/dev/null)\"; done", "sh"].concat(DefaultAppsLog.allTypes());
        asker.running = true;
    }

    Component.onCompleted: root.ask()

    Process {
        id: asker

        stdout: StdioCollector {
            onStreamFinished: {
                root.answers = DefaultAppsLog.parseDefaults(text);
                root.chosen = {};
            }
        }
    }

    Process {
        id: writer

        onRunningChanged: {
            if (!writer.running)
                root.writeNext();
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v xdg-terminal-exec"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.terminalListed = text.trim() !== "";
                root.probed = true;
            }
        }
    }

    Instantiator {
        model: root.terminalNames

        delegate: FileView {
            id: file

            required property string modelData

            path: `${root.xdgConfig}/${modelData}`
            printErrors: false
            watchChanges: true

            Component.onCompleted: root.terminalViews[modelData] = file
            onFileChanged: file.reload()
            onLoaded: root.settleList(modelData, file.text(), true, true)
            onLoadFailed: err => root.settleList(modelData, "", false, err === FileViewError.FileNotFound)
        }
    }
}
