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
    readonly property bool fuserFound: SystemBinaries.has("fuser") && SystemBinaries.has("pkexec")
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
        lister.command = ["sh", "-c", 'id -u; printf "\\036"; cat /etc/passwd 2>/dev/null; printf "\\036"; systemctl list-sockets --all --no-pager --output=json 2>/dev/null; printf "\\036"; systemctl --user list-sockets --all --no-pager --output=json 2>/dev/null; printf "\\036"; exec ss "$1"', "sh", Logic.command(root.wantUdp)[1]];
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

    function tell(summary: string, body: string): void {
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "dialog-error", summary, body]);
    }

    function finish(listener: var): void {
        Polkit.forget();
        root.mark(listener.key, "");
        root.relist();
    }

    function quit(listener: var, force: bool): void {
        if (!Logic.killable(listener) || root.jobs[listener.key])
            return;
        const name = Logic.ownerName(listener) || `port ${listener.port}`;
        const signal = force ? "-KILL" : "-TERM";
        root.mark(listener.key, force ? "killing" : "quitting");
        root.start(Logic.verifyCommand(listener), (code, output) => {
            const pids = code === 0 ? Logic.confirmedPids(listener, output) : [];
            if (!pids.length) {
                root.finish(listener);
                root.tell(`Did not quit ${name}`, `Port ${listener.port} changed owner since it was listed`);
                return;
            }
            root.start(["kill", signal, ...pids.map(String)], (killed, said, error) => {
                const outcome = Logic.killOutcome(killed, error, pids);
                if (!outcome.denied.length) {
                    root.finish(listener);
                    if (outcome.failed)
                        root.tell(`Could not quit ${name}`, error.trim().split("\n")[0] ?? "");
                    return;
                }
                const command = SystemBinaries.elevated("kill", [signal, ...outcome.denied.map(String)]);
                if (!command) {
                    root.finish(listener);
                    root.tell(`Could not quit ${name}`, "pkexec or kill is missing from the system folders");
                    return;
                }
                Polkit.expect(`Quit ${name}`, "kill");
                root.start(command, () => root.finish(listener));
            });
        });
    }

    function quitAsAdministrator(listener: var, force: bool): void {
        if (!Logic.freeable(listener) || root.jobs[listener.key])
            return;
        const command = SystemBinaries.elevated("fuser", ["-k", force ? "-KILL" : "-TERM", "-n", listener.protocol, String(listener.port)]);
        if (!command)
            return;
        root.mark(listener.key, force ? "killing" : "quitting");
        Polkit.expect(`Free port ${listener.port}`, "fuser");
        root.start(command, () => root.finish(listener));
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
            root.uid = parseInt(parts[0] ?? "", 10);
            root.users = Logic.readUsers(parts[1] ?? "");
            root.found = code !== 127;
            root.listeners = code === 0 ? Logic.withSockets(Logic.readListeners(parts[4] ?? "", "tcp"), Logic.readSockets(parts[2] ?? "", parts[3] ?? "")) : [];
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
