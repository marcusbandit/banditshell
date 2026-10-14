pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/modes.json`

    property bool loaded: false

    property bool keep: true

    property string current: "none"

    property string icon: ""

    property var was: ({})

    readonly property bool active: root.current !== "none"

    function enter(id: string, icon: string, was: var): void {
        root.current = id;
        root.icon = id === "none" ? "" : icon;
        root.was = id === "none" ? {} : was;
        root.save();
    }

    function adopt(id: string, icon: string, was: var): bool {
        if (!root.loaded || root.active || !id || id === "none")
            return false;
        root.enter(id, icon, was ?? {});
        return true;
    }

    function save(): void {
        if (!root.keep)
            return;
        store.setText(JSON.stringify({
            current: root.current,
            icon: root.icon,
            was: root.was
        }, null, 2) + "\n");
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.current = typeof data.current === "string" && data.current ? data.current : "none";
                root.icon = typeof data.icon === "string" ? data.icon : "";
                root.was = data.was && typeof data.was === "object" ? data.was : {};
            } catch (e) {
                console.warn(`Modes: ${root.path} is not valid JSON; no mode is on and the file is left alone.`);
                root.keep = false;
            }
            root.loaded = true;
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound) {
                console.warn(`Modes: could not read ${root.path} (${err}); a mode set now will not be kept.`);
                root.keep = false;
            }
            root.loaded = true;
        }
    }
}
