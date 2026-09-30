pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/usage.json`

    property bool loaded: false

    property bool keep: true

    property var spans: []

    property var current: null

    property double lastBeat: 0

    property int sinceSave: 0

    signal changed

    property int revision: 0

    readonly property int tickMs: 60 * 1000

    readonly property real napMs: root.tickMs * 3

    readonly property int saveEvery: 5

    readonly property int keepDays: 400

    readonly property double dayMs: 24 * 60 * 60 * 1000

    function forDay(day: date): var {

        const live = root.revision;
        const from = new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime();
        const to = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1).getTime();
        let sessions = 0;
        let ms = 0;
        for (const sp of root.spans) {

            if (sp.e < from || sp.s >= to)
                continue;
            sessions += 1;
            ms += Math.min(sp.e, to) - Math.max(sp.s, from);
        }
        return {
            sessions,
            minutes: Math.round(ms / 60000)
        };
    }

    function prune(now: double): void {
        const horizon = now - root.keepDays * root.dayMs;
        if (root.spans.length > 0 && root.spans[0].e < horizon)
            root.spans = root.spans.filter(sp => sp.e >= horizon);
    }

    function absorb(disk: var): void {
        const known = new Map();
        for (const sp of root.spans)
            known.set(sp.s, sp);

        let news = false;
        for (const sp of disk) {
            const mine = known.get(sp.s);
            if (!mine) {
                root.spans.push(sp);
                known.set(sp.s, sp);
                news = true;
            } else if (sp.e > mine.e) {
                mine.e = sp.e;
                news = true;
            }
        }

        if (!news)
            return;

        root.spans.sort((a, b) => a.s - b.s);
        root.revision += 1;
        root.changed();
    }

    function save(): void {
        if (!root.loaded || !root.keep)
            return;
        store.setText(JSON.stringify(root.spans) + "\n");
    }

    function begin(): void {
        const now = Date.now();
        root.prune(now);
        root.openSpan(now);
        root.lastBeat = now;
        root.loaded = true;
        root.save();
        root.revision += 1;
        root.changed();
    }

    function openSpan(now: double): void {
        const span = {
            s: now,
            e: now
        };
        root.spans.push(span);
        root.current = span;
    }

    function beat(): void {
        const now = Date.now();

        const current = root.current;
        if (now - root.lastBeat > root.napMs) {
            current.e = root.lastBeat;
            root.prune(now);
            root.openSpan(now);
            root.sinceSave = 0;
            root.save();
        } else {
            current.e = now;
            root.sinceSave += 1;
            if (root.sinceSave >= root.saveEvery) {
                root.sinceSave = 0;
                root.save();
            }
        }
        root.lastBeat = now;
        root.revision += 1;
        root.changed();
    }

    Timer {
        interval: root.tickMs

        running: root.loaded
        repeat: true
        onTriggered: root.beat()
    }

    FileView {
        id: store

        path: root.path

        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            let disk = [];
            try {
                const data = JSON.parse(text());

                disk = (Array.isArray(data) ? data : []).filter(sp => sp && typeof sp.s === "number" && typeof sp.e === "number" && sp.e >= sp.s).sort((a, b) => a.s - b.s);
            } catch (e) {

                if (root.loaded)
                    return;

                console.warn(`Usage: ${root.path} is not valid JSON; tracking this session in memory only and leaving the file alone.`, e);
                root.keep = false;
            }

            if (root.loaded)
                return root.absorb(disk);

            root.spans = disk;

            Qt.callLater(root.begin);
        }

        onLoadFailed: err => {

            if (root.loaded)
                return;

            if (err === FileViewError.FileNotFound) {
                mkdir.running = true;
            } else {
                console.warn(`Usage: could not read ${root.path} (${err}); tracking this session in memory only.`);
                root.keep = false;
                root.begin();
            }
        }
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir]
        onExited: root.begin()
    }
}
