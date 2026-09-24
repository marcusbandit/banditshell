import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.components
import "components/vt.js" as Vt

// The terminal VIEW alone, fed a recorded byte stream. No shell, no browser:
// when a terminal looks wrong this says whether the emulator or the drawing is
// at fault, and they are very different repairs.
ShellRoot {
    id: root

    property var term: null
    property int rev: 0

    FloatingWindow {
        id: win

        title: "banditshell-termprobe"
        color: Appearance.colour.surfaceSolid
        implicitWidth: 1400
        implicitHeight: 800

        TerminalView {
            anchors.fill: parent
            term: root.term
            revision: root.rev
            focused: false
        }
    }

    Process {
        id: reader

        running: true
        command: ["cat", Quickshell.env("TERM_PROBE_FILE") ?? "/tmp/btop.raw"]

        stdout: StdioCollector {
            onStreamFinished: {
                root.term = Vt.create(190, 45, {
                    palette: Appearance.colour.terminalPalette,
                    foreground: String(Appearance.colour.text),
                    background: String(Appearance.colour.surfaceSolid)
                });
                // StdioCollector hands back a QString, so the bytes have already
                // been through a codec; good enough to look at a picture with.
                root.term.write(text);
                root.rev = root.term.revision;
            }
        }
    }
}
