pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/desktop-widgets.json`

    property bool loaded: false
    property bool keep: true
    property var places: ({})
    property var sizes: ({})

    function placeOf(output: string, key: string): var {
        return root.places[output]?.[key] ?? null;
    }

    function place(output: string, key: string, where: var): void {
        const screen = Object.assign({}, root.places[output] ?? {});
        screen[key] = {
            side: where.side,
            edge: where.edge,
            x: Math.round(where.x),
            y: Math.round(where.y)
        };
        root.places = Object.assign({}, root.places, {
            [output]: screen
        });
        root.save();
    }

    function forget(output: string, key: string): void {
        if (!root.places[output]?.[key])
            return;
        const screen = Object.assign({}, root.places[output]);
        delete screen[key];
        root.places = Object.assign({}, root.places, {
            [output]: screen
        });
        root.save();
    }

    function sizeOf(key: string, fallback: string): string {
        return root.sizes[key] ?? fallback;
    }

    function resize(key: string, size: string): void {
        if (root.sizes[key] === size)
            return;
        root.sizes = Object.assign({}, root.sizes, {
            [key]: size
        });
        root.save();
    }

    function save(): void {
        if (!root.loaded || !root.keep)
            return;
        store.setText(JSON.stringify({
            places: root.places,
            sizes: root.sizes
        }, null, 4) + "\n");
    }

    function adopt(disk: var): void {
        if (root.loaded)
            return;
        const clean = value => value !== null && typeof value === "object" && !Array.isArray(value) ? value : {};
        root.places = clean(disk?.places);
        root.sizes = clean(disk?.sizes);
        root.loaded = true;
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            let disk = null;
            try {
                disk = JSON.parse(text());
            } catch (e) {
                console.warn(`DesktopLayout: ${root.path} is not valid JSON; widgets keep their places only until a restart.`, e);
                root.keep = false;
            }
            root.adopt(disk);
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound) {
                console.warn(`DesktopLayout: could not read ${root.path} (${err}); widget places will not be kept.`);
                root.keep = false;
            }
            root.adopt(null);
        }
    }
}
