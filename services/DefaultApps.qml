pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "default-apps.js" as DefaultAppsLog

Singleton {
    id: root

    readonly property string xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`
    readonly property string terminalListPath: `${root.xdgConfig}/xdg-terminals.list`

    readonly property var groups: DefaultAppsLog.GROUPS

    property var answers: ({})
    property var chosen: ({})
    property string terminalList: ""
    property bool terminalListed: false
    property bool probed: false
    property var writes: []

    readonly property bool listsTerminals: root.terminalListed

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
            const text = DefaultAppsLog.terminalListSet(root.terminalList, id);
            root.terminalList = text;
            terminalFile.setText(text);
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

    FileView {
        id: terminalFile

        path: root.terminalListPath
        printErrors: false

        onLoaded: root.terminalList = text()
        onLoadFailed: root.terminalList = ""
    }
}
