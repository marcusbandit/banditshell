pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

Item {
    id: root

    implicitHeight: list.implicitHeight

    readonly property var shells: ["zsh", "bash"]

    property var states: ({})

    readonly property var known: root.shells.filter(s => root.states[s] !== undefined && root.states[s] >= 0)
    readonly property bool anySetUp: root.known.some(s => root.states[s] < 2)
    readonly property bool allCurrent: root.known.length === root.shells.length && root.known.every(s => root.states[s] === 0)

    property bool busy: false

    readonly property string cli: Quickshell.shellPath("cli/banditshell")

    Component.onCompleted: root.probe()

    Connections {
        target: Settings

        function onPageChanged(): void {
            if (Settings.page === "cli")
                root.probe();
        }
    }

    function probe(): void {
        if (root.busy || prober.running)
            return;
        prober.running = true;
    }

    function word(state: int): string {
        switch (state) {
        case 0:
            return "current";
        case 1:
            return "stale";
        case 2:
            return "not set up";
        default:
            return "";
        }
    }

    function summary(): string {
        if (root.busy)
            return "working";
        if (!root.known.length)
            return "";
        const first = root.states[root.known[0]];
        if (root.known.length === root.shells.length && root.known.every(s => root.states[s] === first))
            return first === 2 ? "not set up" : `set up, ${root.word(first)}`;
        return root.known.map(s => `${s} ${root.word(root.states[s])}`).join(", ");
    }

    Process {
        id: prober

        command: ["sh", "-c", `for shell in ${root.shells.join(" ")}; do "$1" completions status "$shell" --quiet; echo "$shell=$?"; done`, "sh", root.cli]

        stdout: StdioCollector {
            onStreamFinished: {
                const next = {};
                for (const line of text.trim().split("\n")) {
                    const at = line.indexOf("=");
                    if (at < 0)
                        continue;
                    const code = parseInt(line.slice(at + 1), 10);
                    next[line.slice(0, at)] = isNaN(code) || code > 2 ? -1 : code;
                }
                root.states = next;
            }
        }
    }

    Process {
        id: actor

        onExited: (code, status) => {
            root.busy = false;
            root.probe();
        }
    }

    function act(verb: string): void {
        if (root.busy)
            return;
        root.busy = true;
        actor.command = [root.cli, "completions", verb, "--quiet"];
        actor.running = true;
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.small / 2

        MenuRow {
            width: list.width
            icon: "keyboard_tab"
            label: "Tab completion"
            detail: root.summary()
            interactive: !root.busy
            onActivated: root.act("install")

            SquircleRect {
                width: Appearance.font.size.small
                height: width
                radius: width / 2
                visible: root.known.length > 0 && !root.busy
                color: root.allCurrent ? Appearance.colour.accent : Appearance.colour.textFaint
            }
        }

        MenuRow {
            width: list.width
            visible: root.anySetUp
            icon: "backspace"
            label: "Remove it"
            interactive: !root.busy
            onActivated: root.act("remove")
        }
    }
}
