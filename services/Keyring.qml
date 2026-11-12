pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "keyring-windows.js" as KeyringWindows
import "password-asks.js" as PasswordAsks

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

    property string requester: ""

    property int requesterPid: 0

    property var cause: null

    property string callerCommand: ""

    property string screenName: ""

    readonly property bool serving: helper.running && root.holding

    property bool holding: false

    property bool blocked: false

    property string owner: ""

    property int ownerPid: 0

    property var brought: []

    readonly property bool gcrAsking: root.blocked && root.owner === "gcr-prompter"

    onGcrAskingChanged: root.bringGcr()

    property bool lookAgain: false

    function bringGcr(): void {
        if (!root.gcrAsking)
            return;
        if (gcrWindows.running)
            root.lookAgain = true;
        else
            gcrWindows.running = true;
    }

    function letGo(): void {
        root.holding = false;
        root.blocked = false;
        root.owner = "";
        root.ownerPid = 0;
        root.brought = [];
    }

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
        root.requester = "";
        root.requesterPid = 0;
        root.cause = null;
        root.callerCommand = "";
    }

    function screenFor(wanted: string): string {
        const names = Quickshell.screens.map(screen => screen.name);
        if (names.includes(wanted))
            return wanted;
        return names.includes(Focus.offStageScreen) ? Focus.offStageScreen : names[0] ?? "";
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

        if (event.event === "acquired") {
            if (event.name === "org.gnome.keyring.SystemPrompter") {
                root.letGo();
                root.holding = true;
            }
            return;
        }

        if (event.event === "owner") {
            if (event.name !== "org.gnome.keyring.SystemPrompter")
                return;
            if ((event.pid ?? 0) !== root.ownerPid)
                root.brought = [];
            root.ownerPid = event.pid ?? 0;
            root.owner = event.program ?? "";
            root.holding = false;
            root.blocked = true;
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
        root.requester = event.requester ?? "";
        root.requesterPid = event.requesterPid ?? 0;
        root.cause = null;
        root.callerCommand = "";

        root.screenName = root.screenFor(Focus.offStageScreen);
        root.asked += 1;
        root.active = true;
        root.traceCaller();
    }

    function traceCaller(): void {
        if (!(root.requesterPid > 0) || !/ssh|pinentry/.test(root.requester))
            return;
        trace.serial = root.serial;
        trace.running = true;
    }

    readonly property var scenes: ({
            login: {
                title: "Unlock Login Keyring",
                message: "Authentication required",
                description: "The login keyring did not get unlocked when you logged into your computer.",
                choiceLabel: "Automatically unlock this keyring whenever I’m logged in",
                continueLabel: "Unlock",
                requester: "gnome-keyring-daemon"
            },
            ssh: {
                title: "Unlock private key",
                message: "Enter password to unlock the private key",
                description: `An application wants access to the private key “ Enter passphrase for ${Quickshell.env("HOME")}/.ssh/id_ed25519: ”, but it is locked`,
                choiceLabel: "Automatically unlock this key whenever I’m logged in",
                continueLabel: "Unlock",
                requester: "gcr-ssh-agent",
                cause: {
                    who: "git",
                    doing: "push to github.com/marcusbandit/banditshell"
                },
                callerCommand: "/usr/bin/ssh -o SendEnv=GIT_PROTOCOL git@github.com git-receive-pack 'marcusbandit/banditshell.git'"
            },
            agent: {
                title: "Unlock private key",
                message: "Enter password to unlock the private key",
                description: `An application wants access to the private key “ Enter passphrase for ${Quickshell.env("HOME")}/.ssh/id_ed25519: ”, but it is locked`,
                choiceLabel: "Automatically unlock this key whenever I’m logged in",
                continueLabel: "Unlock",
                requester: "gcr-ssh-agent",
                cause: {
                    who: "claude",
                    doing: "pull from github.com/marcusbandit/banditshell"
                },
                warning: "The unlock password was incorrect"
            },
            gpg: {
                title: "Enter Passphrase",
                message: "Passphrase:",
                description: "Please enter the passphrase to unlock the OpenPGP secret key:\n\"Ada Example <ada@example.com>\"\n255-bit EDDSA key, ID 0123456789ABCDEF,\ncreated 2025-01-01.",
                continueLabel: "OK",
                requester: "pinentry-gnome3",
                cause: {
                    who: "git",
                    doing: "sign a commit"
                }
            },
            keyring: {
                title: "Unlock Keyring",
                message: "Unlock password for: Work",
                description: "An application wants access to the keyring “Work”, but it is locked",
                choiceLabel: "Automatically unlock this keyring whenever I’m logged in",
                continueLabel: "Unlock",
                requester: "gnome-keyring-daemon"
            },
            new: {
                title: "New Keyring Password",
                message: "Choose password for new keyring",
                description: "An application wants to create a new keyring called “Default keyring”. Choose the password you want to use for it.",
                passwordNew: true,
                continueLabel: "Continue",
                requester: "gnome-keyring-daemon"
            },
            confirm: {
                kind: "confirm",
                title: "Store passwords unencrypted?",
                description: "By choosing to use a blank password, your stored passwords will not be safely encrypted. They will be accessible by anyone with access to your files.",
                continueLabel: "Continue",
                requester: "gnome-keyring-daemon"
            }
        })

    function demo(): void {
        root.scene("login");
    }

    function scene(name: string): bool {
        const picked = root.scenes[name];
        if (!picked)
            return false;
        root.serial = -1;
        root.kind = picked.kind ?? "password";
        root.title = picked.title ?? "";
        root.message = picked.message ?? "";
        root.description = picked.description ?? "";
        root.warning = picked.warning ?? "";
        root.choiceLabel = picked.choiceLabel ?? "";
        root.choiceChosen = false;
        root.passwordNew = picked.passwordNew ?? false;
        root.continueLabel = picked.continueLabel ?? "";
        root.cancelLabel = "Cancel";
        root.requester = picked.requester ?? "";
        root.requesterPid = 0;
        root.cause = picked.cause ?? null;
        root.callerCommand = picked.callerCommand ?? "";
        root.screenName = root.screenFor(Focus.offStageScreen);
        root.asked += 1;
        root.active = true;
        return true;
    }

    Process {
        id: trace

        property int serial: 0

        command: ["sh", "-c", "ss -xpH 2>/dev/null; echo '#ps'; ps -eo pid=,ppid=,etimes=,args="]

        stdout: StdioCollector {
            onStreamFinished: {
                if (trace.serial !== root.serial || !root.active)
                    return;
                const cut = text.indexOf("#ps\n");
                if (cut < 0)
                    return;
                const chain = PasswordAsks.callerOf(text.slice(0, cut), text.slice(cut + 4), root.requesterPid, root.requester);
                root.cause = PasswordAsks.causeOf(chain);
                root.callerCommand = PasswordAsks.commandOf(chain);
            }
        }
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
            root.letGo();
        }
    }

    Process {
        id: gcrWindows

        command: ["hyprctl", "-j", "clients"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.gcrAsking)
                    return;
                const special = Hypr.specialOn(Hypr.focusedScreen);
                const found = KeyringWindows.windowsToBring(text, root.ownerPid, special, Hypr.activeId, root.brought);
                for (const window of found) {
                    if (window.move)
                        Hypr.sendToWorkspace(window.address, special || Hypr.activeId, true);
                    else
                        Hypr.focusAddress(window.address);
                }
                root.brought = [...root.brought, ...found.map(window => window.address)];
            }
        }

        onExited: {
            if (!root.lookAgain)
                return;
            root.lookAgain = false;
            root.bringGcr();
        }
    }

    Connections {
        target: Hypr

        function onWindowOpened(addr: string, title: string, cls: string): void {
            root.bringGcr();
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged(): void {
            if (root.active)
                root.screenName = root.screenFor(root.screenName);
        }
    }
}
