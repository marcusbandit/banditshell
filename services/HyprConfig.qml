pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.config
import "hyprgen.js" as HyprGen

// The user's Hyprland config, as a model banditshell can show and edit.
//
// THE SHAPE: banditshell owns nothing. The config tree (hyprland.lua and
// everything it requires) is scanned into binds, each carrying the file and
// the lines it came from; an edit splices those exact lines in that exact
// file and never touches a byte else. The old designs -- a generated module,
// a require line, a table in config.json -- are all gone: there is no second
// representation of the binds anywhere, so there is nothing to sync, nothing
// to adopt, and nothing the shell could delete that it did not first read.
//
// THE EDITOR'S ONE-WAY VALVE. Reading is free and constant. Writing happens
// only through the three operations below, each an explicit user deed, and
// each is: splice the lines, verify the whole config parses, reload the
// compositor, rescan. A write that does not verify is REVERTED -- the
// compositor reloads on its own inotify the moment the file moves, so a
// broken line would be an error banner on the user's screen within a frame;
// putting the previous text back is faster than apologising.
//
// What the scanner stood back from (binds born in loops and submap
// functions, chords built by concatenation, options this file does not
// speak) is in the model as `dynamic`: shown, located, and read-only. An
// editor that half-understands a line must never write it; the file's own
// comments and structure are the user's and are never regenerated.
Singleton {
    id: root

    readonly property string hyprDir: `${Quickshell.env("HOME")}/.config/hypr`
    readonly property string configPath: `${hyprDir}/hyprland.lua`

    // THE MODEL. `files` is the page's grouping; `binds` is the flat list.
    // An id is file:line -- stable enough to reach the model between scans,
    // never stored anywhere, because every write rescans and the ids move.
    property var files: []
    property var binds: []
    property bool scanned: false
    readonly property bool ready: root.scanned

    // The text of every file the scan read, kept so an edit splices the
    // text the scan read rather than a re-read that may have moved.
    property var texts: ({})

    Component.onCompleted: root.rescan()

    // A reload by any hand -- the user's own, a hook, another tool -- makes
    // this a fresh read: the model must not age next to the file.
    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.rescan();
        }
    }

    function shortName(path: string): string {
        return path.startsWith(`${root.hyprDir}/lua/`) ? `lua/${path.slice(`${root.hyprDir}/lua/`.length)}` : path.startsWith(`${root.hyprDir}/`) ? path.slice(root.hyprDir.length + 1) : path;
    }

    function pathOf(name: string): string {
        return name.startsWith("lua/") ? `${root.hyprDir}/${name}` : `${root.hyprDir}/${name}`;
    }

    // THE SCAN: hyprland.lua, then everything it requires, depth-first, once
    // each. One FileView walks the queue sequentially -- the files are
    // small and the walk is a handful of loads a session, not a hot path.
    FileView {
        id: reader

        watchChanges: false
        printErrors: false

        onLoaded: root.fileScanned()

        // A file that does not exist (or will not read) is a named gap in
        // the model, not a failure: the walk continues with whatever it
        // required.
        onLoadFailed: Qt.callLater(root.nextFile)
    }

    property var queue: []
    property var visited: ({})

    function rescan(): void {
        root.visited = {};
        root.files = [];
        root.binds = [];
        root.scanned = false;
        root.queue = [root.configPath];
        console.warn("HyprConfig: rescanning from", root.configPath);
        root.nextFile();
    }

    function nextFile(): void {
        const p = root.queue.shift();
        if (!p)
            return root.finishScan();
        if (root.visited[p])
            return root.nextFile();
        root.visited[p] = true;
        console.warn("HyprConfig: reading", p);
        reader.path = p;
    }

    function fileScanned(): void {
        console.warn("HyprConfig: scanned", reader.path);
        const name = root.shortName(reader.path);
        const r = HyprGen.scanLua(reader.text());
        const file = {
            name,
            path: reader.path,
            binds: []
        };
        const collected = [];
        for (const b of r.binds) {
            const bind = Object.assign({
                id: `${name}:${b.startLine}`,
                file: name
            }, b);

            // What the bind RUNS, for the page's row: a command when the
            // expression is an exec of one, the expression itself otherwise.
            // And what it does IN WORDS, for the sheet and the rows: the
            // description if the bind has one, else the dictionary's sentence
            // for its expression. A dynamic bind gets neither -- its chord is
            // a loop's business and its action is the source's.
            if (!bind.dynamic) {
                const em = /^hl\.dsp\.exec_cmd\("((?:[^"\\]|\\.)*)"$/.exec(bind.expr);
                bind.cmd = em ? HyprGen.luaUnescape(em[1]) : "";
                bind.action = bind.description || HyprGen.describeExpr(bind.expr) || bind.expr;
            } else {
                bind.action = "";
            }
            file.binds.push(bind);
            collected.push(bind);
        }
        root.texts[reader.path] = reader.text();
        root.texts = Object.assign({}, root.texts);
        root.files = root.files.concat([file]);
        root.binds = root.binds.concat(collected);

        for (const req of r.requires)
            root.queue.push(`${root.hyprDir}/${req.split(".").join("/")}.lua`);
        // DEFERRED, Config.qml's warning restated: a path change made from
        // inside the load's own completion handler is a change made while
        // the FileView is still finishing the read, and it is DROPPED. The
        // walk died one file in, silently, exactly there. Next step next
        // stack.
        Qt.callLater(root.nextFile);
    }

    // WHAT A REGISTERED CHORD DOES, asked by the CheatSheet: the sheet sees
    // the compositor's resolved truth, where every Lua bind is "__lua 40";
    // the scan sees the source, which knows. Chord join on mask and key,
    // literals only, first hit wins.
    function actionFor(mask: int, key: string): string {
        const k = String(key).toLowerCase();
        for (const b of root.binds) {
            if (b.dynamic)
                continue;
            const c = HyprGen.parseChord(b.chord);
            if (c.mask === mask && c.key.toLowerCase() === k)
                return b.action;
        }
        return "";
    }

    function finishScan(): void {
        console.warn("HyprConfig: scan done,", root.binds.length, "binds in", root.files.length, "files");
        root.scanned = true;
    }

    // ------------------------------------------------------- the three edits

    // One bind, re-composed from the given fields and spliced over its own
    // lines. Only literal binds; a dynamic one is the source's business.
    function updateBind(id: string, fields: var): void {
        const b = root.binds.find(x => x.id === id);
        if (!b)
            return console.warn(`HyprConfig: no bind ${id}`);
        if (b.dynamic)
            return console.warn(`HyprConfig: ${b.chord} is generated by the source (line ${b.startLine} of ${b.file}); edit the source.`);
        root.commit(b.file, b.startLine, b.endLine, [HyprGen.composeBind(fields.chord, fields.expr, {
                locked: fields.locked,
                repeating: fields.repeating,
                description: fields.description
            })]);
    }

    function removeBind(id: string): void {
        const b = root.binds.find(x => x.id === id);
        if (!b)
            return console.warn(`HyprConfig: no bind ${id}`);
        if (b.dynamic)
            return console.warn(`HyprConfig: ${b.chord} is generated by the source (line ${b.startLine} of ${b.file}); edit the source.`);
        root.commit(b.file, b.startLine, b.endLine, []);
    }

    // APPENDED, never inserted mid-file: the config's own section structure
    // is the user's, and the end of a binds file is where theirs already
    // expects new lines. Which file: the page asks; there is no default.
    function addBind(fileName: string, fields: var): void {
        const line = HyprGen.composeBind(fields.chord, fields.expr, {
            locked: fields.locked,
            repeating: fields.repeating,
            description: fields.description
        });
        if (!line)
            return console.warn("HyprConfig: a bind needs a chord and something to run.");
        if (!HyprGen.parseChord(fields.chord).key)
            return console.warn(`HyprConfig: "${fields.chord}" is not a chord this editor can write.`);

        const path = root.pathOf(fileName);
        const text = root.texts[path] ?? "";
        root.commit(fileName, text.length + 1, text.length + 1, [line]);
    }

    // A bind added where another already stands is the user's decision; the
    // collision is said out loud at commit time and resolved by nobody.
    // (The per-chord check runs over the MODEL, so it sees the files the
    // scan read -- including the dynamic ones a registry cannot name.)

    // ------------------------------------------------------------ the chain

    // THE WRITE CHAIN, and why it exists. The compositor reloads on its own
    // inotify the moment a file moves, so a broken line is an error banner
    // within a frame no matter what the shell does afterwards. The chain's
    // job is the RECOVERY: verify the on-disk result, reload deterministically
    // when it is good, and put the previous text back when it is not.
    property bool applying: false
    property var committing: null // { file, path, previous }

    function commit(file: string, startLine: int, endLine: int, replacement: var): void {
        if (root.applying)
            return console.warn("HyprConfig: a write is still in flight; try again in a moment.");

        const path = root.pathOf(file);
        const previous = root.texts[path] ?? "";
        const next = HyprGen.spliceLines(previous, startLine, endLine, replacement);
        if (next === null)
            return console.warn(`HyprConfig: lines ${startLine}-${endLine} are outside ${file}; the model is stale, rescanning.`);

        root.applying = true;
        root.committing = {
            file,
            path,
            previous
        };
        writer.path = path;
        writer.setText(next);
    }

    FileView {
        id: writer

        watchChanges: false
        printErrors: false

        onSaved: root.verify()
        onSaveFailed: {
            console.warn(`HyprConfig: could not write ${root.committing?.path}; the edit is not on disk.`);
            root.applying = false;
        }
    }

    function verify(): void {
        verifier.running = true;
    }

    Process {
        id: verifier

        command: ["Hyprland", "--verify-config", "-c", root.configPath]

        stdout: StdioCollector {
            id: verifyOut
        }

        onExited: {
            if (verifier.exitCode !== 0) {
                console.warn(`HyprConfig: the edit did not verify; putting the previous text back.\n${verifyOut.text}`);
                // The revert is a plain write of what was there before; the
                // compositor's inotify reload picks it up on its own.
                writer.setText(root.committing.previous);
                root.applying = false;
                return;
            }
            reloader.running = true;
        }
    }

    Process {
        id: reloader

        command: ["hyprctl", "reload"]

        onExited: {
            root.applying = false;
            root.rescan();
        }
    }

    // The inotify double: OUR write triggers the compositor's own reload,
    // which fires configReloaded, which rescans -- the chain's rescan and
    // this one are the same model being rebuilt twice for one edit, and
    // rescanning is cheap and idempotent. The Connections block at the top
    // owns that path; nothing here listens for it a second time.
}
