pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property var configFiles: HyprConfig.files.map(f => f.path)
    readonly property string script: `${Quickshell.shellDir}/services/cli-migration.js`

    property int deprecated: 0

    property var staleFiles: []

    property bool scanned: false

    property string scannedFiles: ""

    property string lastResult: ""

    readonly property int generation: 1

    readonly property int declinedGeneration: Config.values.cli.bindsDeclinedGeneration > 0 ? Config.values.cli.bindsDeclinedGeneration : (Config.values.cli.bindsDeclined === true ? 1 : 0)

    readonly property bool declined: root.declinedGeneration >= root.generation

    readonly property bool stale: !root.declined && root.deprecated > 0

    property bool nodeAvailable: false

    function scan(): void {
        if (!root.nodeAvailable || !HyprConfig.scanned)
            return;
        root.scannedFiles = root.configFiles.join("\n");
        if (root.configFiles.length === 0) {
            root.staleFiles = [];
            root.deprecated = 0;
            root.scanned = true;
            return;
        }
        scanner.command = ["node", root.script, "--scan"].concat(root.configFiles);
        scanner.running = true;
    }

    function migrate(): string {
        if (root.staleFiles.length === 0)
            return "nothing to migrate";
        migrator.command = ["node", root.script, "--write"].concat(root.staleFiles);
        migrator.running = true;
        return "migrating " + root.staleFiles.join(", ");
    }

    function decline(): void {
        if (root.declined)
            return;
        Config.set("cli.bindsDeclinedGeneration", root.generation);
    }

    Process {
        id: probe

        command: ["node", "--version"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.nodeAvailable = true;
                root.scan();
            }
        }
    }

    Process {
        id: scanner

        stdout: StdioCollector {
            onStreamFinished: {
                const files = [];
                let n = 0;
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const tab = line.indexOf("\t");
                    if (tab < 0)
                        continue;
                    const count = Number(line.slice(0, tab)) || 0;
                    files.push(line.slice(tab + 1));
                    n += count;
                }
                root.staleFiles = files;
                root.deprecated = n;
                root.scanned = true;
            }
        }
    }

    Process {
        id: migrator

        stdout: StdioCollector {
            onStreamFinished: {
                root.lastResult = text.trim() || "nothing changed";
                root.scan();
            }
        }
    }

    Component.onCompleted: {
        if (Config.loaded)
            probe.running = true;
    }

    Connections {
        target: Config

        function onLoadedChanged(): void {
            if (Config.loaded && !root.nodeAvailable)
                probe.running = true;
        }
    }

    Connections {
        target: HyprConfig

        function onScannedChanged(): void {
            if (HyprConfig.scanned && root.configFiles.join("\n") !== root.scannedFiles)
                root.scan();
        }
    }
}
