pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import "ssh-hosts.js" as Logic

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.devOps ?? {}).ssh !== false
    readonly property string terminalScript: `${Quickshell.shellDir}/scripts/in-terminal.sh`
    readonly property int freshFor: 20000

    property var hosts: []
    property bool installed: true
    property bool read: false
    property var files: ({})
    property string known: ""
    property int rounds: 0
    property real readAt: 0
    property bool reading: false

    function refresh(): void {
        if (!root.enabled || root.reading || knownReader.running || Date.now() - root.readAt < root.freshFor)
            return;
        root.readAt = Date.now();
        root.files = ({});
        root.rounds = 0;
        root.readPatterns(["config"]);
        knownReader.running = true;
    }

    function readPatterns(patterns: var): void {
        root.reading = true;
        const job = jobMaker.createObject(root, {
            command: Logic.readCommand(patterns)
        });
        job.finished.connect((code, output) => root.took(output));
        job.running = true;
    }

    function took(output: string): void {
        const files = Object.assign({}, root.files, Logic.readFiles(output));
        root.files = files;
        const missing = Logic.missingIncludes(files);
        if (missing.length && root.rounds < 6) {
            root.rounds += 1;
            root.readPatterns(missing);
            return;
        }
        root.reading = false;
        root.build();
    }

    function build(): void {
        root.hosts = Logic.merged(Logic.configHosts(Logic.assemble(root.files, "config", 0)), Logic.readKnownHosts(root.known));
        root.read = true;
    }

    function connect(host: var): void {
        Quickshell.execDetached([root.terminalScript, Logic.terminalLine(host)]);
    }

    Process {
        id: knownReader

        command: Logic.knownCommand()
        stdout: StdioCollector {
            id: knownText
        }
        onExited: code => {
            root.installed = code !== 3;
            root.known = knownText.text;
            root.build();
        }
    }

    Component {
        id: jobMaker

        CommandJob {}
    }
}
