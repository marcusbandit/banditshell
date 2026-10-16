pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import "containers.js" as Logic

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.devOps ?? {}).containers !== false
    readonly property string terminalScript: `${Quickshell.shellDir}/scripts/in-terminal.sh`
    readonly property int freshFor: 3000

    property var containers: []
    property var problems: ({})
    property bool read: false
    property real readAt: 0
    property var jobs: ({})

    readonly property var engines: ["podman", "docker"].filter(e => root.problems[e]?.kind !== "missing")
    readonly property bool loading: lister.running || debounce.running

    function want(): void {
        if (!root.enabled || Date.now() - root.readAt < root.freshFor)
            return;
        debounce.restart();
    }

    function drop(): void {
        debounce.stop();
    }

    function relist(): void {
        root.readAt = 0;
        settle.restart();
    }

    function list(): void {
        if (lister.running) {
            debounce.restart();
            return;
        }
        lister.running = true;
    }

    function mark(key: string, state: string): void {
        const next = Object.assign({}, root.jobs);
        if (state)
            next[key] = state;
        else
            delete next[key];
        root.jobs = next;
    }

    function control(container: var, verb: string): void {
        const command = Logic.controlCommand(container, verb);
        const key = container.id;
        if (!command || root.jobs[key])
            return;
        root.mark(key, verb === "start" || verb === "unpause" ? "starting" : verb === "stop" ? "stopping" : "restarting");
        const job = jobMaker.createObject(root, {
            command: command
        });
        job.finished.connect((code, output, error) => {
            root.mark(key, "");
            root.relist();
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "dialog-error", `Could not ${verb} ${container.name}`, error.trim().split("\n")[0] ?? ""]);
        });
        job.running = true;
    }

    function logs(container: var): void {
        const line = Logic.logsLine(container);
        if (line)
            Quickshell.execDetached([root.terminalScript, line]);
    }

    function shell(container: var): void {
        const line = Logic.shellLine(container);
        if (line)
            Quickshell.execDetached([root.terminalScript, line]);
    }

    Timer {
        id: debounce

        interval: 200
        onTriggered: root.list()
    }

    Timer {
        id: settle

        interval: 600
        onTriggered: root.list()
    }

    Process {
        id: lister

        command: Logic.readCommand()
        stdout: StdioCollector {
            id: listed
        }
        onExited: {
            const got = Logic.readAll(listed.text);
            root.containers = got.containers;
            root.problems = got.problems;
            root.readAt = Date.now();
            root.read = true;
        }
    }

    Component {
        id: jobMaker

        CommandJob {}
    }
}
