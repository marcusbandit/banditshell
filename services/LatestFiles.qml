pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "latest-files.js" as Logic

Singleton {
    id: root

    readonly property var folders: ({
            screenshots: String(Config.values.picker.dir ?? `${UserFolders.pictures}/Screenshots`).replace(/^~(?=\/|$)/, System.home),
            downloads: Downloads.dir || UserFolders.downloads
        })
    readonly property var patterns: ({
            screenshots: ["-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp"],
            downloads: ["-type", "f", "-o", "-type", "d"]
        })
    readonly property int keep: 200

    property var lists: ({})
    property var readAt: ({})
    property string owed: ""

    function refresh(key: string): void {
        if (Date.now() - (root.readAt[key] ?? 0) < 1000)
            return;
        if (lister.running) {
            root.owed = key;
            return;
        }
        root.readAt = Object.assign({}, root.readAt, {
            [key]: Date.now()
        });
        lister.key = key;
        lister.command = ["sh", "-c", 'dir=$1; keep=$2; shift 2; [ -d "$dir" ] || exit 0; find "$dir" -mindepth 1 -maxdepth 1 \\( "$@" \\) -printf "%T@\\t%y\\t%p\\n" | sort -rn | head -n "$keep"', "sh", root.folders[key], String(root.keep)].concat(root.patterns[key]);
        lister.running = true;
    }

    function copy(path: string, picture: bool): void {
        Clipboard.copy(picture ? {
            file: path
        } : {
            paths: [path]
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

        property string key: ""

        stdout: StdioCollector {
            onStreamFinished: root.lists = Object.assign({}, root.lists, {
                [lister.key]: Logic.readListing(this.text)
            })
        }

        onRunningChanged: {
            if (!lister.running && root.owed) {
                const key = root.owed;
                root.owed = "";
                root.refresh(key);
            }
        }
    }
}
