pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/clipboard.json`

    readonly property string blobs: `${root.dir}/clipboard`

    property var entries: []

    property bool loaded: false

    property bool keep: true

    property bool reaped: false

    readonly property bool recording: watcher.running

    property string current: ""

    readonly property var kinds: ["image", "audio", "video", "json", "code", "document", "files", "colour", "url", "text"]

    function markFor(kind: string): string {
        switch (kind) {
        case "image":
            return "image";
        case "audio":
            return "graphic_eq";
        case "video":
            return "movie";
        case "json":
            return "data_object";
        case "code":
            return "code";
        case "document":
            return "description";
        case "files":
            return "folder";
        case "colour":
            return "palette";
        case "url":
            return "link";

        case "speech":
            return "mic";
        }
        return "notes";
    }

    readonly property int jsonProbeLimit: 1048576

    function looksJson(text: string): bool {
        const s = (text ?? "").trim();
        if (s.length < 2 || s.length > root.jsonProbeLimit)
            return false;

        const open = s.charAt(0);
        const close = s.charAt(s.length - 1);
        if (!((open === "{" && close === "}") || (open === "[" && close === "]")))
            return false;

        try {
            JSON.parse(s);
            return true;
        } catch (err) {
            return false;
        }
    }

    readonly property var hex: /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/

    readonly property var url: /^(https?|ftp|magnet|mailto|ssh|git):/i

    function classify(e: var): string {
        const paths = e.paths ?? [];
        const mimes = e.mimes ?? [];
        const types = e.types ?? [];

        if (paths.length) {
            const kind = m => m.startsWith("image/") ? "image" : m.startsWith("audio/") ? "audio" : m.startsWith("video/") ? "video" : m.startsWith("text/") || m.startsWith("application/pdf") || m.includes("document") ? "document" : "files";
            if (mimes.length === paths.length && mimes.every(m => !!m)) {
                const all = mimes.map(kind);
                if (all.every(k => k === all[0]))
                    return all[0];
            }
            return "files";
        }

        if (e.file)
            return "image";

        if (types.some(t => t.startsWith("image/")))
            return "image";

        if (types.includes("text/uri-list") || (e.uris ?? []).length)
            return "files";

        const text = (e.text ?? "").trim();
        if (!text)
            return "text";
        if (root.hex.test(text))
            return "colour";
        if (root.url.test(text))
            return "url";

        if (root.looksJson(text))
            return "json";

        if (root.looksCode(text))
            return "code";

        if (/^(~|\/)[^\n]*$/.test(text) && !/\s{2}/.test(text))
            return "files";

        return "text";
    }

    readonly property var strongCode: /^\s*(#!|#include\b|package\s+\w+;|<\?php|<!DOCTYPE|import\s+[\w.]+\s*$|from\s+[\w.]+\s+import\b|using\s+namespace\b)/m
    readonly property var codeSignals: [

        /\b(function|def|class|struct|impl|fn|func|const|let|var|public|private|static|return)\b/,

        /[;{}]\s*$/m,

        /(=>|->|:=|==|!=|\+=|\|\||&&)/,

        /\w+\s*\([^)]*\)/,

        /^\s*(\/\/|\/\*|#\s)/m,

        /^[ \t]{2,}\S/m
    ]

    function looksCode(text: string): bool {
        const s = (text ?? "").trim();

        if (s.length < 12)
            return false;

        if (root.strongCode.test(s))
            return true;

        if (s.indexOf("\n") < 0)
            return false;

        let votes = 0;
        for (const rule of root.codeSignals)
            if (rule.test(s))
                votes++;

        return votes >= 3;
    }

    function summarise(e: var): string {

        if (e.file)
            return root.basename(e.file);
        if ((e.paths ?? []).length)
            return e.paths.length === 1 ? root.basename(e.paths[0]) : `${e.paths.length} files`;
        return (e.text ?? "").trim();
    }

    function size(bytes: real): string {
        if (!bytes || bytes <= 0)
            return "";

        const units = ["B", "kB", "MB", "GB", "TB"];
        const tier = Math.min(units.length - 1, Math.floor(Math.log10(bytes) / 3));
        const scaled = bytes / Math.pow(1000, tier);

        return `${tier === 0 || scaled >= 10 ? Math.round(scaled) : scaled.toFixed(1)} ${units[tier]}`;
    }

    function basename(p: string): string {
        const cut = p.lastIndexOf("/");
        return cut < 0 ? p : p.slice(cut + 1);
    }

    function age(recorded: real): string {
        if (!recorded)
            return "some time ago";

        const secs = Math.max(0, (Date.now() - recorded) / 1000);
        if (secs < 45)
            return "just now";

        const mins = secs / 60;
        if (mins < 60)
            return `${Math.round(mins)}m ago`;

        const hours = mins / 60;
        if (hours < 24)
            return `${Math.round(hours)}h ago`;

        const days = hours / 24;
        if (days < 7)
            return Math.round(days) === 1 ? "yesterday" : `${Math.round(days)}d ago`;

        const weeks = days / 7;
        return weeks < 5 ? `${Math.round(weeks)}w ago` : `${Math.round(days / 30)}mo ago`;
    }

    function identity(e: var): string {
        if (e.file)
            return `file:${e.file}`;
        if ((e.paths ?? []).length)

        return `paths:${e.paths.join("\u0000")}`;
        return `text:${e.text ?? ""}`;
    }

    function absorb(line: string): void {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (err) {

            console.warn("Clipboard: unreadable line from the recorder:", line);
            return;
        }

        if (ev.state !== "data") {
            root.current = "";
            return;
        }

        if (ev.text && Dictation.said(ev.text))
            return;

        if (ev.dropped || (!ev.text && !ev.file && !(ev.paths ?? []).length))
            return;

        const now = Date.now();
        const entry = {
            id: `${now}-${root.entries.length}`,
            recorded: now,
            text: ev.text ?? "",
            file: ev.file ?? "",
            bytes: ev.bytes ?? 0,

            w: ev.w ?? 0,
            h: ev.h ?? 0,
            types: ev.types ?? [],
            paths: ev.paths ?? [],
            mimes: ev.mimes ?? [],
            pinned: false
        };
        entry.kind = root.classify(entry);

        root.push(entry);
    }

    function push(entry: var): void {
        const key = root.identity(entry);
        const had = root.entries.find(e => root.identity(e) === key);

        if (had) {
            entry.id = had.id;
            entry.pinned = had.pinned;
        }

        const rest = root.entries.filter(e => root.identity(e) !== key);
        root.entries = [entry, ...rest];
        root.current = entry.id;
        root.prune();
        root.save();
    }

    function prune(): void {
        const max = Math.max(1, Config.values.clipboard.maxEntries);
        const loose = root.entries.filter(e => !e.pinned);
        if (loose.length <= max)
            return;

        const doomed = new Set(loose.slice(max).map(e => e.id));
        root.entries = root.entries.filter(e => !doomed.has(e.id));
    }

    function copy(entry: var): void {
        if (!entry)
            return;

        if (entry.file) {

            const ext = entry.file.slice(entry.file.lastIndexOf(".") + 1).toLowerCase();
            paste.command = ["sh", "-c", 'exec wl-copy -t "$1" < "$2"', "sh", `image/${ext === "jpg" ? "jpeg" : ext}`, entry.file];
        } else if ((entry.paths ?? []).length) {

            const uris = entry.paths.map(p => `file://${encodeURI(p)}`).join("\r\n");
            paste.command = ["wl-copy", "-t", "text/uri-list", "--", uris];
        } else {

            paste.command = ["wl-copy", "-n", "--", entry.text ?? ""];
        }

        paste.running = true;
    }

    function pathsOf(entry: var): var {
        if (!entry)
            return [];
        if ((entry.paths ?? []).length)
            return entry.paths;
        return entry.file ? [entry.file] : [];
    }

    function copyPath(entry: var): void {
        const paths = root.pathsOf(entry);
        if (!paths.length)
            return;

        paste.command = ["wl-copy", "-n", "--", paths.join("\n")];
        paste.running = true;
    }

    function noteAspect(id: string, ratio: real): void {
        if (!id || !(ratio > 0))
            return;
        const had = root.entries.find(e => e.id === id);

        if (!had || had.w > 0 || Math.abs((had.aspect ?? 0) - ratio) < 0.001)
            return;
        root.entries = root.entries.map(e => e.id === id ? Object.assign({}, e, {
                    aspect: ratio
                }) : e);

        root.save();
    }

    property var pretty: ({})

    property string formattingId: ""

    function formatted(entry: var): string {
        return entry ? (root.pretty[entry.id] ?? "") : "";
    }

    function beautify(entry: var): void {
        if (!entry || entry.kind !== "json")
            return;

        if (root.pretty[entry.id] !== undefined || jq.running)
            return;

        root.formattingId = entry.id;

        jq.command = ["sh", "-c", 'printf %s "$1" | jq --indent 2 .', "sh", entry.text ?? ""];
        jq.running = true;
    }

    Process {
        id: jq

        stdout: StdioCollector {
            onStreamFinished: {
                const id = root.formattingId;
                if (!id)
                    return;

                const next = Object.assign({}, root.pretty);
                next[id] = text;
                root.pretty = next;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: if (text.trim())
                console.warn("Clipboard: jq could not format that entry:", text.trim())
        }

        onExited: code => {

            if (code !== 0 && root.formattingId && root.pretty[root.formattingId] === undefined) {
                const next = Object.assign({}, root.pretty);
                next[root.formattingId] = "";
                root.pretty = next;
            }
            root.formattingId = "";
        }
    }

    function setPinned(entry: var, pinned: bool): void {
        if (!entry)
            return;
        root.entries = root.entries.map(e => e.id === entry.id ? Object.assign({}, e, {
                    pinned: pinned
                }) : e);
        root.save();
    }

    function remove(entry: var): void {
        if (!entry)
            return;
        root.entries = root.entries.filter(e => e.id !== entry.id);
        if (root.current === entry.id)
            root.current = "";
        root.save();
        root.sweep();
    }

    function clear(): void {
        root.entries = root.entries.filter(e => e.pinned);
        root.current = "";
        root.save();
        root.sweep();
    }

    function sweep(): void {

        if (reaper.running) {
            root.sweepOwed = true;
            return;
        }
        root.sweepOwed = false;

        const wanted = root.entries.filter(e => !!e.file).map(e => root.basename(e.file));

        reaper.command = ["sh", "-c", `
            dir=$1; shift
            [ -d "$dir" ] || exit 0
            keep=$(mktemp) || exit 0
            printf '%s\\n' "$@" > "$keep"
            find "$dir" -maxdepth 1 -type f -printf '%f\\n' 2>/dev/null \\
                | grep -vxF -f "$keep" \\
                | while IFS= read -r n; do rm -f -- "$dir/$n"; done
            rm -f "$keep"
            exit 0
        `, "sh", root.blobs, ...wanted];
        reaper.running = true;
    }

    readonly property int tierExact: 4
    readonly property int tierPrefix: 3
    readonly property int tierWord: 2
    readonly property int tierAnywhere: 1
    readonly property int tierNone: -1

    function tier(entry: var, needle: string): int {
        if (!needle)
            return root.tierExact;

        const q = needle.toLowerCase();

        const hay = [entry.text ?? "", entry.kind ?? "", ...(entry.paths ?? []), entry.file ? root.basename(entry.file) : ""].join("\n").toLowerCase();

        if (hay === q)
            return root.tierExact;
        if (hay.startsWith(q))
            return root.tierPrefix;
        if (new RegExp(`\\b${root.escapeRegex(q)}`).test(hay))
            return root.tierWord;
        if (hay.includes(q))
            return root.tierAnywhere;

        return root.tierNone;
    }

    function escapeRegex(s: string): string {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function search(needle: string): var {
        return root.entries.map(e => ({
                    entry: e,
                    tier: root.tier(e, needle)
                })).filter(r => r.tier > root.tierNone).sort((a, b) => (b.entry.pinned ? 1 : 0) - (a.entry.pinned ? 1 : 0) || b.tier - a.tier || b.entry.recorded - a.entry.recorded).map(r => r.entry);
    }

    Process {
        id: stale

        command: ["sh", "-c", `
            script=$1
            for p in $(pgrep -f "wl-paste --watch $script" 2>/dev/null); do
                ppid=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
                [ -n "$ppid" ] || continue
                owner=$(ps -o comm= -p "$ppid" 2>/dev/null | tr -d ' ')
                # BOTH NAMES. The binary is invoked as \`qs\` and reports itself
                # as \`quickshell\`, and which one \`comm\` shows is not this
                # file's business to predict: testing only the short one meant
                # every live shell's watcher looked ownerless and got killed,
                # which is precisely the failure this parentage test exists to
                # prevent, arrived at from the other side.
                case "$owner" in
                qs | quickshell) continue ;;
                esac
                kill "$p" 2>/dev/null
            done
            exit 0
        `, "sh", Quickshell.shellPath("scripts/clip-record.sh")]

        onExited: root.reaped = true
    }

    Process {
        id: watcher

        running: root.loaded && root.reaped && Config.values.clipboard.record

        command: ["wl-paste", "--watch", Quickshell.shellPath("scripts/clip-record.sh")]

        environment: ({
                BANDITSHELL_CLIP_STORE: root.blobs,
                BANDITSHELL_CLIP_MAXTEXT: `${Config.values.clipboard.maxText}`,
                BANDITSHELL_CLIP_MAXBLOB: `${Config.values.clipboard.maxBlob}`
            })

        stdout: SplitParser {
            onRead: line => {
                if (line.trim())
                    root.absorb(line);
            }
        }

        stderr: SplitParser {
            onRead: line => console.warn("clip-record:", line)
        }

        onExited: (code, status) => {
            if (Config.values.clipboard.record)
                console.warn(`Clipboard: the recorder exited (${code}); nothing new will be recorded until the shell restarts it.`);
        }
    }

    Process {
        id: paste

        stderr: SplitParser {
            onRead: line => console.warn("wl-copy:", line)
        }
    }

    property bool sweepOwed: false

    Process {
        id: reaper

        onExited: if (root.sweepOwed)
            root.sweep()
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.blobs]

        onExited: {
            stale.running = true;
            store.reload();
        }
    }

    FileView {
        id: store

        path: root.path

        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            const raw = text();

            if (root.loaded && raw === root.lastWritten)
                return;

            let disk = [];
            try {
                const data = JSON.parse(raw);
                disk = Array.isArray(data?.entries) ? data.entries : [];
            } catch (err) {

                if (root.loaded)
                    return;

                console.warn(`Clipboard: ${root.path} is not valid JSON; running from memory and leaving the file alone.`, err);
                root.keep = false;
            }

            disk = disk.filter(e => e && (e.text || e.file || (e.paths ?? []).length));

            for (const e of disk)
                e.kind = root.classify(e);

            if (root.loaded) {
                root.entries = root.reconcile(disk);
                return;
            }

            root.entries = disk;
            root.loaded = true;

            if (Config.values.clipboard.importClipse)
                clipse.reload();
        }

        onLoadFailed: err => {
            if (root.loaded)
                return;

            if (err === FileViewError.FileNotFound) {

                root.loaded = true;
                if (Config.values.clipboard.importClipse)
                    clipse.reload();
                return;
            }

            console.warn(`Clipboard: could not read ${root.path} (${err}); running from memory.`);
            root.keep = false;
            root.loaded = true;
        }
    }

    function reconcile(disk: var): var {
        const theirs = new Set(disk.map(e => e?.id));
        const unseen = root.entries.filter(e => !theirs.has(e.id));
        return [...disk, ...unseen].sort((a, b) => b.recorded - a.recorded);
    }

    property string lastWritten: ""

    function save(): void {
        if (!root.keep || !root.loaded)
            return;

        Qt.callLater(root.write);
    }

    function write(): void {
        if (!root.keep || !root.loaded)
            return;
        root.lastWritten = JSON.stringify({
            version: 1,
            entries: root.entries
        });
        store.setText(root.lastWritten);
    }

    Component.onCompleted: mkdir.running = true

    FileView {
        id: clipse

        path: `${Quickshell.env("HOME")}/.config/clipse/clipboard_history.json`
        printErrors: false

        watchChanges: false

        onLoaded: {
            if (!Config.values.clipboard.importClipse)
                return;

            let old = [];
            try {
                old = JSON.parse(text())?.clipboardHistory ?? [];
            } catch (err) {
                console.warn("Clipboard: clipse's history could not be read; importing nothing.", err);
            }

            root.adopt(old);
        }

        onLoadFailed: root.settleImport()
    }

    function importedPath(from: string): string {
        return `${root.blobs}/imported-${root.basename(from)}`;
    }

    function adopt(old: var): void {

        const mine = new Set(root.entries.map(e => root.identity(e)));
        const brought = [];

        for (const item of old) {
            if (!item || typeof item.value !== "string")
                continue;

            const isImage = item.filePath && item.filePath !== "null";

            const entry = {
                id: `clipse-${brought.length}`,

                recorded: root.parseClipseTime(item.recorded),

                text: isImage ? "" : item.value,
                file: isImage ? root.importedPath(item.filePath) : "",
                bytes: 0,

                types: [],
                paths: [],
                mimes: [],
                pinned: !!item.pinned
            };
            entry.kind = root.classify(entry);

            const key = root.identity(entry);
            if (mine.has(key))
                continue;
            mine.add(key);
            brought.push(entry);
        }

        if (brought.length) {
            root.entries = [...root.entries, ...brought];
            root.prune();

            root.write();
        }

        const pics = root.entries.filter(e => e.file && e.file.startsWith(`${root.blobs}/imported-`));
        if (pics.length) {
            adopter.command = ["sh", "-c", `
                dir=$1; shift
                for f in "$@"; do
                    [ -e "$f" ] || continue
                    cp -n -- "$f" "$dir/imported-$(basename "$f")" 2>/dev/null
                done
                exit 0
            `, "sh", root.blobs, ...pics.map(e => `${Quickshell.env("HOME")}/.config/clipse/tmp_files/${root.basename(e.file).replace("imported-", "")}`)];
            adopter.running = true;
        }

        console.log(`Clipboard: imported ${brought.length} entries from clipse (${pics.length} pictures copied).`);
        root.settleImport();
    }

    Process {
        id: adopter
    }

    function parseClipseTime(recorded: string): real {
        if (typeof recorded !== "string")
            return 0;
        const t = Date.parse(recorded.replace(" ", "T"));
        return isNaN(t) ? 0 : t;
    }

    function settleImport(): void {
        if (Config.values.clipboard.importClipse)
            Config.set("clipboard.importClipse", false);
    }
}
