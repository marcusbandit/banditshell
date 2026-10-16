pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs.config

Singleton {
    id: root

    readonly property bool wanted: Config.values.polkit.agent && !Quickshell.env("BANDITSHELL_PREVIEW")

    property PolkitAgent agent: null

    property var stopped: []

    readonly property bool serving: root.agent?.isRegistered ?? false

    readonly property var flow: root.agent?.flow ?? null

    property bool showing: false

    readonly property bool active: root.showing || !!root.agent?.isActive && !!root.flow && !root.flow.isCompleted

    readonly property bool busy: !root.showing && root.active && !root.flow.isResponseRequired

    readonly property string kind: "password"

    property var expected: null

    readonly property bool ours: !!root.expected && root.message.includes(root.expected.program)

    readonly property string title: root.showing ? "Uninstall Firefox" : root.ours ? root.expected.label : "Authentication"
    readonly property string message: root.showing ? "Authentication is needed to run `/usr/bin/pacman -Rs --noconfirm firefox' as the super user" : root.flow?.message ?? ""
    readonly property string warning: root.showing || !root.flow ? "" : root.flow.supplementaryIsError && root.flow.supplementaryMessage ? root.flow.supplementaryMessage : root.flow.failed ? "That password did not work" : ""
    readonly property string placeholder: (root.flow?.inputPrompt ?? "").replace(/:\s*$/, "").trim().toLowerCase() || "password"

    readonly property string requester: ""
    readonly property string description: ""
    readonly property string choiceLabel: ""
    readonly property bool choiceChosen: false
    readonly property string continueLabel: "allow"
    readonly property string cancelLabel: "cancel"

    property int asked: 0

    property string screenName: ""

    function submit(secret: string): void {
        if (root.showing)
            root.showing = false;
        else if (root.flow?.isResponseRequired)
            root.flow.submit(secret);
    }

    function refuse(): void {
        if (root.showing)
            root.showing = false;
        else if (root.flow && !root.flow.isCompleted)
            root.flow.cancelAuthenticationRequest();
    }

    function expect(label: string, program: string): void {
        root.expected = {
            label: label,
            program: program
        };
    }

    function forget(): void {
        root.expected = null;
    }

    function demo(): void {
        root.screenName = root.screenFor(Shell.offStageScreen);
        root.asked += 1;
        root.showing = true;
    }

    function confirm(): void {
    }

    function choose(on: bool): void {
    }

    function screenFor(wanted: string): string {
        const names = Quickshell.screens.map(screen => screen.name);
        return names.includes(wanted) ? wanted : names[0] ?? "";
    }

    function start(): void {
        retire.stop();
        if (root.agent || !root.wanted || !Config.loaded || takeover.running)
            return;
        takeover.running = true;
    }

    function handBack(): void {
        for (const gone of root.stopped)
            Quickshell.execDetached(gone.kind === "unit" ? ["systemctl", "--user", "start", gone.what] : [gone.what]);
        root.stopped = [];
    }

    onWantedChanged: {
        if (root.wanted)
            root.start();
        else if (root.agent)
            retire.restart();
    }

    Connections {
        target: Config

        function onLoadedChanged(): void {
            root.start();
        }
    }

    Component.onCompleted: root.start()

    Component {
        id: agentMaker

        PolkitAgent {
            onAuthenticationRequestStarted: {
                root.screenName = root.screenFor(Shell.offStageScreen);
                root.asked += 1;
            }
        }
    }

    Timer {
        id: retire

        interval: 3000
        onTriggered: {
            if (root.wanted || !root.agent)
                return;
            root.agent.destroy();
            root.agent = null;
            root.handBack();
        }
    }

    Process {
        id: takeover

        command: [Quickshell.shellPath("scripts/polkit-takeover.sh")]
        stdout: StdioCollector {
            onStreamFinished: {
                const gone = text.split("\n").filter(Boolean).map(line => ({
                            kind: line.slice(0, line.indexOf("\t")),
                            what: line.slice(line.indexOf("\t") + 1)
                        }));
                root.stopped = [...root.stopped, ...gone.filter(g => !root.stopped.some(s => s.what === g.what))];
            }
        }
        onExited: {
            if (root.wanted && !root.agent)
                root.agent = agentMaker.createObject(root);
        }
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true

        function onIsResponseRequiredChanged(): void {
            if (root.flow?.isResponseRequired)
                root.asked += 1;
        }
    }
}
