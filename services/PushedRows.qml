pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "pushed-rows.js" as Pushed

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/launcher-pushed-rows.json`

    property var store: Pushed.empty()

    property real now: Date.now()

    readonly property var rows: Pushed.rowsOf(Pushed.live(root.store, root.now), "")

    function keep(next: var): void {
        root.now = Date.now();
        root.store = next;
        file.setText(JSON.stringify(next, null, 2) + "\n");
        root.schedule();
    }

    function add(json: string): string {
        const read = Pushed.parseRow(json, Date.now());
        if (read.error)
            return `refused: ${read.error}`;
        root.keep(Pushed.added(Pushed.live(root.store, Date.now()), read.row));
        return `added ${read.row.tool}/${read.row.id}`;
    }

    function remove(tool: string, id: string): string {
        const out = Pushed.removed(Pushed.live(root.store, Date.now()), tool, id);
        if (!out.count)
            return id ? `no such row: ${tool}/${id}` : `no such tool: ${tool}`;
        root.keep(out.store);
        return out.count === 1 ? "removed 1 row" : `removed ${out.count} rows`;
    }

    function list(tool: string): string {
        return JSON.stringify(Pushed.rowsOf(Pushed.live(root.store, Date.now()), tool));
    }

    function rowFor(tool: string, id: string): var {
        return Pushed.rowsOf(Pushed.live(root.store, Date.now()), tool).find(r => r.id === id) ?? null;
    }

    function schedule(): void {
        const next = Pushed.nextExpiry(root.store);
        expiry.stop();
        if (next) {
            expiry.interval = Math.max(1000, Math.min(next - Date.now() + 50, 60000));
            expiry.start();
        }
    }

    Timer {
        id: expiry

        onTriggered: {
            root.now = Date.now();
            const next = Pushed.live(root.store, root.now);
            if (next !== root.store)
                root.keep(next);
            else
                root.schedule();
        }
    }

    FileView {
        id: file

        path: root.path
        blockLoading: true
        printErrors: false

        onLoaded: {
            root.store = Pushed.readStore(file.text(), Date.now());
            root.schedule();
        }
    }
}
