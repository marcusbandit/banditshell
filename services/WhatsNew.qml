pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "whatsnew.js" as WhatsNewLog

Singleton {
    id: root

    readonly property string path: `${Quickshell.shellDir}/docs/whats-new.json`
    readonly property string seenPath: `${Config.stateDir}/whats-new-seen`

    property var entries: []

    property bool checked: false
    property bool seenChecked: false
    property string stored: ""

    readonly property string legacy: Config.loaded ? (Config.values.updates.seen ?? "") : ""
    readonly property string seen: WhatsNewLog.lastSeen(root.stored, root.legacy)

    readonly property bool ready: Config.loaded && root.checked && root.seenChecked

    readonly property bool firstRun: Config.fresh && root.seen === ""

    readonly property var pending: root.firstRun ? [] : WhatsNewLog.accumulated(root.entries, root.seen)

    onReadyChanged: root.settle()
    Component.onCompleted: root.settle()

    function settle(): void {
        if (!root.ready)
            return;
        if (root.firstRun)
            return root.markSeen(WhatsNewLog.accumulated(root.entries, "")[0]?.id ?? "");
        const old = WhatsNewLog.legacyToMove(root.stored, root.legacy);
        if (old !== "")
            root.keep(old);
        else if (root.legacy !== "")
            Config.set("updates.seen", "");
    }

    function keep(id: string): void {
        root.stored = id;
        store.setText(`${id}\n`);
        if (root.legacy !== "")
            Config.set("updates.seen", "");
    }

    function markSeen(id: string): void {
        if (!root.ready || !id || id === root.seen)
            return;
        root.keep(id);
    }

    function severityOf(entry: var): string {
        return WhatsNewLog.severityOf(entry);
    }

    FileView {
        id: store

        path: root.seenPath
        printErrors: false

        onLoaded: {
            root.stored = WhatsNewLog.readSeen(store.text());
            root.seenChecked = true;
        }
        onLoadFailed: root.seenChecked = true
    }

    FileView {
        id: file

        path: root.path
        preload: true
        watchChanges: true
        printErrors: false

        onFileChanged: file.reload()
        onLoaded: {
            root.entries = WhatsNewLog.parse(file.text());
            root.checked = true;
        }
        onLoadFailed: root.checked = true
    }
}
