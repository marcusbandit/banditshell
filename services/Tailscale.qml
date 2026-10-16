pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "tailscale.js" as Logic

Singleton {
    id: root

    readonly property bool installed: ToolInstaller.has("tailscale")

    property var status: null
    property string trouble: ""
    property bool needsOperator: false
    property string busy: ""
    property double readAt: 0
    property string openedUrl: ""

    readonly property bool known: root.status !== null
    readonly property bool running: !!root.status?.running
    readonly property string state: root.status?.state ?? ""
    readonly property bool signedOut: root.state === "NeedsLogin"
    readonly property var peers: root.status?.peers ?? []
    readonly property var exitNodes: root.peers.filter(p => p.exitOption || p.exitActive)
    readonly property string exitNode: root.status?.exitNode ?? ""
    readonly property string stateText: root.trouble || Logic.stateText(root.state)

    property var viewers: []

    function setViewing(viewer: var, on: bool): void {
        const held = root.viewers.indexOf(viewer) >= 0;
        if (on && !held)
            root.viewers = root.viewers.concat([viewer]);
        else if (!on && held)
            root.viewers = root.viewers.filter(other => other !== viewer);
        if (on)
            root.refresh();
    }

    onInstalledChanged: if (root.installed && root.viewers.length)
        root.refresh()

    function refresh(): void {
        if (!root.installed || reader.running || Date.now() - root.readAt < 1000)
            return;
        reader.running = true;
    }

    property var queued: null

    function run(what: string, command: var): void {
        if (!root.installed || !command.length)
            return;
        const job = {
            what: what,
            command: command
        };
        if (!actor.running)
            return root.start(job);
        root.queued = job;
        if (root.busy === "signin") {
            actor.replaced = true;
            actor.running = false;
        }
    }

    function start(job: var): void {
        root.busy = job.what;
        root.trouble = "";
        actor.said = "";
        actor.replaced = false;
        actor.timedOut = false;
        if (job.what === "operator")
            Polkit.expect("Let you control Tailscale", "tailscale");
        actor.command = job.command;
        deadline.interval = 20000;
        deadline.restart();
        actor.running = true;
    }

    function up(): void {
        if (root.state === "NeedsMachineAuth")
            return;
        if (root.busy === "signin" && actor.running && root.openedUrl) {
            Quickshell.execDetached(["xdg-open", root.openedUrl]);
            return;
        }
        root.run(root.signedOut ? "signin" : "up", ["tailscale", "up"]);
    }

    function down(): void {
        root.run("down", ["tailscale", "down"]);
    }

    function useExitNode(peer: var): void {
        root.run(peer ? `exit:${peer.id}` : "exit:", Logic.exitNodeCommand(peer?.address ?? ""));
    }

    function allowOperator(): void {
        if (!whoami.running)
            whoami.running = true;
    }

    function hear(line: string): void {
        actor.said += `${line}\n`;
        const url = Logic.authUrlIn(line);
        if (!url || url === root.openedUrl)
            return;
        root.openedUrl = url;
        root.busy = "signin";
        deadline.interval = 300000;
        deadline.restart();
        Quickshell.execDetached(["xdg-open", url]);
    }

    Timer {
        interval: 4000
        repeat: true
        running: root.viewers.length > 0 && root.installed
        onTriggered: root.refresh()
    }

    Process {
        id: reader

        command: ["tailscale", "status", "--json"]

        stdout: StdioCollector {
            id: readerOutput
        }

        stderr: StdioCollector {
            id: readerErrors
        }

        onExited: code => {
            root.readAt = Date.now();
            const parsed = code === 0 ? Logic.parseStatus(readerOutput.text) : null;
            root.status = parsed;
            if (!parsed && !actor.running)
                root.trouble = Logic.explain(readerErrors.text || readerOutput.text).text || "tailscale did not answer";
            else if (parsed && !actor.running && !root.needsOperator)
                root.trouble = "";
        }
    }

    Timer {
        id: deadline

        onTriggered: {
            if (!actor.running)
                return;
            actor.timedOut = true;
            actor.running = false;
        }
    }

    Process {
        id: whoami

        command: ["id", "-un"]

        stdout: StdioCollector {
            id: whoamiOutput
        }

        onExited: code => {
            const command = code === 0 ? Logic.operatorCommand(ToolInstaller.pathOf("tailscale"), whoamiOutput.text.trim()) : [];
            if (command.length)
                root.run("operator", command);
            else
                root.trouble = "could not tell who you are";
        }
    }

    Process {
        id: actor

        property string said: ""
        property bool replaced: false
        property bool timedOut: false

        stdout: SplitParser {
            onRead: line => root.hear(line)
        }

        stderr: SplitParser {
            onRead: line => root.hear(line)
        }

        onExited: code => {
            deadline.stop();
            const what = root.busy;
            root.busy = "";
            root.openedUrl = "";
            if (what === "operator")
                Polkit.forget();
            if (actor.replaced) {
                root.trouble = "";
            } else if (actor.timedOut) {
                root.trouble = what === "signin" ? "the sign in was not finished" : "tailscale did not answer";
            } else if (code === 0) {
                root.trouble = "";
                if (what === "operator")
                    root.needsOperator = false;
            } else if (what === "operator") {
                root.trouble = code === 126 || code === 127 ? "" : "could not make you the operator";
            } else {
                const why = Logic.explain(actor.said);
                root.needsOperator = why.operator;
                root.trouble = why.text || "tailscale refused";
            }
            const next = root.queued;
            root.queued = null;
            if (next)
                root.start(next);
            root.readAt = 0;
            root.refresh();
        }
    }
}
