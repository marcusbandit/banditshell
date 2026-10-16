pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "screenshots.js" as Logic

Singleton {
    id: root

    readonly property string folder: String(Config.values.picker.dir ?? "~/Pictures/Screenshots").replace(/^~(?=\/|$)/, Files.home)
    readonly property int keep: 200

    property var shots: []
    property double readAt: 0
    property bool owed: false

    function refresh(): void {
        if (Date.now() - root.readAt < 5000)
            return;
        if (lister.running) {
            root.owed = true;
            return;
        }
        root.readAt = Date.now();
        lister.command = ["sh", "-c", '[ -d "$1" ] || exit 0; find "$1" -maxdepth 1 -type f \\( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \\) -printf "%T@\\t%p\\n" | sort -rn | head -n "$2"', "sh", root.folder, String(root.keep)];
        lister.running = true;
    }

    function copy(path: string): void {
        Clipboard.copy({
            file: path
        });
    }

    function edit(path: string): void {
        const editor = String(Config.values.picker.editor ?? "").trim();
        if (editor)
            Quickshell.execDetached(["sh", "-c", `${editor} "$1"`, "sh", path]);
        else
            Quickshell.execDetached(["xdg-open", path]);
    }

    Process {
        id: lister

        stdout: StdioCollector {
            onStreamFinished: root.shots = Logic.readListing(this.text)
        }

        onRunningChanged: {
            if (!lister.running && root.owed) {
                root.owed = false;
                root.readAt = 0;
                root.refresh();
            }
        }
    }
}
