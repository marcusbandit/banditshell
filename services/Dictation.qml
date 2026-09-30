pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string path: `${root.home}/.local/share/gvoice/history.json`

    readonly property string cli: `${root.home}/bin/voice`

    property var entries: []

    property bool loaded: false

    property bool present: false

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
