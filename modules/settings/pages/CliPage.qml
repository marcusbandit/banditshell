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

    property int state: -1

    property string target: ""
    readonly property string dir: root.target.slice(0, root.target.lastIndexOf("/"))

    property bool busy: false

    readonly property string script: Quickshell.shellPath("scripts/zsh-completion.sh")

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

    Process {
        id: prober

        command: ["sh", "-c", `"$1" where; "$1" status --quiet; echo "state=$?"`, "sh", root.script]

        stdout: StdioCollector {
            onStreamFinished: {
                let where = "";
                let code = -1;
                for (const line of text.trim().split("\n")) {
                    if (line.startsWith("state="))
                        code = parseInt(line.slice(6), 10);
                    else if (line.startsWith("/"))
                        where = line;
                }
                root.target = where;
                root.state = isNaN(code) ? -1 : code;
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

    function short(path: string): string {
        const home = Quickshell.env("HOME");
        return home && path.startsWith(home) ? `~${path.slice(home.length)}` : path;
    }

    function act(verb: string): void {
        if (root.busy)
            return;
        root.busy = true;
        actor.command = [root.script, verb];
        actor.running = true;
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.small / 2

        StyledText {
            width: list.width
            wrapMode: Text.WordWrap
            text: "Generated from the CLI itself, so it offers every verb banditshell has and none it does not."
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
        }

        MenuRow {
            width: list.width
            icon: "keyboard_tab"
            label: "Tab completion"
            detail: {
                if (root.busy)
                    return "working";
                switch (root.state) {
                case 0:
                    return "set up, current";
                case 1:
                    return "set up, stale";
                case 2:
                    return "not set up";
                default:
                    return "";
                }
            }
            tip: root.state === 2 ? "write it, and wire zsh's fpath to find it" : root.state === 1 ? "rebuild it now rather than on the next Tab" : "rebuild it from the CLI as it stands now"
            interactive: !root.busy
            onActivated: root.act("install")

            G2Rect {
                width: Appearance.font.size.small
                height: width
                radius: width / 2
                visible: root.state >= 0 && !root.busy
                color: root.state === 0 ? Appearance.colour.accent : Appearance.colour.textFaint
            }
        }

        StyledText {
            width: list.width
            visible: root.state === 0 || root.state === 1
            text: root.short(root.dir)
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            topPadding: Appearance.padding.small / 2
            bottomPadding: Appearance.padding.small
        }

        MenuRow {
            width: list.width
            visible: root.state === 0 || root.state === 1
            icon: "backspace"
            label: "Remove it"
            detail: "the file, and the fpath line"
            tip: "banditshell keeps working; only the Tab does not"
            interactive: !root.busy
            onActivated: root.act("remove")
        }

        Item {
            width: list.width
            height: Appearance.padding.large

            Separator {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
            }
        }

        StyledText {
            width: list.width
            wrapMode: Text.WordWrap
            text: "It keeps itself current: the first Tab in a shell checks the CLI and rebuilds if it has changed, so a new verb needs nothing pressed here. This row is for the first time, and for a machine where it cannot write the file itself."
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
        }

        StyledText {
            width: list.width
            wrapMode: Text.WordWrap
            visible: root.state === 2
            text: "Open a new terminal afterwards. zsh reads its startup file once."
            color: Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
            topPadding: Appearance.padding.small
        }
    }
}
