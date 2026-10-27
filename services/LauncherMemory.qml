pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "launcher-memory.js" as Memory

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/launcher-rows.json`
    readonly property int keep: 400

    property var usage: ({})

    function scoreOf(key: string, now: real): real {
        return Memory.scoreOf(root.usage, key, now, (from, to) => Apps.decay(from, to));
    }

    function bonusOf(key: string, now: real): real {
        const used = root.scoreOf(key, now);
        return used > 0 ? Math.min(1, Math.log(1 + used) / 2) : 0;
    }

    readonly property var passing: /^(?:app|cli|suggest|output|scriptline|process|window|link|translation|video|newnote|latest|clipboard|notification|thread|definition|stream|answer|fallback|content|file|reminder|timer|zone|convert|developer|scriptitem|scriptproblem|place|github|port):/

    function remembers(key: string): bool {
        return !!key && key.length <= 80 && !root.passing.test(key);
    }

    function forget(key: string): void {
        if (!root.usage[key])
            return;
        const next = Object.assign({}, root.usage);
        delete next[key];
        root.usage = next;
        store.setText(JSON.stringify(next));
    }

    function record(key: string): void {
        if (!root.remembers(key))
            return;
        const next = Memory.record(root.usage, key, Date.now(), root.keep, (from, to) => Apps.decay(from, to));
        root.usage = next;
        store.setText(JSON.stringify(next));
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.usage = data && typeof data === "object" && !Array.isArray(data) ? data : {};
            } catch (e) {
                root.usage = {};
            }
        }
    }
}
