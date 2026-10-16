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

    function run(what: string, command: var): void {
        if (!root.installed || actor.running || !command.length)
            return;
        root.busy = what;
        root.trouble = "";
        actor.said = "";
        actor.command = command;
        actor.running = true;
    }

    function up(): void {
        if (!root.signedOut) {
            root.run("up", ["tailscale", "up"]);
            return;
        }
        if (signer.running) {
            if (root.openedUrl)
                Quickshell.execDetached(["xdg-open", root.openedUrl]);
            return;
        }
        root.trouble = "";
        root.openedUrl = "";
        root.busy = "signin";
        signer.running = true;
    }

    function down(): void {
        root.run("down", ["tailscale", "down"]);
    }

    function useExitNode(peer: var): void {
        root.run(peer ? `exit:${peer.id}` : "exit:", Logic.exitNodeCommand(peer?.address ?? ""));
    }

    function allowOperator(): void {
        const command = Logic.operatorCommand(ToolInstaller.pathOf("tailscale"), Quickshell.env("USER"));
        if (!command.length || actor.running)
            return;
        Polkit.expect("Let you control Tailscale", "tailscale");
        root.run("operator", command);
    }

    function hear(line: string): void {
        actor.said += `${line}\n`;
    }

    function hearSigner(line: string): void {
        const url = Logic.authUrlIn(line);
        if (url && url !== root.openedUrl) {
            root.openedUrl = url;
            if (root.busy === "signin")
                root.busy = "";
            Quickshell.execDetached(["xdg-open", url]);
        }
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

    Process {
        id: signer

        command: ["tailscale", "up"]

        stdout: SplitParser {
            onRead: line => root.hearSigner(line)
        }

        stderr: SplitParser {
            onRead: line => root.hearSigner(line)
        }

        onExited: {
            if (root.busy === "signin")
                root.busy = "";
            root.readAt = 0;
            root.refresh();
        }
    }

    Process {
        id: actor

        property string said: ""

        stdout: SplitParser {
            onRead: line => root.hear(line)
        }

        stderr: SplitParser {
            onRead: line => root.hear(line)
        }

        onExited: code => {
            const what = root.busy;
            root.busy = "";
            if (what === "operator")
                Polkit.forget();
            if (code === 0) {
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
            root.readAt = 0;
            root.refresh();
        }
    }
}
