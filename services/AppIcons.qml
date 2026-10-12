pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/appicons.json`

    property bool loaded: false

    property var apps: ({})

    property var fits: ({})

    function fitFor(path: string): var {
        return root.fits[path] ?? null;
    }

    function recordFit(path: string, box: var): void {
        if (!path || !box)
            return;

        if (path.startsWith("image://"))
            return;
        const next = Object.assign({}, root.fits);
        next[path] = box;
        root.fits = next;
        root.save();
    }

    readonly property var classes: Object.keys(root.apps).sort()

    function specFor(cls: string): string {
        return root.apps[cls]?.spec ?? "";
    }

    function save(): void {
        if (!root.loaded)
            return;
        store.setText(JSON.stringify({
            apps: root.apps,
            fits: root.fits
        }, null, 4) + "\n");
    }

    function write(cls: string, patch: var): void {
        if (!cls)
            return;
        const next = Object.assign({}, root.apps);
        next[cls] = Object.assign({}, next[cls] ?? {}, patch);
        root.apps = next;
        root.save();
    }

    function record(cls: string, title: string): void {
        const known = root.apps[cls];
        if (known && known.title)
            return;
        root.write(cls, {
            title: title ?? "",
            at: Date.now()
        });
    }

    readonly property var watching: Hypr.clients

    onWatchingChanged: root.observe()

    onLoadedChanged: if (root.loaded)
        Qt.callLater(root.observe)

    function observe(): void {
        if (!root.loaded)
            return;
        for (const id in root.watching)
            for (const c of root.watching[id]) {
                const o = c.lastIpcObject;
                root.record(o?.initialClass || o?.class || "", o?.initialTitle || o?.title || "");
            }
    }

    function markFor(cls: string, want: string): string {
        const picked = root.specFor(cls);
        if (picked)
            return picked;

        const named = Apps.overrideFor(cls);
        if (named)
            return `symbol:${named}`;

        const mode = want || Appearance.sizes.wsIconMode;

        if (mode === "colour") {
            const art = Apps.iconSourceFor([cls]);
            if (art)
                return `image:${art}`;
        }

        if (mode === "brand" || mode === "colour") {
            const drawn = Apps.drawnFor(cls);
            if (drawn)
                return `draw:${drawn}`;
        }

        if (mode === "brand") {
            const glyph = Apps.brandFor(cls);
            if (glyph)
                return `glyph:${glyph.codePointAt(0).toString(16)}`;
        }
        return "";
    }

    function isFile(spec: string): bool {
        return spec.startsWith("mono:") || spec.startsWith("image:");
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text()) ?? {};

                root.apps = data.apps ?? data ?? {};
                root.fits = data.fits ?? {};
                root.loaded = true;
            } catch (e) {
                console.warn(`AppIcons: ${root.path} is not valid JSON, starting the table over.`, e);
                root.apps = {};
                root.fits = {};
                root.loaded = true;
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.loaded = true;
            else
                console.warn(`AppIcons: could not read ${root.path} (${err}); choices made now will not be kept.`);
        }
    }
}
