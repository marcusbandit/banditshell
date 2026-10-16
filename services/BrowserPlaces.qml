pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "browsing.js" as Browsing

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.online ?? {}).browser !== false

    readonly property string file: `${Config.cacheDir}/browser-places.json`
    readonly property string icons: `${Config.cacheDir}/favicons`
    readonly property real restFor: 3 * 60 * 1000

    property var places: []
    property real readAt: 0
    property bool woken: false

    function wake(): void {
        if (!root.enabled)
            return;
        root.woken = true;
        if (reader.running || Date.now() - root.readAt < root.restFor)
            return;
        root.readAt = Date.now();
        reader.running = true;
    }

    Process {
        id: reader

        command: ["python3", "-I", `${Quickshell.shellDir}/scripts/browser-places.py`, root.file, root.icons]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "unchanged")
                store.reload()
        }
    }

    FileView {
        id: store

        path: root.woken ? root.file : ""
        printErrors: false
        onLoaded: {
            try {
                root.places = Browsing.prepare(JSON.parse(text()));
            } catch (e) {}
        }
    }
}
