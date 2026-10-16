pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "script-commands.js" as Scripts

Singleton {
    id: root

    readonly property string chosenFolder: Config.values.launcher.powerTools.scriptsFolder
    readonly property string folder: root.chosenFolder ? root.chosenFolder.replace(/^~(?=\/|$)/, Files.home).replace(/(.)\/+$/, "$1") : `${Config.dir}/scripts`

    property var scripts: []
    property bool folderExists: false
    property double scannedAt: 0

    property var runs: ({})
    property var live: ({})

    readonly property int keptLines: 200

    function refresh(): void {
        if (Date.now() - root.scannedAt > 3000)
            settle.restart();
    }

    property bool rescanOwed: false

    function scan(): void {
        if (scanner.running) {
            root.rescanOwed = true;
            return;
        }
        root.rescanOwed = false;
        scanner.running = true;
    }

    onFolderChanged: {
        root.scripts = [];
        settle.restart();
    }

    Timer {
        id: settle

        interval: 150
        onTriggered: root.scan()
    }

    Process {
        id: scanner

        command: ["sh", "-c", '[ -d "$1" ] || { echo none; exit 0; }; echo found; for f in "$1"/*; do [ -f "$f" ] || continue; x=0; [ -x "$f" ] && x=1; printf "\\036%s\\t%s\\n" "$x" "$f"; head -c 8192 "$f" | head -n 60; echo; done', "sh", root.folder]

        stdout: StdioCollector {
            onStreamFinished: {
                root.folderExists = text.indexOf("found") === 0;
                root.scripts = Scripts.readScan(text);
                root.scannedAt = Date.now();
            }
        }

        onExited: if (root.rescanOwed)
            Qt.callLater(root.scan)
    }

    function script(path: string): var {
        return root.scripts.find(s => s.path === path) ?? null;
    }

    function record(path: string, fields: var): void {
        const next = Object.assign({}, root.runs);
        next[path] = Object.assign({}, root.runs[path] ?? {}, fields);
        root.runs = next;
    }

    function run(script: var, values: var): void {
        const command = Scripts.commandFor(script, values);
        const folder = script.path.slice(0, script.path.lastIndexOf("/")) || "/";
        if (script.mode === "silent") {
            Quickshell.execDetached({
                command: command,
                workingDirectory: folder
            });
            return;
        }
        root.stop(script.path);
        root.record(script.path, {
            key: Scripts.runKey(script, values),
            running: true,
            lines: [],
            code: 0,
            at: Date.now()
        });
        root.live[script.path] = runner.createObject(root, {
            path: script.path,
            command: Scripts.groupCommand(["sh", "-c", 'exec "$@" 2>&1 </dev/null', "sh", ...command], root.grouped),
            workingDirectory: folder,
            running: true
        });
    }

    function stop(path: string): void {
        const process = root.live[path];
        if (!process)
            return;
        delete root.live[path];
        root.stopGroup(process);
        process.running = false;
        root.record(path, {
            running: false,
            code: -1
        });
    }

    function forget(path: string): void {
        root.stop(path);
        const next = Object.assign({}, root.runs);
        delete next[path];
        root.runs = next;
    }

    readonly property string examples: `${Quickshell.shellDir}/docs/script-commands`

    function createExamples(): void {
        if (!exampleWriter.running)
            exampleWriter.running = true;
    }

    Process {
        id: exampleWriter

        command: ["sh", "-c", 'mkdir -p "$1" || exit 1; for f in "$2"/*.sh "$2"/*.py; do [ -f "$f" ] || continue; t="$1/${f##*/}"; [ -e "$t" ] || { cp "$f" "$t" && chmod +x "$t"; }; done', "sh", root.folder, root.examples]
        onExited: code => {
            restartListing.restart();
            if (code === 0)
                Files.show(root.folder);
        }
    }

    readonly property int listDelay: 300
    readonly property int listTimeoutMs: 5000
    readonly property int listKeep: 24

    property var lists: ({})
    property var latestList: ({})
    property var listOrder: []
    property string listWanted: ""
    property var listScript: null
    property var listValues: []
    property QtObject listRun: null
    readonly property string listAsking: root.listRun?.key ?? ""

    function listFor(path: string, key: string): var {
        return root.lists[key] ?? root.lists[root.latestList[path] ?? ""] ?? null;
    }

    function listFresh(key: string): bool {
        return root.lists[key] !== undefined;
    }

    function listPending(key: string): bool {
        return !!key && root.listWanted === key && (root.listAsking === key || listWait.running);
    }

    function wantList(script: var, values: var): void {
        if (!script) {
            root.listWanted = "";
            listWait.stop();
            root.cancelList();
            return;
        }
        const key = Scripts.runKey(script, values);
        if (key === root.listWanted)
            return;
        root.listWanted = key;
        root.listScript = script;
        root.listValues = values;
        if (root.listRun && root.listRun.key !== key)
            root.cancelList();
        listWait.restart();
    }

    function rerunList(): void {
        const script = root.listScript;
        const values = root.listValues;
        root.listWanted = "";
        if (script)
            root.wantList(script, values);
    }

    function cancelList(): void {
        const run = root.listRun;
        root.listRun = null;
        if (!run)
            return;
        run.dropped = true;
        root.stopGroup(run);
        run.running = false;
        run.destroy();
    }

    property bool grouped: false

    Process {
        running: true
        command: ["sh", "-c", "command -v setsid"]
        onExited: code => root.grouped = code === 0
    }

    function stopGroup(process: var): void {
        const command = process?.running ? Scripts.stopGroupCommand(process.processId) : null;
        if (command)
            Quickshell.execDetached(command);
    }

    function startList(): void {
        const script = root.listScript;
        if (!script || !root.listWanted)
            return;
        root.cancelList();
        root.listRun = listRunner.createObject(root, {
            key: root.listWanted,
            path: script.path,
            command: Scripts.groupCommand(Scripts.commandFor(script, root.listValues), root.grouped),
            workingDirectory: script.path.slice(0, script.path.lastIndexOf("/")) || "/"
        });
        root.listRun.running = true;
    }

    function finishList(run: var): void {
        if (root.listRun === run)
            root.listRun = null;
        if (run.dropped)
            return;
        const folder = run.path.slice(0, run.path.lastIndexOf("/")) || "/";
        const result = run.late ? {
            items: [],
            error: `stopped after ${root.listTimeoutMs / 1000} s`,
            code: -1
        } : Scripts.readList(run.code, run.out, run.err, folder, Files.home, 50);
        const lists = Object.assign({}, root.lists);
        lists[run.key] = Object.assign(result, {
            key: run.key,
            path: run.path,
            at: Date.now()
        });
        const order = root.listOrder.filter(k => k !== run.key).concat([run.key]);
        while (order.length > root.listKeep)
            delete lists[order.shift()];
        const latest = Object.assign({}, root.latestList);
        latest[run.path] = run.key;
        root.lists = lists;
        root.listOrder = order;
        root.latestList = latest;
        run.destroy();
    }

    function select(script: var, arg: string): void {
        Quickshell.execDetached({
            command: Scripts.selectCommand(script, arg),
            workingDirectory: script.path.slice(0, script.path.lastIndexOf("/")) || "/"
        });
    }

    Timer {
        id: listWait

        interval: root.listDelay
        onTriggered: root.startList()
    }

    Component {
        id: listRunner

        Process {
            id: run

            property string key: ""
            property string path: ""
            property bool dropped: false
            property bool late: false
            property bool settled: false
            property int code: -1
            property bool heardOut: false
            property bool heardError: false
            property string out: ""
            property string err: ""

            function settle(): void {
                if (run.settled || run.dropped || run.code < 0 && !run.late || !run.late && !(run.heardOut && run.heardError))
                    return;
                run.settled = true;
                root.finishList(run);
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    run.out = text;
                    run.heardOut = true;
                    run.settle();
                }
            }

            stderr: StdioCollector {
                onStreamFinished: {
                    run.err = text;
                    run.heardError = true;
                    run.settle();
                }
            }

            property Timer limit: Timer {
                interval: root.listTimeoutMs
                running: true
                onTriggered: {
                    run.late = true;
                    root.stopGroup(run);
                    run.running = false;
                    run.settle();
                }
            }

            onExited: code => {
                run.code = code;
                run.settle();
            }
        }
    }

    Timer {
        id: restartListing

        interval: 300
        onTriggered: root.scan()
    }

    Component {
        id: runner

        Process {
            id: process

            property string path: ""
            property var buffer: []

            stdout: SplitParser {
                onRead: line => {
                    process.buffer.push(line);
                    if (process.buffer.length > root.keptLines)
                        process.buffer.shift();
                    if (!process.flush.running)
                        process.flush.start();
                }
            }

            property Timer flush: Timer {
                interval: 120
                onTriggered: process.publish()
            }

            function publish(): void {
                if (root.live[process.path] === process)
                    root.record(process.path, {
                        lines: Scripts.outputLines(process.buffer.join("\n"), root.keptLines)
                    });
            }

            onExited: code => {
                if (root.live[process.path] === process) {
                    delete root.live[process.path];
                    root.record(process.path, {
                        running: false,
                        code: code,
                        lines: Scripts.outputLines(process.buffer.join("\n"), root.keptLines)
                    });
                }
            }

            onRunningChanged: if (!process.running)
                process.destroy()
        }
    }
}
