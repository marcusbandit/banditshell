pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import qs.services

// TERMINAL: the other way into everything on this rail.
//
// Every panel, menu and setting in this shell also has a verb: `banditshell
// menu open clock`, `banditshell set theme slate`, `banditshell close`. That is
// not a debugging convenience, it is how the compositor drives the shell, since
// a Hyprland bind is an exec and nothing else. So the CLI is a first-class face
// of the shell and deserves a page rather than a paragraph in a README.
//
// What is ON the page is the one thing about the CLI that has to be installed
// rather than merely used: tab completion. Everything else about `banditshell`
// works the moment the file exists.
//
// THE ROW IS A BUTTON, not a switch, even though it has an off. Setting the
// completion up and taking it away are not two ends of one setting you flip
// while making up your mind; one is a thing you do once and the other is a thing
// you almost never do, and giving them the same weight would put a toggle on the
// page whose off position nobody wants. So the row acts, and the way back is a
// quieter row underneath that only exists once there is something to undo.
//
// WIDTH COMES FROM THE FACE, the same contract every page here has: fill what
// the pager gives, ask only for height.
Item {
    id: root

    implicitHeight: list.implicitHeight

    // ------------------------------------------------------------- the state

    // What scripts/zsh-completion.sh says, in its own three answers. Held as
    // the number rather than a phrase so the rows can each say their own thing
    // about it; -1 is "have not asked yet", which is not one of the three and
    // must not be drawn as any of them.
    //
    //   0  installed, and built from the CLI as it stands now
    //   1  installed, but older than something it was built from
    //   2  not installed
    property int state: -1

    // Where the file goes, which the script knows and nothing here should
    // guess: it depends on XDG_DATA_HOME and on who is actually logged in.
    property string target: ""
    readonly property string dir: root.target.slice(0, root.target.lastIndexOf("/"))

    // True while a Process is out. Every row goes quiet rather than
    // disappearing: a button that vanishes mid-click is a button you press
    // twice by accident.
    property bool busy: false

    readonly property string script: Quickshell.shellPath("scripts/zsh-completion.sh")

    // ASKED WHEN THE PAGE IS LOOKED AT, and not on a timer. The answer only
    // changes when somebody edits the CLI or presses one of these rows, and a
    // settings panel that polls a shell script every few seconds to draw one
    // line is a cost with nothing on the other side of it. Arriving on the page
    // is the moment the answer starts mattering.
    Component.onCompleted: root.probe()

    Connections {
        target: Settings

        function onPageChanged(): void {
            if (Settings.page === "cli")
                root.probe();
        }
    }

    // Idempotent, so arriving on the page may call it every time.
    function probe(): void {
        if (root.busy || prober.running)
            return;
        prober.running = true;
    }

    // One call for both questions. `where` prints the path whether or not
    // anything is there yet, which is what lets the not-installed row say where
    // it WOULD go; `status --quiet` says nothing and answers in its exit code,
    // which is echoed rather than read off the Process because a non-zero exit
    // from a pipeline is a failure to Quickshell and a fact to us.
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

    // The two things a row can ask for. Both re-probe when they finish, so the
    // page never shows the state it had before the button was pressed.
    Process {
        id: actor

        // The exit code is not read on purpose. `install` and `remove` both
        // print what they did and the probe that follows says what is true now,
        // which is a better answer than a number: a partial install (the file
        // written, the startup line not) is a real outcome and the probe is what
        // notices it.
        onExited: (code, status) => {
            root.busy = false;
            root.probe();
        }
    }

    // A path with the home folded back to `~`, which is how anyone would write
    // it and half the width of the literal one.
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

    // ------------------------------------------------------------- the rows

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.small / 2

        // The quiet eyebrow the other pages open with, saying the thing the
        // rows below cannot: this is not a list the shell keeps, it is read out
        // of the CLI every time it is built, so it cannot be missing a verb the
        // CLI has.
        StyledText {
            width: list.width
            wrapMode: Text.WordWrap
            text: "Generated from the CLI itself, so it offers every verb banditshell has and none it does not."
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
        }

        // THE BUTTON. One row, three things it can say, and the same action
        // behind all of them: build it from the CLI as it stands and put it
        // where zsh looks. Pressing it when everything is already current is
        // not a no-op you have to explain, it is the rebuild, which is exactly
        // what somebody who does not trust the automatic one wants.
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

            // The state as a mark rather than a second sentence, in the shell's
            // colour for state that is genuinely worth a colour. A dot is
            // enough: the row already says the words, and this is what you see
            // from across the page.
            // NO ANCHORS. MenuRow's trailing slot is already centred in the
            // row and takes its height from what is put in it, so a child that
            // anchors its own centre to the slot makes the slot's height depend
            // on a position that depends on the slot's height. Qt calls that a
            // binding loop and draws the row a pixel wrong forever.
            G2Rect {
                width: Appearance.font.size.small
                height: width
                radius: width / 2
                visible: root.state >= 0 && !root.busy
                color: root.state === 0 ? Appearance.colour.accent : Appearance.colour.textFaint
            }
        }

        // WHERE IT WENT. Not a row, because there is nothing to press: it is
        // the answer to "did that do anything", and a path is the only form of
        // that answer worth printing. Shown only once there is a file at it,
        // and as the DIRECTORY: the file is always called _banditshell, because
        // zsh requires it to be, so the leaf carries no information and its
        // eleven characters are what pushed the line onto a second row.
        StyledText {
            width: list.width
            visible: root.state === 0 || root.state === 1
            text: root.short(root.dir)
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            topPadding: Appearance.padding.small / 2
            bottomPadding: Appearance.padding.small
        }

        // THE WAY BACK, and it only exists when there is something to go back
        // from. A "remove" row on a machine where nothing was installed is a
        // button that does nothing, sitting under the button that would have
        // given it something to do.
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

        // The rule the appearance page uses to say "different question below".
        Item {
            width: list.width
            height: Appearance.padding.large

            Separator {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
            }
        }

        // WHY THERE IS NOTHING ELSE ON THIS PAGE, which is worth a line rather
        // than an absence: the interesting property of this completion is that
        // it maintains itself, and a page full of controls for keeping it fresh
        // would be a page arguing with its own design.
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
