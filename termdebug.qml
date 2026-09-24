import QtQuick
import Quickshell
import qs.config
import qs.components
import Quickshell.Io
import qs.services

// THE TERMINAL, ALONE, and nothing else in the window.
//
// A debug mode rather than a feature: `banditshell termdebug` opens this beside
// a real kitty attached to the SAME tmux session, so both are showing the same
// bytes at the same size and any difference between them is a difference in
// this emulator. Kitty is the truth; this is the copy.
//
// Nothing here is the browser. No grid, no sidebar, no preview - a terminal that
// is wrong is easier to see when it is the only thing on screen, and a browser
// around it is a hundred other reasons a screenshot might differ.
ShellRoot {
    id: root

    FloatingWindow {
        id: win

        title: "banditshell-termdebug"
        color: Appearance.colour.surfaceSolid

        implicitWidth: 1200
        implicitHeight: 760

        Component.onCompleted: Files.ensureTerminal()

        TerminalView {
            id: view

            anchors.fill: parent
            anchors.margins: Appearance.padding.small

            term: Files.term
            revision: Files.revision
            focused: true

            onSend: bytes => Files.send(bytes)
            onResized: (cols, rows) => {
                Files.resizeTerminal(cols, rows);
                // WRITTEN DOWN so the comparison can open its kitty at exactly
                // this grid. tmux sizes a session to its smallest client, so a
                // mismatched second client changes the session itself and fills
                // the difference with its own filler - which looks precisely
                // like this emulator drawing dots it should not.
                grid.exec(["sh", "-c", `printf '%dx%d' ${cols} ${rows} > /tmp/banditshell-termdebug.grid`]);
            }

            Keys.onPressed: event => view.key(event)
            focus: true
        }

        // WHAT IT IS ATTACHED TO, written where a script can read it. The
        // comparison needs to point kitty at the same session, and polling
        // `tmux ls` for a name that looks like ours would find the wrong one the
        // moment two of these are open.
        Connections {
            target: Files

            function onTmuxSessionChanged(): void {
                if (Files.tmuxSession)
                    stamp.exec(["sh", "-c", `printf '%s' ${Files.quote(Files.tmuxSession)} > /tmp/banditshell-termdebug.session`]);
            }
        }
    }

    Process {
        id: stamp
    }

    Process {
        id: grid
    }
}
