pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import "phone.js" as Logic

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.devOps ?? {}).phone !== false
    readonly property string installer: `${Quickshell.shellDir}/scripts/install-package.sh`
    readonly property var packages: ["pacman:kdeconnect", "apt:kdeconnect", "dnf:kdeconnect", "zypper:kdeconnect-kde", "xbps:kdeconnect", "apk:kdeconnect"]
    readonly property int freshFor: 10000

    property var devices: []
    property var names: ({})
    property bool installed: true
    property bool read: false
    property real readAt: 0
    property var jobs: ({})
    property string installing: ""

    readonly property bool loading: lister.running || debounce.running

    function want(): void {
        if (!root.enabled || Date.now() - root.readAt < root.freshFor)
            return;
        debounce.restart();
    }

    function drop(): void {
        debounce.stop();
    }

    function list(): void {
        if (lister.running) {
            debounce.restart();
            return;
        }
        lister.running = true;
    }

    function nameOf(id: string): string {
        return root.names[id] ?? "your phone";
    }

    function mark(key: string, state: string): void {
        const next = Object.assign({}, root.jobs);
        if (state)
            next[key] = state;
        else
            delete next[key];
        root.jobs = next;
    }

    function run(id: string, action: string, payload: var): void {
        const name = root.nameOf(id);
        const sent = Logic.commandFor(id, action, payload);
        if (!sent) {
            if (payload?.kind === "file")
                root.tell(`Nothing sent to ${name}`, `${payload.value} is not a file`);
            return;
        }
        const file = action === "share" && payload.kind === "file";
        const command = file ? ["sh", "-c", '[ -f "$1" ] || exit 3; shift; exec "$@"', "sh", payload.value, ...sent] : sent;
        const key = `${action}:${id}`;
        root.mark(key, "sending");
        root.start(command, (code, output, error) => {
            root.mark(key, "");
            if (file && code === 3)
                root.tell(`Nothing sent to ${name}`, `${payload.value} is not a file`);
            else if (code !== 0 || /error|not reachable|couldn't find/i.test(error))
                root.tell(`Could not reach ${name}`, error.trim().split("\n")[0] ?? "");
        });
    }

    function tell(summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "smartphone", summary, body]);
    }

    function start(command: var, done: var): void {
        const job = jobMaker.createObject(root, {
            command: command
        });
        job.finished.connect(done);
        job.running = true;
    }

    function lookAgain(): void {
        Quickshell.execDetached(["kdeconnect-cli", "--refresh"]);
        root.readAt = 0;
        again.restart();
    }

    function openApp(): void {
        Quickshell.execDetached(["sh", "-c", "if command -v kdeconnect-app >/dev/null 2>&1; then exec kdeconnect-app; fi; exec kdeconnect-settings"]);
    }

    function install(): void {
        if (root.installing === "trying")
            return;
        root.installing = "trying";
        Polkit.expect("Install KDE Connect", "kdeconnect");
        root.start([root.installer, "--polkit", ...root.packages], code => {
            Polkit.forget();
            if (code === 4 || code === 127) {
                root.installing = "terminal";
                Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `'${root.installer}' --ask ${root.packages.join(" ")}`]);
                return;
            }
            root.installing = code === 0 || code === 126 ? "" : "failed";
            root.readAt = 0;
            root.list();
        });
    }

    Timer {
        id: debounce

        interval: 200
        onTriggered: root.list()
    }

    Timer {
        id: again

        interval: 3000
        onTriggered: root.list()
    }

    Process {
        id: lister

        command: Logic.readCommand()
        stdout: StdioCollector {
            id: listed
        }
        onExited: code => {
            root.installed = code !== 3;
            const found = code === 0 ? Logic.readDevices(listed.text) : [];
            const names = Object.assign({}, root.names);
            for (const device of found)
                names[device.id] = device.name;
            root.names = names;
            root.devices = found;
            root.readAt = Date.now();
            root.read = true;
        }
    }

    Component {
        id: jobMaker

        CommandJob {}
    }
}
