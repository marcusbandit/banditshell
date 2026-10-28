pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "ranking.js" as Ranking
import "clipboard-sweep.js" as Sweep
import "clipboard-shelf.js" as Shelf
import "clipboard-secret.js" as Secret
import "clipboard-age.js" as Age

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/clipboard.json`

    readonly property string blobs: `${Config.stateDir}/clipboard`

    readonly property string clipseDir: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/clipse`

    property var entries: []

    readonly property int unpinned: root.entries.filter(e => !e.pinned).length

    property bool loaded: false

    property bool keep: true

    property var recovery: null
    property int salvaged: 0
    property int started: 0
    property string backupPath: ""

    property bool reaped: false

    readonly property bool recording: watcher.running

    property string current: ""

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
        return Sweep.basename(p);
    }

    function age(recorded: real): string {
        return Age.age(recorded, Date.now());
    }

    function identity(e: var): string {
        return Shelf.identity(e);
    }

    readonly property string mask: Secret.MASK

    function sensitive(entry: var): bool {
        return Secret.sensitive(entry);
    }

    function absorb(line: string): void {
        let ev;
        try {
            ev = JSON.parse(line);
        } catch (err) {

            console.warn("Clipboard: unreadable line from the recorder:", line);
            return;
        }

        if (ev.state !== "data" || Secret.marked(ev.types)) {
            root.current = "";
            return;
        }

        if (ev.text && Dictation.said(ev.text))
            return;

        if (ev.dropped || (!ev.text && !ev.file && !(ev.paths ?? []).length)) {
            root.current = "";
            return;
        }

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
        root.wasCleared = false;
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
            root.offer(["sh", "-c", 'exec wl-copy -t "$1" < "$2"', "sh", `image/${ext === "jpg" ? "jpeg" : ext}`, entry.file], "", false);
        } else if ((entry.paths ?? []).length) {
            root.offer(["wl-copy", "-t", "text/uri-list"], entry.paths.map(p => `file://${String(p).split("/").map(encodeURIComponent).join("/")}`).join("\r\n"), false);
        } else {
            root.offer(Secret.copyCommand(entry, root.sensitiveCopy), entry.text ?? "", Secret.sensitive(entry));
        }
    }

    property var offered: null

    property bool sensitiveCopy: false
    property bool sensitiveProbed: false

    signal copied(var command, string input, bool secret)

    function offer(command: var, input: string, secret: bool): void {
        root.copied(command, input, secret);
        root.offered = {
            command: command,
            input: input
        };
        root.offerNext();
    }

    function offerNext(): void {
        if (paste.running || !root.offered)
            return;
        const next = root.offered;
        root.offered = null;
        paste.command = next.command;
        paste.stdinEnabled = true;
        paste.running = true;
        paste.write(next.input);
        paste.stdinEnabled = false;
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

        root.offer(["wl-copy", "-n"], paths.join("\n"), false);
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
        root.sweep(false);
    }

    function clear(): void {
        if (!root.entries.some(e => !e.pinned))
            return;
        root.letGo();
        root.shelf = Shelf.shelve(root.entries);
        root.shelfElapsed = 0;
        root.entries = Shelf.kept(root.entries);
        root.current = "";
        root.wasCleared = true;
        root.save();
    }

    readonly property int undoMs: 5000

    property var shelf: null
    property int shelfElapsed: 0
    property var shelfHolders: []

    readonly property bool shelfHeld: root.shelfHolders.length > 0

    function holdShelf(who: var): void {
        if (!root.shelfHolders.includes(who))
            root.shelfHolders = [...root.shelfHolders.filter(w => w), who];
    }

    function releaseShelf(who: var): void {
        root.shelfHolders = root.shelfHolders.filter(w => w && w !== who);
    }

    readonly property int shelved: root.shelf ? root.shelf.entries.length : 0
    readonly property int shelfKept: root.shelf ? root.shelf.before.length - root.shelf.entries.length : 0
    readonly property bool clearSaves: root.keep

    property bool wasCleared: false

    function undo(): bool {
        const shelf = root.shelf;
        if (!shelf)
            return false;
        root.shelf = null;
        root.wasCleared = false;
        root.entries = Shelf.restored(root.entries, shelf);
        root.prune();
        root.save();
        return true;
    }

    function letGo(): void {
        if (!root.shelf)
            return;
        root.shelf = null;
        root.recovery = null;
        root.sweep(true);
    }

    function recoverySeen(): void {
        if (!root.recovery)
            return;
        root.recovery = null;
        root.save();
    }

    Timer {
        interval: 100
        repeat: true
        running: root.shelf !== null && !root.shelfHeld

        onTriggered: {
            root.shelfElapsed += interval;
            if (root.shelfElapsed >= root.undoMs)
                root.letGo();
        }
    }

    property bool purgeOwed: false

    function sweep(purge: bool): void {
        if (purge === true)
            root.purgeOwed = true;

        if (reaper.running) {
            root.sweepOwed = true;
            return;
        }
        root.sweepOwed = false;

        const command = Sweep.command(root.blobs, root.path, root.shelf ? root.entries.concat(root.shelf.entries) : root.entries, root.keep && root.loaded, root.purgeOwed);
        if (!command)
            return;
        root.purgeOwed = false;
        reaper.command = command;
        reaper.running = true;
    }

    readonly property int tierNone: Ranking.NONE

    function tier(entry: var, needle: string): int {
        return Ranking.place([entry.text ?? "", entry.kind ?? "", ...(entry.paths ?? []), entry.file ? root.basename(entry.file) : ""].join("\n"), needle);
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
                case "$owner" in
                qs | quickshell) continue ;;
                esac
                kill "$p" 2>/dev/null
            done
            exit 0
        `, "sh", Quickshell.shellPath("scripts/clip-record.sh")]

        onExited: root.reaped = true
    }

    readonly property bool wantsRecorder: root.loaded && root.reaped && Config.ready && Config.values.clipboard.record

    readonly property int recorderPatience: 60000
    property int recorderFailures: 0
    property real recorderStarted: 0

    onWantsRecorderChanged: {
        revive.stop();
        root.recorderFailures = 0;
        watcher.running = root.wantsRecorder;
    }

    function recorderStopped(): void {
        const ranLong = root.recorderStarted > 0 && Date.now() - root.recorderStarted > root.recorderPatience;
        root.recorderStarted = 0;
        if (!root.wantsRecorder)
            return;
        if (ranLong)
            root.recorderFailures = 0;
        revive.interval = Math.min(root.recorderPatience, 1000 * Math.pow(2, root.recorderFailures));
        root.recorderFailures++;
        console.warn(`Clipboard: the recorder stopped; starting it again in ${revive.interval / 1000} s.`);
        revive.restart();
    }

    Timer {
        id: revive

        onTriggered: if (root.wantsRecorder && !watcher.running)
            watcher.running = true
    }

    Process {
        id: watcher

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

        onStarted: root.recorderStarted = Date.now()
        onRunningChanged: if (!running)
            root.recorderStopped()
    }

    Process {
        command: ["sh", "-c", "wl-copy --help 2>&1 | grep -q -- --sensitive && echo sensitive; true"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.sensitiveCopy = text.trim() === "sensitive";
                root.sensitiveProbed = true;
            }
        }
    }

    Process {
        id: paste

        stderr: SplitParser {
            onRead: line => console.warn("wl-copy:", line)
        }

        onRunningChanged: if (!running)
            Qt.callLater(root.offerNext)
    }

    property bool sweepOwed: false

    Process {
        id: reaper

        onExited: if (root.sweepOwed)
            root.sweep(false)
    }

    Process {
        id: backup

        stdout: StdioCollector {
            onStreamFinished: {
                root.backupPath = text.trim();
                if (!root.backupPath)
                    return;
                console.log(`Clipboard: the damaged history is kept as ${root.backupPath}.`);
                if (root.recovery && !root.recovery.copy) {
                    root.recovery = Object.assign({}, root.recovery, {
                        copy: root.backupPath
                    });
                    root.save();
                }
            }
        }

        onExited: code => {
            if (code !== 0) {
                console.warn(`Clipboard: could not keep a copy of ${root.path}; running from memory and leaving the file alone.`);
                return;
            }
            root.keep = true;
            root.recovery = {
                kept: root.salvaged,
                of: Math.max(root.salvaged, root.started),
                copy: root.backupPath
            };
            root.write();
        }
    }

    Process {
        id: mkdir

        command: ["sh", "-c", 'umask 077 && mkdir -p -- "$2" && chmod 700 -- "$1" "$2"', "sh", Config.stateDir, root.blobs]

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
            const raw = text();

            if (root.loaded && raw === root.lastWritten)
                return;

            let disk = [];
            try {
                const data = raw.trim() === "" && !root.loaded ? {} : JSON.parse(raw);
                disk = Array.isArray(data?.entries) ? data.entries : [];
                if (!root.loaded)
                    root.recovery = data?.recovered?.kept >= 0 ? {
                        kept: data.recovered.kept,
                        of: data.recovered.of > 0 ? data.recovered.of : 0,
                        copy: String(data.recovered.copy ?? "")
                    } : null;
            } catch (err) {

                if (root.loaded)
                    return;

                disk = Shelf.salvage(raw);
                root.salvaged = root.readable(disk.slice()).length;
                root.started = Shelf.seen(raw);
                console.warn(`Clipboard: ${root.path} is not valid JSON; keeping a copy of it and going on with the ${disk.length} entries it still holds.`, err);
                root.keep = false;
                backup.command = Shelf.backupCommand(root.path, new Date());
                backup.running = true;
            }

            disk = root.readable(disk);

            if (root.loaded) {
                root.entries = root.reconcile(disk);
                return;
            }

            root.entries = disk;
            root.loaded = true;

            if (root.clipseOwed)
                clipse.reload();
            else if (root.keep)
                root.sweep(false);
        }

        onLoadFailed: err => {
            if (root.loaded)
                return;

            if (err === FileViewError.FileNotFound) {

                root.loaded = true;
                if (root.clipseOwed)
                    clipse.reload();
                return;
            }

            console.warn(`Clipboard: could not read ${root.path} (${err}); running from memory.`);
            root.keep = false;
            root.loaded = true;
        }
    }

    function readable(disk: var): var {
        const kept = disk.filter(e => e && !Secret.marked(e.types) && (e.text || e.file || (e.paths ?? []).length));
        for (const e of kept)
            e.kind = root.classify(e);
        return kept;
    }

    function reconcile(disk: var): var {
        const theirs = new Set(disk.map(e => e?.id));
        const unseen = root.entries.filter(e => !theirs.has(e.id));
        return [...disk, ...unseen].sort((a, b) => b.recorded - a.recorded);
    }

    property string lastWritten: ""

    readonly property int echoAfterSave: 500
    readonly property int echoWhileSaving: 5000

    Timer {
        id: echoQuiet
    }

    Timer {
        id: saveDelay

        interval: 1000
        onTriggered: root.write()
    }

    function save(): void {
        if (!root.keep || !root.loaded)
            return;
        if (!saveDelay.running)
            saveDelay.start();
    }

    function write(): void {
        saveDelay.stop();
        if (!root.keep || !root.loaded)
            return;
        const text = JSON.stringify(Object.assign({
            version: 1,
            entries: root.entries
        }, root.recovery ? {
            recovered: root.recovery
        } : {}));
        if (text === root.lastWritten)
            return;
        root.lastWritten = text;
        if (text === store.text())
            return;
        echoQuiet.interval = root.echoWhileSaving;
        echoQuiet.restart();
        store.setText(text);
    }

    Component.onCompleted: mkdir.running = true

    Component.onDestruction: {
        if (!saveDelay.running)
            return;
        store.blockWrites = true;
        root.write();
    }

    FileView {
        id: clipse

        path: `${root.clipseDir}/clipboard_history.json`
        printErrors: false

        watchChanges: false

        onLoaded: {
            let old = [];
            try {
                old = JSON.parse(text())?.clipboardHistory ?? [];
            } catch (err) {
                if (Config.values.clipboard.importClipse)
                    console.warn("Clipboard: clipse's history could not be read; importing nothing.", err);
            }

            root.clipseHistory = Array.isArray(old) ? old : [];

            if (!root.clipseOwed)
                return;

            root.adopt(root.clipseHistory);
        }

        onLoadFailed: {
            root.clipseHistory = [];
            root.settleImport();
        }
    }

    property var clipseHistory: []

    readonly property bool clipseOwed: Config.ready && Config.values.clipboard.importClipse

    Connections {
        target: Config

        function onReadyChanged(): void {
            if (root.loaded && root.clipseOwed)
                clipse.reload();
        }
    }

    readonly property int clipseWaiting: root.fresh(root.clipseHistory).length

    function importFromClipse(): void {
        Config.set("clipboard.importClipse", true);
        clipse.reload();
    }

    function importedPath(from: string): string {
        return `${root.blobs}/imported-${root.basename(from)}`;
    }

    function fresh(old: var): var {

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

            const key = root.identity(entry);
            if (mine.has(key))
                continue;
            mine.add(key);
            brought.push(entry);
        }

        return brought;
    }

    function adopt(old: var): void {

        const brought = root.fresh(old);
        for (const entry of brought)
            entry.kind = root.classify(entry);

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
            `, "sh", root.blobs, ...pics.map(e => `${root.clipseDir}/tmp_files/${root.basename(e.file).replace("imported-", "")}`)];
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
        if (root.clipseOwed)
            Config.set("clipboard.importClipse", false);
    }
}
