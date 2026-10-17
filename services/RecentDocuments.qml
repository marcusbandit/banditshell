pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string file: `${Quickshell.env("XDG_DATA_HOME") || `${Quickshell.env("HOME")}/.local/share`}/recently-used.xbel`

    property string xbel: ""
    property string listing: ""
    property double readAt: 0
    property string checked: ""

    readonly property int staleMs: 3000

    function refresh(): void {
        if (Date.now() - root.readAt < root.staleMs)
            return;
        root.readAt = Date.now();
        reader.reload();
    }

    function check(paths: var): void {
        const signature = paths.join("\n");
        if (signature === root.checked)
            return;
        root.checked = signature;
        checker.running = false;
        checker.command = ["sh", "-c", 'for p in "$@"; do [ -e "$p" ] && printf "%s\\n" "$p"; done', "sh", ...paths];
        checker.running = true;
    }

    FileView {
        id: reader

        path: root.file
        watchChanges: false
        printErrors: false

        onLoaded: root.xbel = reader.text()
    }

    Process {
        id: checker

        stdout: StdioCollector {
            onStreamFinished: root.listing = text
        }
    }
}
