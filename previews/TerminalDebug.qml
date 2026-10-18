import QtQuick
import Quickshell
import qs.config
import qs.components
import Quickshell.Io
import qs.services

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
            zoom: Appearance.sizes.filesZoom
            face: Appearance.sizes.filesTerminalFont

            onSend: bytes => Files.send(bytes)
            onResized: (cols, rows) => {
                Files.resizeTerminal(cols, rows);

                grid.exec(["sh", "-c", 'printf "%dx%d" "$1" "$2" > "$XDG_RUNTIME_DIR/banditshell-termdebug.grid"', "sh", String(cols), String(rows)]);
            }

            Keys.onPressed: event => view.key(event)
            focus: true
        }

        Connections {
            target: Files

            function onTmuxSessionChanged(): void {
                if (Files.tmuxSession)
                    stamp.exec(["sh", "-c", 'printf "%s" "$1" > "$XDG_RUNTIME_DIR/banditshell-termdebug.session"', "sh", Files.tmuxSession]);
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
