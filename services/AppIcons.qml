pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// WHAT EACH APPLICATION IS DRAWN AS, and the record of which ones exist.
//
// Three jobs, all of them about the same table:
//
//   SEEN. Every window class that has ever been on this machine, with the last
//   title it had. A settings menu cannot offer to pick an icon for an
//   application it has never heard of, and the list of what you actually run is
//   not knowable from the desktop entries: half of them are things you have
//   never opened and the ones you live in may have no entry at all.
//
//   PICKED. What you chose for it, as a spec (see components/AppMark.qml).
//   Nothing else in the shell decides this: the automatic answer is a
//   suggestion, and a suggestion that cannot be overruled is a decision.
//
//   SUGGESTED. What is on this machine for a given application, found by looking
//   rather than by guessing: every icon file in every installed theme whose name
//   mentions it, which is where the alternatives come from. Telegram ships a
//   plane in a circle AND a bare plane AND a monochrome panel version, and which
//   of those belongs in this bar is a matter of taste, so all three are offered.
//
// Both tables live in one file under the state directory, because they are one
// answer to "what does this machine run and how should it look".
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/appicons.json`
    // Where a downloaded icon lands. Under `share`, not `state`: it is an asset
    // that is expensive to fetch again, not a record of what happened.
    readonly property string store: `${Quickshell.env("HOME")}/.local/share/banditshell/icons`

    // WHETHER THE FILE HAS BEEN READ YET, and the reason this exists: every
    // write is a write of the WHOLE table, and the table starts empty. The
    // window list arrives before the first read finishes, so recording what is
    // open used to overwrite the file with nothing but what was open, and every
    // icon anybody had ever chosen went with it. Nothing writes until the disk
    // has had its say.
    property bool loaded: false

    // { class: { title, spec, at } }
    property var apps: ({})

    // { path: [x, y, w, h] } normalised, what an icon file actually covers of
    // its own canvas. Measured once by components/FittedImage.qml and kept,
    // because a file does not change shape and scanning pixels is not free.
    property var fits: ({})

    function fitFor(path: string): var {
        return root.fits[path] ?? null;
    }

    function recordFit(path: string, box: var): void {
        if (!path || !box)
            return;
        // ONLY WHAT WILL STILL BE THERE TOMORROW. An image provider's url names
        // a live object rather than a file (`image://qsimage/0x...` is a tray
        // item's pixmap, and the address is different next session), so a
        // measurement filed under one can never be found again and the table
        // would grow by every icon in the tray on every boot. Measuring one is
        // a 64x64 scan; keeping a key that cannot match is a leak.
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

    // A NEW OBJECT, not a mutated one: `apps` is a var property and QML only
    // notices assignment, so mutating it in place leaves every binding reading
    // it showing the old table until something else happens to invalidate them.
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

    // FIRST SIGHT ONLY. A window's title changes every time you switch a tab,
    // and this table is on disk: recording every title would rewrite the file
    // several times a second for as long as a browser is open, to store a fact
    // nobody asked for. What is wanted is that the application EXISTS and a
    // human-readable name for it, and the first one is as good as any.
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

    // Watch what is open and remember it. A window that is never open when the
    // settings menu happens to be is still an application you use.
    readonly property var watching: Hypr.clients

    onWatchingChanged: root.observe()
    // Whatever was open before the file came back is still open now, and now
    // there is something to merge it into.
    onLoadedChanged: if (root.loaded)
        root.observe()

    function observe(): void {
        if (!root.loaded)
            return;
        for (const id in root.watching)
            for (const c of root.watching[id]) {
                const o = c.lastIpcObject;
                root.record(o?.initialClass || o?.class || "", o?.initialTitle || o?.title || "");
            }
    }

    // THE MARK a window gets, as a spec. One place, so the sidebar and the
    // settings menu can never disagree about what an application looks like.
    //
    // The order is the point: what you PICKED, then what the config named by
    // hand, then whatever the current mode can work out, then nothing, which
    // AppMark draws as the category glyph. Every step down is less specific and
    // more automatic.
    function markFor(cls: string): string {
        const picked = root.specFor(cls);
        if (picked)
            return picked;

        const named = Apps.overrideFor(cls);
        if (named)
            return `symbol:${named}`;

        const mode = Appearance.sizes.wsIconMode;
        if (mode === "brand") {
            const glyph = Apps.brandFor(cls);
            if (glyph)
                return `glyph:${glyph.codePointAt(0).toString(16)}`;
        }
        if (mode === "colour") {
            const art = Apps.iconSourceFor([cls]);
            if (art)
                return `image:${art}`;
        }
        return "";
    }

    function isFile(spec: string): bool {
        return spec.startsWith("mono:") || spec.startsWith("image:");
    }

    // Two specs that name the same FILE, whatever colour each asks for.
    function sameMark(a: string, b: string): bool {
        if (!a || !b)
            return false;
        return a === b || (root.isFile(a) && root.isFile(b) && a.slice(a.indexOf(":")) === b.slice(b.indexOf(":")));
    }

    // Flip the chosen file between the shell's colour and its own.
    function recolour(cls: string): void {
        const spec = root.specFor(cls);
        if (!root.isFile(spec))
            return;
        const path = spec.slice(spec.indexOf(":") + 1);
        root.assign(cls, `${spec.startsWith("mono:") ? "image" : "mono"}:${path}`);
    }

    // ------------------------------------------------------------------
    // Suggestions: what this machine already has for an application.

    // { class: [spec, ...] } once a scan has run for that class.
    property var found: ({})
    property string scanning: ""

    function suggest(cls: string): void {
        if (!cls || root.scanning === cls)
            return;
        root.scanning = cls;
        scan.needle = root.needleFor(cls);
        scan.cls = cls;
        scan.running = true;
    }

    // What to look for on disk. The window class with its reverse-DNS wrapping
    // taken off, because `org.telegram.desktop` never names a file and
    // `telegram` names a dozen.
    function needleFor(cls: string): string {
        const parts = cls.toLowerCase().split(".").filter(p => p);
        while (parts.length > 1 && ["desktop", "app", "gui", "client", "bin"].includes(parts[parts.length - 1]))
            parts.pop();
        return (parts[parts.length - 1] ?? cls).replace(/[^a-z0-9_-]/g, "");
    }

    // A file is MONOCHROME by convention, not by inspection: every icon theme
    // files its single-colour versions under `panel`, `status` or `symbolic`, or
    // names them so. Reading the SVG to find out would be more honest and much
    // slower, and the convention is near-universal.
    function monoLooking(path: string): bool {
        const p = path.toLowerCase();
        return p.includes("symbolic") || p.includes("/panel/") || p.includes("-panel") || p.includes("/status/");
    }

    Process {
        id: scan

        property string needle: ""
        property string cls: ""

        command: ["sh", "-c", `find /usr/share/icons /usr/share/pixmaps "$HOME/.local/share/icons" "${root.store}" -type f \\( -iname '*${needle}*.svg' -o -iname '*${needle}*.png' \\) 2>/dev/null | head -60`]

        stdout: StdioCollector {
            onStreamFinished: {
                // One entry per BASENAME. A theme ships the same icon at eight
                // sizes and there are four themes installed; that is thirty-two
                // paths and one choice.
                const seen = {};
                for (const line of text.split("\n")) {
                    const path = line.trim();
                    if (!path)
                        continue;
                    const base = path.slice(path.lastIndexOf("/") + 1).replace(/\.(svg|png)$/i, "");
                    const prev = seen[base];
                    // Prefer SVG, then the largest raster: a 16px icon blown up
                    // to 25 is a smear, and the picker is showing it at size.
                    const score = (path.endsWith(".svg") ? 1000 : 0) + (parseInt(path.match(/(\d+)x\1/)?.[1] ?? "0") || 0);
                    if (!prev || score > prev.score)
                        seen[base] = {
                            path,
                            score
                        };
                }

                // EVERY file is offered as a `mono`, whatever it is. The
                // alternatives are meant to be comparable, and five brand
                // palettes in a row are not comparable to each other or to the
                // rest of the bar; the picker has a switch for the ones you
                // want in their own colours.
                const specs = [];
                for (const base in seen)
                    specs.push(`mono:${seen[base].path}`);

                const next = Object.assign({}, root.found);
                next[scan.cls] = specs;
                root.found = next;
                root.scanning = "";
            }
        }
    }

    // ------------------------------------------------------------------
    // Ask Claude: when the machine has nothing good, go and find one.

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

        // The prompt is the whole interface to it: one file, one path printed,
        // nothing else. Everything about HOW is the CLI's problem, which is the
        // point of asking it rather than writing a downloader here.
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
            // Straight into the suggestions, as a monochrome candidate: it was
            // asked for a single-colour logo, and a wrong guess about that costs
            // one click to correct.
            const next = Object.assign({}, root.found);
            next[cls] = [`mono:${root.askResult}`, `image:${root.askResult}`].concat(next[cls] ?? []);
            root.found = next;
        }
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text()) ?? {};
                // The file used to BE the app table. A version without the
                // wrapper is still every choice somebody made, so it is read as
                // what it was rather than thrown away for having the old shape.
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
            // No file yet is not a failure to read one: there is nothing on disk
            // to lose, so writing can start as soon as the directory exists.
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
