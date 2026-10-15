pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string path: Quickshell.env("XDG_RUNTIME_DIR") ? `${Quickshell.env("XDG_RUNTIME_DIR")}/banditshell-relaunch.json` : `/tmp/banditshell-relaunch-${Quickshell.env("USER") ?? "user"}.json`

    readonly property string owner: `${Date.now()}-${Math.random().toString(36).slice(2)}`

    property var live: null
    property var recalled: ({})
    property bool retired: false

    function read(): var {
        try {
            const data = JSON.parse(store.text());
            return data && typeof data === "object" ? data : {};
        } catch (e) {
            return {};
        }
    }

    function remembered(): var {
        if (root.live === null) {
            root.live = root.read();
            root.write();
        }
        return root.live;
    }

    function recall(key: string): var {
        root.recalled[key] = true;
        return root.remembered()[key] ?? null;
    }

    function keep(key: string, value: var): void {
        if (!root.recalled[key])
            return;
        const next = Object.assign({}, root.remembered());
        next[key] = value;
        root.live = next;
        writer.restart();
    }

    function write(): void {
        store.setText(JSON.stringify(Object.assign({}, root.live, {
            owner: root.owner
        })) + "\n");
    }

    Timer {
        id: writer

        interval: 250
        onTriggered: {
            if (root.retired)
                return;
            store.reload();
            const owner = root.read().owner;
            if (owner && owner !== root.owner)
                root.retired = true;
            else
                root.write();
        }
    }

    FileView {
        id: store

        path: root.path
        blockLoading: true
        blockWrites: true
        printErrors: false
    }
}
