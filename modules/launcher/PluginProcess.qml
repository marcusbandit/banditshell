import QtQuick
import Quickshell.Io

Process {
    id: root

    property string pluginId: ""
    property var exec: []
    property string folder: ""
    property string log: ""
    property var env: ({})
    property bool stopping: false
    property bool lasting: false
    property var queued: []

    signal said(string line)
    signal ended(bool wanted)

    command: ["sh", "-c", 'mkdir -p "${1%/*}" && { [ -z "$BANDITSHELL_PLUGIN_DATA" ] || mkdir -p -m 700 "$BANDITSHELL_PLUGIN_DATA"; } && exec 2>>"$1" && shift && exec "$@"', "sh", root.log].concat(root.exec)
    workingDirectory: root.folder
    environment: root.env
    stdinEnabled: true

    stdout: SplitParser {
        onRead: line => root.said(line)
    }

    onStarted: {
        for (const line of root.queued)
            root.write(`${line}\n`);
        root.queued = [];
    }

    onExited: root.ended(root.stopping)

    function send(line: string, passing: bool): void {
        if (!passing)
            idle.restart();
        if (root.running && root.processId)
            root.write(`${line}\n`);
        else
            root.queued = root.queued.concat([line]);
    }

    function stop(): void {
        root.stopping = true;
        root.running = false;
    }

    property Timer idle: Timer {
        interval: 600000
        onTriggered: {
            if (!root.lasting)
                root.stop();
        }
    }
}
