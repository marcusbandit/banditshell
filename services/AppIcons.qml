pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/appicons.json`

    readonly property string store: `${Quickshell.env("HOME")}/.local/share/banditshell/icons`

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

    function titleOf(cls: string): string {
        return root.apps[cls]?.title ?? "";
    }

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

    function assign(cls: string, spec: string): void {
        root.write(cls, {
            spec: spec ?? ""
        });
    }

    function forget(cls: string): void {
        const next = Object.assign({}, root.apps);
        delete next[cls];
        root.apps = next;
        root.save();
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

    property string asking: ""
    property string askResult: ""

    function ask(cls: string): void {
        if (!cls || root.asking)
            return;
        root.asking = cls;
        root.askResult = "";
        claude.cls = cls;
        claude.running = true;
    }

    Process {
        id: claude

        property string cls: ""

        command: {
            const name = root.titleOf(claude.cls) || claude.cls;
            const target = `${root.store}/${claude.cls.replace(/[^a-zA-Z0-9_.-]/g, "_")}.svg`;
            return Config.values.apps.claude.concat([`Find the official logo for the application "${name}" (window class "${claude.cls}") as an SVG, preferring a simple single-colour or monochrome version. Download it to exactly ${target}, creating directories as needed. Do not modify anything else on this machine. Print only that path as the last line of your reply, and nothing else if you fail.`]);
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").map(l => l.trim()).filter(l => l);
                const last = lines[lines.length - 1] ?? "";
                root.askResult = last.endsWith(".svg") ? last : "";
            }
        }

        onExited: (code, status) => {
            const cls = claude.cls;
            root.asking = "";
            if (!root.askResult) {
                console.warn(`AppIcons: asking Claude for ${cls} came back with nothing (exit ${code}).`);
                return;
            }

        }
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
                mkdir.running = true;
            else
                console.warn(`AppIcons: could not read ${root.path} (${err}); choices made now will not be kept.`);
        }
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir, root.store]
        onExited: root.loaded = true
    }
}
