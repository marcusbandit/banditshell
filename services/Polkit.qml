pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

Singleton {
    id: root

    readonly property bool serving: agent.isRegistered

    readonly property var flow: agent.flow

    property bool showing: false

    readonly property bool active: root.showing || agent.isActive && !!root.flow && !root.flow.isCompleted

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

    PolkitAgent {
        id: agent

        onAuthenticationRequestStarted: {
            root.screenName = root.screenFor(Shell.offStageScreen);
            root.asked += 1;
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
