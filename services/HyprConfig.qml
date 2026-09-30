pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "hyprgen.js" as HyprGen

Singleton {
    id: root

    readonly property string hyprDir: `${Quickshell.env("HOME")}/.config/hypr`
    readonly property string configPath: `${hyprDir}/hyprland.lua`

    property var files: []
    property var binds: []

    property var monitors: []
    property var outputTables: []

    property var bands: []
    property var bandTables: []

    property string hostName: Quickshell.env("HOSTNAME") || "unknown"
    readonly property string hostnamePath: "/etc/hostname"

    property bool scanned: false

    property bool hostRead: false
    readonly property bool ready: root.scanned && root.hostRead

    property var texts: ({})

    Component.onCompleted: root.rescan()

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
        return `${root.hyprDir}/${name}`;
    }

    FileView {
        id: reader

        watchChanges: false
        printErrors: false

        onLoaded: root.fileScanned()

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
        console.info("HyprConfig: rescanning from", root.configPath);
        root.nextFile();
    }

    function nextFile(): void {
        const p = root.queue.shift();
        if (!p)
            return root.finishScan();
        if (root.visited[p])
            return root.nextFile();
        root.visited[p] = true;
        console.info("HyprConfig: reading", p);
        reader.path = p;
    }

    function fileScanned(): void {
        console.info("HyprConfig: scanned", reader.path);
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

        Qt.callLater(root.nextFile);
    }

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
        console.info("HyprConfig: scan done,", root.binds.length, "binds in", root.files.length, "files");
        root.scanned = true;
    }

    FileView {
        id: hostnameReader

        path: root.hostnamePath
        watchChanges: false
        printErrors: false

        onLoaded: {
            const name = String(text() ?? "").trim();
            if (name)
                root.hostName = name;
            root.hostRead = true;
        }

        onLoadFailed: root.hostRead = true
    }

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

    function updateMonitor(id: string, changed: var): void {
        const m = root.monitors.find(x => x.id === id);
        if (!m)
            return console.warn(`HyprConfig: no monitor entry ${id}`);
        if (m.dynamic)
            return console.warn(`HyprConfig: ${m.output} is generated by the source (line ${m.startLine} of ${m.file}); edit the source.`);
        const line = HyprGen.composeEntry(m, changed);
        if (!line)
            return console.warn("HyprConfig: nothing to write.");

        root.commit(m.file, m.startLine, m.endLine, [m.indent + line + (m.trailing ?? "")]);
    }

    function addMonitor(fileName: string, spec: var): void {
        const line = HyprGen.composeEntry(null, spec);
        if (!line)
            return console.warn("HyprConfig: a monitor entry needs an output and a spec.");

        const path = root.pathOf(fileName);
        const text = root.texts[path] ?? "";
        const table = root.outputTables.find(t => t.file === fileName);

        if (table) {
            const closer = text.split("\n")[table.endLine - 1] ?? "";

            const inside = root.monitors.filter(m => m.file === fileName && m.startLine > table.startLine && m.endLine < table.endLine);
            const indent = inside.length ? inside[inside.length - 1].indent : /^[ \t]*/.exec(closer)[0] + "    ";

            root.commit(fileName, table.endLine, table.endLine, [`${indent}${line},`, closer]);
            return;
        }

        const lines = text.split("\n");
        root.commit(fileName, lines.length, lines.length, [lines[lines.length - 1], line]);
    }

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

    property bool applying: false
    property var committing: null

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

}
