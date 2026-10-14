pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string path: `${root.home}/.local/share/gvoice/history.json`

    readonly property string cli: `${root.home}/bin/voice`

    property var entries: []

    property bool loaded: false

    property bool present: false

    readonly property string socketPath: `${root.home}/.local/share/gvoice/events.sock`

    property string phase: "idle"
    property string lang: "auto"

    readonly property bool live: root.phase !== "idle"

    readonly property string langTag: root.lang === "auto" ? "" : root.lang.startsWith("en") ? "EN" : root.lang.startsWith("da") ? "DK" : root.lang.startsWith("ja") ? "JP" : root.lang.split(/[-_]/)[0].toUpperCase()

    readonly property int levelCount: 64
    property var levels: []

    function quiet(): void {
        const blank = [];
        for (let i = 0; i < root.levelCount; i++)
            blank.push(0);
        root.levels = blank;
    }

    function heard(level: real): void {
        const next = root.levels.slice(1);
        next.push(level);
        root.levels = next;
    }

    onPhaseChanged: if (root.phase === "listening")
        root.quiet()

    Component.onCompleted: root.quiet()

    Loader {
        id: events

        active: true
        sourceComponent: eventSocket

        readonly property bool up: item?.connected ?? false

        onUpChanged: if (!up) {
            root.phase = "idle";
            root.quiet();
        }
    }

    Component {
        id: eventSocket

        Socket {
            path: root.socketPath
            connected: true

            parser: SplitParser {
                splitMarker: "\n"
                onRead: line => {
                    let msg;
                    try {
                        msg = JSON.parse(line);
                    } catch (e) {
                        return;
                    }
                    if (msg.phase !== undefined)
                        root.phase = msg.phase;
                    if (msg.lang !== undefined)
                        root.lang = msg.lang;
                    if (msg.level !== undefined && root.phase === "listening")
                        root.heard(msg.level);
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: !events.up
        repeat: true
        onTriggered: {
            events.active = false;
            events.active = true;
        }
    }

    function shape(e: var): var {
        return {
            id: e.id,
            kind: "speech",
            text: e.text ?? "",
            recorded: (e.at ?? 0) * 1000,

            pinned: false
        };
    }

    readonly property int echoWindow: 15000

    function said(text: string): bool {
        const needle = (text ?? "").trim();
        if (!needle)
            return false;
        const cut = Date.now() - root.echoWindow;
        return root.entries.some(e => e.recorded >= cut && (e.text ?? "").trim() === needle);
    }

    function search(needle: string): var {
        if (!needle)
            return root.entries;
        return root.entries.filter(e => Clipboard.tier(e, needle) > Clipboard.tierNone);
    }

    function use(entry: var): void {
        if (!entry?.id)
            return;
        root.run(["use", entry.id]);
    }

    function drop(entry: var): void {
        if (!entry?.id)
            return;

        root.entries = root.entries.filter(e => e.id !== entry.id);
        root.run(["drop", entry.id]);
    }

    function run(args: var): void {
        poke.command = [root.cli, ...args];
        poke.running = true;
    }

    Process {
        id: poke

        stderr: SplitParser {
            onRead: line => console.warn("Dictation:", line)
        }
    }

    FileView {
        id: store

        path: root.path

        watchChanges: true
        printErrors: false

        onLoaded: root.absorb(text())
        onFileChanged: reload()

        onLoadFailed: err => {
            root.loaded = true;
            root.present = false;
            root.entries = [];
            if (err !== FileViewError.FileNotFound)
                console.warn(`Dictation: could not read ${root.path} (${err}).`);

        }
    }

    function absorb(raw: string): void {
        root.loaded = true;
        let data;
        try {
            data = JSON.parse(raw);
        } catch (e) {
            console.warn("Dictation: history.json did not parse; showing nothing.");
            root.present = false;
            root.entries = [];
            return;
        }
        if (!Array.isArray(data)) {
            root.present = false;
            root.entries = [];
            return;
        }
        root.present = true;
        root.entries = data.filter(e => e && e.text).map(e => root.shape(e));
    }
}
