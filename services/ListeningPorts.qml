pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import "listening-ports.js" as Logic

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.devOps ?? {}).ports !== false
    readonly property int freshFor: 2000

    property var listeners: []
    property bool read: false
    property bool readUdp: false
    property bool wantUdp: false
    property real readAt: 0
    property int uid: -1
    property var users: ({})
    property bool fuserFound: false
    property bool found: true
    property var jobs: ({})

    readonly property bool loading: lister.running || debounce.running

    function want(udp: bool): void {
        root.wantUdp = udp;
        if (!root.enabled)
            return;
        if (Date.now() - root.readAt < root.freshFor && (!udp || root.readUdp))
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
        lister.udp = root.wantUdp;
        lister.command = ["sh", "-c", 'id -u; command -v fuser >/dev/null 2>&1 && echo fuser || echo none; printf "\\036"; cat /etc/passwd 2>/dev/null; printf "\\036"; exec ss "$1"', "sh", Logic.command(root.wantUdp)[1]];
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

    function start(command: var, done: var): void {
        const job = jobMaker.createObject(root, {
            command: command
        });
        job.finished.connect(done);
        job.running = true;
    }

    function quit(listener: var, force: bool): void {
        const pids = listener.owners.map(o => o.pid).filter(pid => pid > 0);
        if (!pids.length)
            return;
        const signal = force ? "-KILL" : "-TERM";
        root.mark(listener.key, force ? "killing" : "quitting");
        root.start(["kill", signal, ...pids.map(String)], (code, output, error) => {
            if (code === 0 || /no such process/i.test(error)) {
                root.mark(listener.key, "");
                root.relist();
                return;
            }
            Polkit.expect(`Quit ${Logic.ownerName(listener) || `port ${listener.port}`}`, "kill");
            root.start(["pkexec", "kill", signal, ...pids.map(String)], () => {
                Polkit.forget();
                root.mark(listener.key, "");
                root.relist();
            });
        });
    }

    function quitAsAdministrator(listener: var, force: bool): void {
        if (!root.fuserFound || !Logic.validPort(listener.port) || ["tcp", "udp"].indexOf(listener.protocol) < 0)
            return;
        root.mark(listener.key, force ? "killing" : "quitting");
        Polkit.expect(`Free port ${listener.port}`, "fuser");
        root.start(["pkexec", "fuser", "-k", force ? "-KILL" : "-TERM", "-n", listener.protocol, String(listener.port)], () => {
            Polkit.forget();
            root.mark(listener.key, "");
            root.relist();
        });
    }

    Timer {
        id: debounce

        interval: 200
        onTriggered: root.list()
    }

    Timer {
        id: settle

        interval: 500
        onTriggered: root.list()
    }

    Process {
        id: lister

        property bool udp: false

        stdout: StdioCollector {
            id: listed
        }
        onExited: code => {
            const parts = listed.text.split("\u001e");
            const head = (parts[0] ?? "").split("\n");
            root.uid = parseInt(head[0], 10);
            root.fuserFound = (head[1] ?? "").trim() === "fuser";
            root.users = Logic.readUsers(parts[1] ?? "");
            root.found = code !== 127;
            root.listeners = code === 0 ? Logic.readListeners(parts[2] ?? "", "tcp") : [];
            root.readAt = Date.now();
            root.readUdp = lister.udp;
            root.read = true;
            if (root.wantUdp && !lister.udp)
                debounce.restart();
        }
    }

    Component {
        id: jobMaker

        CommandJob {}
    }
}
