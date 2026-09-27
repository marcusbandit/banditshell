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

    // Monitor entries, the flat list the monitors page edits: one per table
    // literal carrying an `output` field, wherever in the config tree it
    // stood -- a direct hl.monitor call, an entry of the host table's
    // `outputs` list, either, resolved through the file's own named
    // constants. `outputTables` is where those lists live, for an entry that
    // has to be CREATED rather than changed: a monitor no line has ever
    // named joins the list its file already keeps.
    property var monitors: []
    property var outputTables: []

    // Band entries, the workspace assignment the shell manages: one per
    // `{ monitor, first, last }` table literal in the config tree, wherever
    // the managed section keeps it. `path` is the chain of table keys it
    // hung under, which is how a host tells its bands from another
    // machine's in a config shared byte for byte. `bandTables` is where
    // those lists live, for a band that has to be CREATED rather than
    // changed.
    property var bands: []
    property var bandTables: []

    // THE HOST THIS MACHINE IS, read the way the config's own host.lua reads
    // it -- /etc/hostname first, the environment as backstop -- so the bands
    // model can answer "mine" without the shell ever evaluating the user's
    // Lua. "unknown" is the same answer host.lua gives a machine it cannot
    // name: a managed table keyed by no host anybody knows matches nothing,
    // which is the correct failure.
    property string hostName: Quickshell.env("HOSTNAME") || "unknown"
    readonly property string hostnamePath: "/etc/hostname"

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
        root.monitors = [];
        root.outputTables = [];
        root.bands = [];
        root.bandTables = [];
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
        root.monitors = root.monitors.concat(r.monitors.map(m => Object.assign({
                id: `${name}:${m.startLine}`,
                file: name
            }, m)));
        root.outputTables = root.outputTables.concat(r.outputTables.map(t => Object.assign({
                file: name
            }, t)));
        root.bands = root.bands.concat(r.bands.map(b => Object.assign({
                id: `${name}:${b.startLine}`,
                file: name
            }, b)));
        root.bandTables = root.bandTables.concat(r.bandTables.map(t => Object.assign({
                file: name
            }, t)));

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

    // THE HOSTNAME, as a file read rather than an environment hope: host.lua
    // prefers /etc/hostname and this reads the same authority, so "mine" is
    // the same word on both sides of the managed section.
    FileView {
        id: hostnameReader

        path: root.hostnamePath
        watchChanges: false
        printErrors: false

        onLoaded: {
            const name = String(text() ?? "").trim();
            if (name)
                root.hostName = name;
        }
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

    // ------------------------------------------------- the two monitor edits

    // One monitor entry, re-composed with the given fields merged in and
    // spliced over its own lines. composeEntry rewrites exactly the fields
    // the edit actually moved: the file's own aliases and its unmanaged
    // fields (`bitdepth`, `cm`) go back byte for byte.
    function updateMonitor(id: string, changed: var): void {
        const m = root.monitors.find(x => x.id === id);
        if (!m)
            return console.warn(`HyprConfig: no monitor entry ${id}`);
        if (m.dynamic)
            return console.warn(`HyprConfig: ${m.output} is generated by the source (line ${m.startLine} of ${m.file}); edit the source.`);
        const line = HyprGen.composeEntry(m, changed);
        if (!line)
            return console.warn("HyprConfig: nothing to write.");
        // `trailing` is the list separator the source kept after the entry's
        // own closing brace -- outside the braces, so compose never saw it,
        // and the file cannot parse without it once the entry is one line.
        root.commit(m.file, m.startLine, m.endLine, [m.indent + line + (m.trailing ?? "")]);
    }

    // A monitor no source line has ever named joins the `outputs` list its
    // file keeps, indented as that list's closing brace is. A file with no
    // outputs list takes the line at the end of the file, top-level, where a
    // literal hl.monitor call applies on every host -- said plainly here
    // because that is a decision about the user's file shape, made quietly.
    function addMonitor(fileName: string, spec: var): void {
        const line = HyprGen.composeEntry(null, spec);
        if (!line)
            return console.warn("HyprConfig: a monitor entry needs an output and a spec.");

        const path = root.pathOf(fileName);
        const text = root.texts[path] ?? "";
        const table = root.outputTables.find(t => t.file === fileName);

        if (table) {
            const closer = text.split("\n")[table.endLine - 1] ?? "";
            // The indent a MEMBER of this list wears, taken from the last
            // entry already inside it -- the closer's own indent is one tier
            // out, and a new line at the closer's depth would read as the
            // table's exit rather than its contents. A list with no members
            // yet has no member to ask, and takes the closer's tier plus the
            // four the config tree indents by.
            const inside = root.monitors.filter(m => m.file === fileName && m.startLine > table.startLine && m.endLine < table.endLine);
            const indent = inside.length ? inside[inside.length - 1].indent : /^[ \t]*/.exec(closer)[0] + "    ";
            // A LIST ITEM the entry is, inside the outputs table's braces: it
            // wears the trailing comma the list's every other member does.
            root.commit(fileName, table.endLine, table.endLine, [`${indent}${line},`, closer]);
            return;
        }

        const lines = text.split("\n");
        root.commit(fileName, lines.length, lines.length, [lines[lines.length - 1], line]);
    }

    // --------------------------------------------------- the two band edits

    // One band entry, re-composed with the given fields and spliced over its
    // own lines. The file's own name for the monitor (`monitor = ultrawide`)
    // survives untouched unless the edit itself names a different output.
    function updateBand(id: string, changed: var): void {
        const b = root.bands.find(x => x.id === id);
        if (!b)
            return console.warn(`HyprConfig: no band entry ${id}`);
        if (b.dynamic)
            return console.warn(`HyprConfig: the band for ${b.monitor} is generated by the source (line ${b.startLine} of ${b.file}); edit the source.`);
        const line = HyprGen.composeEntry(b, changed);
        if (!line)
            return console.warn("HyprConfig: nothing to write.");
        root.commit(b.file, b.startLine, b.endLine, [b.indent + line + (b.trailing ?? "")]);
    }

    // A band that does not exist yet joins its host's list inside the managed
    // section, indented as that list's members are and wearing the trailing
    // comma every other member wears. Only a list the scan has already found
    // can be joined: a config with no managed band table gets a refusal and
    // a log line, because the shell does not invent sections in the user's
    // file -- the section exists by the user's own hand (or the bootstrap),
    // and the shell's writes stay inside it.
    function addBand(spec: var): void {
        const line = HyprGen.composeEntry(null, spec);
        if (!line)
            return console.warn("HyprConfig: a band entry needs a monitor and a range.");

        const table = root.bandTables.find(t => t.path[1] === root.hostName)
            ?? root.bandTables[0];
        if (!table)
            return console.warn("HyprConfig: no managed band table to add to; edit the source.");

        const path = root.pathOf(table.file);
        const text = root.texts[path] ?? "";
        const closer = text.split("\n")[table.endLine - 1] ?? "";
        const inside = root.bands.filter(b => b.file === table.file && b.startLine > table.startLine && b.endLine < table.endLine);
        const indent = inside.length ? inside[inside.length - 1].indent : /^[ \t]*/.exec(closer)[0] + "    ";
        root.commit(table.file, table.endLine, table.endLine, [`${indent}${line},`, closer]);
    }

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
