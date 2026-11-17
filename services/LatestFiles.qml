pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "latest-files.js" as Logic

Singleton {
    id: root

    readonly property string extraFolders: String(Config.values.launcher.latest?.screenshotFolders ?? "")
    readonly property var folders: ({
            screenshots: [String(Config.values.picker.dir ?? `${UserFolders.pictures}/Screenshots`)].concat(root.extraFolders.split(",")).map(d => d.trim().replace(/^~(?=\/|$)/, System.home).replace(/(.)\/+$/, "$1")).filter((d, i, all) => d && all.indexOf(d) === i),
            downloads: [Downloads.dir || UserFolders.downloads]
        })
    readonly property var patterns: ({
            screenshots: ["-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp"],
            downloads: ["-type", "f", "-o", "-type", "d"]
        })
    readonly property int keep: 200

    property var lists: ({})
    property var readAt: ({})
    property string owed: ""

    property var texts: ({})
    property string textOwed: ""
    property string tesseract: ""
    readonly property string textsPath: `${Config.cacheDir}/screenshot-text.json`
    readonly property int textBatch: 8
    readonly property int textReach: 60

    function readTexts(files: var): void {
        files = files.filter(f => root.texts[f.path]?.m !== f.modified);
        if (!files.length)
            return;
        if (root.tesseract === "") {
            root.pendingFiles = files;
            if (!prober.running)
                prober.running = true;
            return;
        }
        if (root.tesseract === "no")
            return;
        if (root.reading) {
            root.pendingFiles = files;
            return;
        }
        root.reading = true;
        const batch = files.slice(0, root.textBatch);
        const stamps = {};
        for (const file of batch)
            stamps[file.path] = file.modified;
        reader.modified = stamps;
        reader.code = -1;
        reader.heard = false;
        reader.command = ["nice", "-n", "19", "sh", "-c", 'for f; do printf "%s\\t" "$f"; timeout 30 tesseract "$f" - 2>/dev/null | tr "\\n\\t\\r" "   " | head -c 3000; printf "\\n"; done', "sh"].concat(batch.map(f => f.path));
        reader.running = true;
    }

    property var pendingFiles: []
    property bool reading: false

    function readFinished(output: string, stamps: var): void {
        root.takeTexts(output, stamps);
        root.reading = false;
        const next = root.pendingFiles;
        root.pendingFiles = [];
        root.readTexts(next);
    }

    function takeTexts(output: string, stamps: var): void {
        const next = Object.assign({}, root.texts);
        for (const line of output.split("\n")) {
            const cut = line.indexOf("\t");
            if (cut < 0)
                continue;
            const path = line.slice(0, cut);
            if (stamps[path] === undefined)
                continue;
            next[path] = {
                m: stamps[path],
                t: line.slice(cut + 1).replace(/\s+/g, " ").trim()
            };
        }
        for (const path of Object.keys(stamps))
            if (next[path] === undefined)
                next[path] = {
                    m: stamps[path],
                    t: ""
                };
        const keys = Object.keys(next);
        for (let i = 0; i < keys.length - 500; i++)
            delete next[keys[i]];
        root.texts = next;
        saving.restart();
    }

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
        lister.command = ["sh", "-c", 'dirs=$1; keep=$2; shift 2; printf "%s\\n" "$dirs" | while IFS= read -r dir; do [ -d "$dir" ] && find "$dir" -mindepth 1 -maxdepth 1 \\( "$@" \\) -printf "%T@\\t%y\\t%p\\n"; done | sort -rn | head -n "$keep"', "sh", root.folders[key].join("\n"), String(root.keep)].concat(root.patterns[key]);
        lister.running = true;
    }

    function copy(path: string, picture: bool): void {
        Clipboard.copy(picture ? {
            file: path
        } : {
            paths: [path]
        });
    }

    function paste(path: string, address: string): void {
        Clipboard.copy({
            file: path
        });
        Typist.paste(address);
    }

    function edit(path: string): void {
        const editor = String(Config.values.picker.editor ?? "").trim();
        if (editor)
            Quickshell.execDetached(["sh", "-c", `${editor} "$1"`, "sh", path]);
        else
            Quickshell.execDetached(["xdg-open", path]);
    }

    Process {
        id: prober

        command: ["sh", "-c", "command -v tesseract >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.tesseract = text.trim() === "yes" ? "yes" : "no";
                if (root.tesseract === "yes") {
                    const next = root.pendingFiles;
                    root.pendingFiles = [];
                    root.readTexts(next);
                }
            }
        }
    }

    Process {
        id: reader

        property var modified: ({})
        property int code: -1
        property bool heard: false
        property string output: ""

        function settle(): void {
            if (reader.code < 0 || !reader.heard)
                return;
            const text = reader.output;
            reader.code = -1;
            reader.heard = false;
            root.readFinished(text, reader.modified);
        }

        stdout: StdioCollector {
            onStreamFinished: {
                reader.output = text;
                reader.heard = true;
                reader.settle();
            }
        }

        onExited: code => {
            reader.code = code;
            reader.settle();
        }
    }

    Timer {
        id: saving

        interval: 3000
        onTriggered: memory.save(JSON.stringify(root.texts))
    }

    PrivateFile {
        id: memory

        path: root.textsPath

        onLoaded: text => {
            try {
                const kept = JSON.parse(text);
                root.texts = Object.assign({}, kept, root.texts);
            } catch (e) {}
        }
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
