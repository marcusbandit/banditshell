pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false

    property int serial: 0

    property int asked: 0

    property string kind: ""

    property string title: ""
    property string message: ""
    property string description: ""

    property string warning: ""

    property string choiceLabel: ""
    property bool choiceChosen: false

    property bool passwordNew: false

    property string continueLabel: ""
    property string cancelLabel: ""

    property string screenName: ""

    readonly property bool serving: helper.running && !root.blocked

    property bool blocked: false

    function submit(secret: string): void {
        if (!root.active || root.kind !== "password")
            return;
        root.reply({
            reply: "yes",
            secret: secret
        });
    }

    function confirm(): void {
        if (!root.active || root.kind !== "confirm")
            return;
        root.reply({
            reply: "yes"
        });
    }

    function refuse(): void {
        if (!root.active)
            return;
        root.reply({
            reply: "no"
        });
    }

    function choose(on: bool): void {
        root.choiceChosen = on;
    }

    function reply(answer: var): void {
        answer.id = root.serial;
        answer.choice = root.choiceChosen;
        helper.write(JSON.stringify(answer) + "\n");

        root.clear();
    }

    function clear(): void {
        root.active = false;
        root.kind = "";
        root.title = "";
        root.message = "";
        root.description = "";
        root.warning = "";
        root.choiceLabel = "";
        root.choiceChosen = false;
        root.passwordNew = false;
        root.continueLabel = "";
        root.cancelLabel = "";
    }

    function take(line: string): void {
        let event = null;
        try {
            event = JSON.parse(line);
        } catch (e) {
            console.warn(`Keyring: the prompter said something that is not JSON: ${e}`);
            return;
        }

        if (event.event === "hide") {

            if (event.id === root.serial)
                root.clear();
            return;
        }

        if (event.event !== "show")
            return;

        root.serial = event.id;
        root.kind = event.kind ?? "";
        root.title = event.title ?? "";
        root.message = event.message ?? "";
        root.description = event.description ?? "";
        root.warning = event.warning ?? "";
        root.choiceLabel = event.choiceLabel ?? "";
        root.choiceChosen = event.choiceChosen ?? false;
        root.passwordNew = event.passwordNew ?? false;
        root.continueLabel = event.continueLabel ?? "";
        root.cancelLabel = event.cancelLabel ?? "";

        root.screenName = Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
        root.asked += 1;
        root.active = true;
    }

    function demo(): void {
        root.serial = -1;
        root.kind = "password";
        root.title = "Unlock Login Keyring";
        root.message = "Authentication required";
        root.description = "The login keyring did not get unlocked when you logged into your computer.";
        root.warning = "";
        root.choiceLabel = "Automatically unlock this keyring whenever I'm logged in";
        root.choiceChosen = false;
        root.passwordNew = false;
        root.continueLabel = "Unlock";
        root.cancelLabel = "Cancel";
        root.screenName = Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
        root.asked += 1;
        root.active = true;
    }

    Process {
        id: helper

        running: true
        command: ["python3", Quickshell.shellPath("scripts/keyring-prompter.py")]

        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.take(line)
        }

        stderr: SplitParser {
            onRead: line => {
                if (line.includes("DeprecationWarning") || line.startsWith("  "))
                    return;
                console.warn(`Keyring: ${line}`);
            }
        }

        onExited: code => {
            root.clear();
            root.blocked = code === 3;
            if (root.blocked)
                retry.restart();
        }
    }

    Timer {
        id: retry

        interval: 5000
        onTriggered: helper.running = true
    }
}
