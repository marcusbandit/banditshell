pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "usage-apps.js" as Days

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/usage-apps.json`

    property bool loaded: false

    property bool keep: true

    property var days: ({})

    property int revision: 0

    property string focusedClass: ""

    property double since: 0

    property int sinceSave: 0

    property string lastWritten: ""

    readonly property int saveEvery: 5

    readonly property int echoAfterSave: 500
    readonly property int echoWhileSaving: 5000

    readonly property string activeClass: Hypr.classOf(Hypr.activeClient)

    function appsFor(day: date): var {
        const live = root.revision;
        return Days.top(root.days, Days.dayKey(day));
    }

    function settle(counting: bool): void {
        const now = Date.now();
        const elapsed = now - root.since;
        root.since = now;
        if (!root.loaded || !counting || !root.focusedClass || elapsed > Usage.napMs)
            return;
        root.days = Days.credit(root.days, Days.dayKey(new Date(now)), root.focusedClass, elapsed);
        root.revision += 1;
    }

    function follow(): void {
        root.settle(!Idle.idle);
        root.focusedClass = root.activeClass;
    }

    function beat(): void {
        root.settle(!Idle.idle);
        root.days = Days.prune(root.days, new Date());
        root.sinceSave += 1;
        if (root.sinceSave >= root.saveEvery) {
            root.sinceSave = 0;
            root.save();
        }
    }

    function save(): void {
        if (!root.loaded || !root.keep)
            return;
        const text = JSON.stringify(root.days) + "\n";
        if (text === root.lastWritten)
            return;
        root.lastWritten = text;
        if (text === store.text())
            return;
        echoQuiet.interval = root.echoWhileSaving;
        echoQuiet.restart();
        store.setText(text);
    }

    function begin(): void {
        root.since = Date.now();
        root.focusedClass = root.activeClass;
        root.loaded = true;
        root.revision += 1;
    }

    onActiveClassChanged: root.follow()

    Connections {
        target: Idle

        function onIdleChanged(): void {
            if (Idle.idle)
                root.settle(true);
            else
                root.since = Date.now();
        }
    }

    Connections {
        target: Usage

        function onChanged(): void {
            root.beat();
        }
    }

    Component.onDestruction: root.save()

    Timer {
        id: echoQuiet
    }

    FileView {
        id: store

        path: root.path

        watchChanges: true
        printErrors: false

        onFileChanged: if (!echoQuiet.running)
            reload()

        onSaved: {
            echoQuiet.interval = root.echoAfterSave;
            echoQuiet.restart();
        }

        onSaveFailed: {
            echoQuiet.stop();
            root.lastWritten = "";
        }

        onLoaded: {
            let disk = {};
            try {
                disk = Days.sanitise(JSON.parse(text()));
            } catch (e) {
                if (root.loaded)
                    return;
                console.warn(`UsageApps: ${root.path} is not valid JSON; counting this session in memory only and leaving the file alone.`, e);
                root.keep = false;
            }

            if (root.loaded) {
                const merged = Days.merge(root.days, disk);
                if (!Days.same(merged, root.days)) {
                    root.days = merged;
                    root.revision += 1;
                }
                return;
            }

            root.days = Days.prune(disk, new Date());
            Qt.callLater(root.begin);
        }

        onLoadFailed: err => {
            if (root.loaded)
                return;
            if (err !== FileViewError.FileNotFound) {
                console.warn(`UsageApps: could not read ${root.path} (${err}); counting this session in memory only.`);
                root.keep = false;
            }
            root.begin();
        }
    }
}
