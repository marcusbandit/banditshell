pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "whatsnew.js" as WhatsNewLog

Singleton {
    id: root

    readonly property string path: `${Quickshell.shellDir}/docs/whats-new.json`

    property var entries: []

    property bool checked: false

    readonly property bool ready: Config.loaded && root.checked

    readonly property var pending: WhatsNewLog.accumulated(root.entries, Config.values.updates.seen)

    function markSeen(id: string): void {
        if (!Config.loaded || !id || id === Config.values.updates.seen)
            return;
        Config.set("updates.seen", id);
    }

    function severityOf(entry: var): string {
        return WhatsNewLog.severityOf(entry);
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
