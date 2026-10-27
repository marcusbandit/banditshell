pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "files-find.js" as Find

Singleton {
    id: root

    readonly property string scope: Config.values.files.search
    readonly property bool everywhere: Config.values.files.searchEverywhere
    readonly property bool home: root.scope === "home"
    readonly property int limit: Find.LIMIT

    property string query: ""
    property string cwd: ""
    property bool hidden: false

    readonly property bool active: root.home && Find.searchable(root.query)
    readonly property bool tooShort: root.home && root.query.trim() !== "" && !root.active

    property var results: []
    property var fresh: []
    property var provisional: []
    property var pending: []
    property int scanned: 0
    property bool running: false
    property bool stopped: false
    property bool capped: false
    property bool finished: false
    property string finishedFor: ""

    property int generation: 0
    property var run: null

    readonly property string summary: {
        const folders = `${root.scanned.toLocaleString()} ${root.scanned === 1 ? "folder" : "folders"}`;
        if (root.running)
            return root.scanned > 0 ? `searching, ${folders} so far` : "searching";
        if (root.stopped)
            return root.scanned > 0 ? `stopped after ${folders}` : "stopped";
        if (root.capped)
            return `the first ${root.limit.toLocaleString()} matches`;
        return root.finished ? `${folders} searched` : "";
    }

    function setScope(scope: string): void {
        if (scope !== root.scope)
            Config.set("files.search", scope);
    }

    function toggleScope(): void {
        root.setScope(root.home ? "folder" : "home");
    }

    onScopeChanged: root.restart()
    onEverywhereChanged: root.restart()

    function restart(): void {
        root.finishedFor = "";
        root.ask(root.query, root.cwd, root.hidden);
    }

    function signature(): string {
        return [root.cwd, root.hidden, root.everywhere].join("\n");
    }

    function ask(text: string, cwd: string, hidden: bool): void {
        const sameWalk = cwd === root.cwd && hidden === root.hidden;
        const before = root.query;
        root.query = text;
        root.cwd = cwd;
        root.hidden = hidden;
        root.halt();
        root.stopped = false;

        if (!root.active) {
            settle.stop();
            root.results = [];
            root.fresh = [];
            root.provisional = [];
            root.capped = false;
            root.finished = false;
            return;
        }

        const kept = sameWalk ? Find.named(root.results, text) : [];
        if (sameWalk && root.finished && !root.capped && root.finishedFor === root.signature() && Find.narrows(before, text)) {
            settle.stop();
            root.results = kept;
            return;
        }

        root.provisional = kept;
        root.results = kept;
        root.fresh = [];
        root.finished = false;
        root.capped = false;
        root.scanned = 0;
        root.running = true;
        settle.restart();
    }

    function halt(): void {
        root.generation += 1;
        flush.stop();
        root.pending = [];
        if (root.run) {
            root.run.running = false;
            root.run = null;
        }
        root.running = false;
    }

    function stop(): void {
        if (!root.running)
            return;
        settle.stop();
        root.take(root.generation);
        root.halt();
        root.results = Find.merged(root.fresh, root.provisional);
        root.stopped = true;
    }

    function heard(generation: int, line: string): void {
        if (generation !== root.generation)
            return;
        const said = Find.parse(line);
        if (!said)
            return;
        if (said.entry) {
            root.pending.push(said.entry);
            if (!flush.running)
                flush.start();
            return;
        }
        root.scanned = said.scanned;
        if (said.done) {
            root.take(generation);
            root.capped = said.capped;
            root.finished = true;
            root.finishedFor = root.signature();
            root.running = false;
            root.run = null;
            root.provisional = [];
            root.results = root.fresh;
        }
    }

    function take(generation: int): void {
        if (generation !== root.generation || root.pending.length === 0)
            return;
        root.fresh = root.fresh.concat(root.pending);
        root.pending = [];
        root.results = Find.merged(root.fresh, root.provisional);
    }

    function ended(process: var): void {
        if (process !== root.run)
            return;
        root.take(root.generation);
        root.run = null;
        root.running = false;
    }

    Timer {
        id: flush

        interval: 80

        onTriggered: root.take(root.generation)
    }

    Timer {
        id: settle

        interval: 120

        onTriggered: {
            const command = Find.command(`${Quickshell.shellDir}/bin/bs-ls`, root.query, System.home, root.cwd, {
                hidden: root.hidden,
                deep: root.everywhere
            });
            if (!command) {
                root.running = false;
                return;
            }
            root.run = walker.createObject(root, {
                command: command,
                generation: root.generation,
                running: true
            });
        }
    }

    Component {
        id: walker

        Process {
            id: process

            property int generation: 0

            stdout: SplitParser {
                onRead: line => root.heard(process.generation, line)
            }

            onRunningChanged: if (!process.running) {
                root.ended(process);
                process.destroy();
            }
        }
    }
}
