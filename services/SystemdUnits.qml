pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import "systemd-units.js" as Logic

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.devOps ?? {}).services !== false
    readonly property string terminalScript: `${Quickshell.shellDir}/scripts/in-terminal.sh`
    readonly property int freshFor: 3000

    property var units: []
    property bool read: false
    property bool found: true
    property real readAt: 0
    property var jobs: ({})

    readonly property bool loading: lister.running || debounce.running
    readonly property bool elevatable: SystemBinaries.has("pkexec") && SystemBinaries.has("systemctl")

    function controllable(unit: var): bool {
        return unit.scope === "user" || root.elevatable;
    }

    function keyOf(unit: var): string {
        return `${unit.scope}:${unit.name}`;
    }

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

    function control(unit: var, verb: string, after: var): void {
        const command = Logic.controlCommand(unit, verb, (tool, args) => SystemBinaries.elevated(tool, args));
        const key = root.keyOf(unit);
        if (root.jobs[key])
            return;
        if (!command) {
            if (unit.scope !== "user")
                Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "dialog-error", `Could not ${verb} ${unit.base ?? unit.name}`, "pkexec or systemctl is missing from the system folders"]);
            return;
        }
        root.mark(key, Logic.progressWord(verb));
        if (unit.scope !== "user")
            Polkit.expect(`${Logic.verbLabel(verb)} ${unit.base ?? unit.name}`, "systemctl");
        const job = jobMaker.createObject(root, {
            command: command
        });
        job.finished.connect((code, output, error) => {
            if (unit.scope !== "user")
                Polkit.forget();
            root.mark(key, "");
            root.relist();
            if (code !== 0 && code !== 126 && code !== 127)
                Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "dialog-error", `Could not ${verb} ${unit.base ?? unit.name}`, error.trim().split("\n")[0] ?? ""]);
            if (after)
                after(code);
        });
        job.running = true;
    }

    function logs(unit: var): void {
        const line = Logic.logsLine(unit);
        if (line)
            Quickshell.execDetached([root.terminalScript, line]);
    }

    function systemUnit(name: string): var {
        return root.units.find(u => u.scope === "system" && u.name === name) ?? {
            name: name,
            base: name.replace(/\.service$/, ""),
            scope: "system"
        };
    }

    Timer {
        id: debounce

        interval: 200
        onTriggered: root.list()
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: root.list()
    }

    Process {
        id: lister

        command: Logic.readCommand()
        stdout: StdioCollector {
            id: listed
        }
        onExited: code => {
            root.found = code !== 3;
            root.units = code === 0 ? Logic.readUnits(listed.text) : [];
            root.readAt = Date.now();
            root.read = true;
        }
    }

    Component {
        id: jobMaker

        CommandJob {}
    }
}
