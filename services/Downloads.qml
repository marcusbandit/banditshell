pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property bool enabled: Config.values.island.downloads

    property string dir: ""
    property bool watchable: false

    readonly property var partial: /\.(part|crdownload|download|partial|tmp|filepart|opdownload|aria2|!qb)$/i

    property var candidates: []

    readonly property bool wanted: root.enabled && root.watchable && root.dir !== ""

    signal arrived(var names, string dir)

    function saw(line: string): void {
        const cut = line.indexOf("|");
        if (cut < 0)
            return;
        const events = line.slice(0, cut);
        const name = line.slice(cut + 1);
        if (!name || events.includes("ISDIR") || name.startsWith(".") || root.partial.test(name))
            return;
        if (!root.candidates.includes(name))
            root.candidates = [...root.candidates, name];
        settle.restart();
    }

    function confirm(): void {
        if (confirmer.running || root.candidates.length === 0)
            return;
        const names = root.candidates;
        root.candidates = [];
        confirmer.command = ["sh", "-c", `
            cd -- "$1" || exit 0
            shift
            for f; do
                [ -f "$f" ] && [ -s "$f" ] || continue
                for tail in part crdownload download partial; do
                    [ -e "$f.$tail" ] && continue 2
                done
                printf '%s\\n' "$f"
            done
        `, "sh", root.dir, ...names];
        confirmer.running = true;
    }

    Process {
        id: finder

        running: true
        command: ["sh", "-c", `
            dir=$(xdg-user-dir DOWNLOAD 2>/dev/null)
            if [ -z "$dir" ] || [ "$dir" = "$HOME" ]; then
                dir="$HOME/Downloads"
            fi
            [ -d "$dir" ] && printf 'dir=%s\\n' "$dir"
            command -v inotifywait >/dev/null 2>&1 && echo watch=1
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    if (line.startsWith("dir="))
                        root.dir = line.slice(4);
                    else if (line === "watch=1")
                        root.watchable = true;
                }
                if (root.dir && !root.watchable)
                    console.info("Downloads: inotifywait is not installed (inotify-tools), so finished downloads are not announced.");
            }
        }
    }

    Loader {
        id: watch

        active: root.wanted

        sourceComponent: Process {
            running: true
            command: ["inotifywait", "-m", "-q", "-e", "close_write", "-e", "moved_to", "--format", "%e|%f", "--", root.dir]

            stdout: SplitParser {
                onRead: line => root.saw(line)
            }

            onExited: lost.restart()
        }
    }

    Timer {
        id: lost

        interval: 10000
        onTriggered: {
            watch.active = false;
            watch.active = Qt.binding(() => root.wanted);
        }
    }

    Timer {
        id: settle

        interval: 1500
        onTriggered: root.confirm()
    }

    Process {
        id: confirmer

        stdout: StdioCollector {
            onStreamFinished: {
                const names = text.split("\n").filter(n => n);
                if (names.length > 0)
                    root.arrived(names, root.dir);
                if (root.candidates.length > 0)
                    settle.restart();
            }
        }
    }
}
