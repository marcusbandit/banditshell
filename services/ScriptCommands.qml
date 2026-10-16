pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
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

    FolderListModel {
        id: listing

        folder: `file://${root.folder}`
        showDirs: false
        showHidden: false
        onCountChanged: settle.restart()
    }

    Connections {
        target: listing

        function onDataChanged(): void {
            settle.restart();
        }
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
            command: ["sh", "-c", 'exec "$@" 2>&1 </dev/null', "sh", ...command],
            workingDirectory: folder,
            running: true
        });
    }

    function stop(path: string): void {
        const process = root.live[path];
        if (!process)
            return;
        delete root.live[path];
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

    function createExample(): string {
        const path = `${root.folder}/hello.sh`;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && [ ! -e "$2" ] && printf "%s" "$3" > "$2" && chmod +x "$2"', "sh", root.folder, path, Scripts.EXAMPLE]);
        restartListing.restart();
        return path;
    }

    Timer {
        id: restartListing

        interval: 300
        onTriggered: {
            listing.folder = "";
            listing.folder = `file://${root.folder}`;
            root.scan();
        }
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
