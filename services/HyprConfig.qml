pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "hyprland-lua.js" as HyprlandLua

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string xdgConfig: Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`
    readonly property string defaultPath: `${xdgConfig}/hypr/hyprland.lua`
    readonly property string legacyPath: `${xdgConfig}/hypr/hyprland.conf`
    readonly property string signature: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""

    property string configPath: ""

    onConfigPathChanged: root.rescan()

    readonly property string hyprDir: {
        const at = root.configPath.lastIndexOf("/");
        return at > 0 ? root.configPath.slice(0, at) : `${root.xdgConfig}/hypr`;
    }

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

    Component.onCompleted: root.findConfig()

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.rescan();
        }
    }

    function findConfig(): void {
        if (!root.signature)
            return root.settle("");
        instances.began = false;
        instances.running = true;
    }

    function settle(found: string): void {
        const next = found || root.defaultPath;
        if (next !== root.configPath)
            root.configPath = next;
        else
            root.rescan();
    }

    function readInstances(text: string): void {
        let list = [];
        try {
            list = JSON.parse(text);
        } catch (e) {
            return root.settle("");
        }
        const mine = (Array.isArray(list) ? list : []).find(i => i.instance === root.signature);
        if (!mine || !(mine.pid > 0))
            return root.settle("");
        commandLine.began = false;
        commandLine.command = ["sh", "-c", "printf 'cwd=%s\\n' \"$(readlink \"/proc/$1/cwd\")\"; tr '\\0' '\\n' < \"/proc/$1/cmdline\"", "sh", String(mine.pid)];
        commandLine.running = true;
    }

    Process {
        id: instances

        property bool began: false

        command: ["hyprctl", "instances", "-j"]

        stdout: StdioCollector {
            onStreamFinished: root.readInstances(text)
        }

        onStarted: instances.began = true
        onRunningChanged: {
            if (!instances.running && !instances.began)
                root.settle("");
        }
    }

    Process {
        id: commandLine

        property bool began: false

        stdout: StdioCollector {
            onStreamFinished: root.settle(HyprlandLua.configFromCommandLine(text, root.home))
        }

        onStarted: commandLine.began = true
        onRunningChanged: {
            if (!commandLine.running && !commandLine.began)
                root.settle("");
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

        onLoaded: {
            root.inFlight = false;
            root.fileScanned();
        }

        onLoadFailed: {
            root.inFlight = false;
            Qt.callLater(reader.path === root.defaultPath && root.configPath === root.defaultPath ? root.useLegacy : root.nextFile);
        }
    }

    function useLegacy(): void {
        root.configPath = root.legacyPath;
    }

    property var queue: []
    property var visited: ({})
    property bool inFlight: false

    function rescan(): void {
        if (!root.configPath)
            return;
        root.visited = {};
        root.files = [];
        root.binds = [];
        root.monitors = [];
        root.outputTables = [];
        root.bands = [];
        root.bandTables = [];
        root.scanned = false;
        root.queue = [root.configPath];
        root.inFlight = false;
        console.info("HyprConfig: rescanning from", root.configPath);
        root.nextFile();
    }

    function nextFile(): void {
        if (root.inFlight)
            return;
        const p = root.queue.shift();
        if (!p)
            return root.finishScan();
        if (root.visited[p])
            return root.nextFile();
        root.visited[p] = true;
        root.inFlight = true;
        console.info("HyprConfig: reading", p);
        if (reader.path === p)
            reader.reload();
        else
            reader.path = p;
    }

    function fileScanned(): void {
        console.info("HyprConfig: scanned", reader.path);
        const name = root.shortName(reader.path);
        const r = HyprlandLua.scanLua(reader.text());
        const file = {
            name,
            path: reader.path,
            binds: []
        };
        const collected = [];
        for (const b of r.binds) {
            const chord = HyprlandLua.parseChord(b.chordLiteral ? b.chord : "");
            const bind = Object.assign({
                id: `${name}:${b.startLine}`,
                file: name,
                mask: chord.mask,
                key: chord.key,
                presses: b.chords.map(c => {
                    const p = HyprlandLua.parseChord(c);
                    return {
                        mask: p.mask,
                        key: p.key
                    };
                })
            }, b);

            if (!bind.dynamic) {
                const em = /^hl\.dsp\.exec_cmd\("((?:[^"\\]|\\.)*)"$/.exec(bind.expr);
                bind.cmd = em ? HyprlandLua.luaUnescape(em[1]) : "";
                bind.action = bind.description || HyprlandLua.describeExpr(bind.expr) || bind.expr;
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
        if (reader.path.endsWith(".conf"))
            for (const source of HyprlandLua.confSources(reader.text(), root.hyprDir, root.home))
                root.queue.push(source);

        Qt.callLater(root.nextFile);
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
        root.commit(b.file, b.startLine, b.endLine, [HyprlandLua.composeBind(fields.chord, fields.expr, {
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
        const line = HyprlandLua.composeBind(fields.chord, fields.expr, {
            locked: fields.locked,
            repeating: fields.repeating,
            description: fields.description
        });
        if (!line)
            return console.warn("HyprConfig: a bind needs a chord and something to run.");
        if (!HyprlandLua.parseChord(fields.chord).key)
            return console.warn(`HyprConfig: "${fields.chord}" is not a chord this editor can write.`);

        const at = HyprlandLua.appendSplice(root.texts[root.pathOf(fileName)] ?? "", [line]);
        root.commit(fileName, at.startLine, at.endLine, at.replacement);
    }

    function updateMonitor(id: string, changed: var): void {
        const m = root.monitors.find(x => x.id === id);
        if (!m)
            return console.warn(`HyprConfig: no monitor entry ${id}`);
        if (m.dynamic)
            return console.warn(`HyprConfig: ${m.output} is generated by the source (line ${m.startLine} of ${m.file}); edit the source.`);
        const line = HyprlandLua.composeEntry(m, changed);
        if (!line)
            return console.warn("HyprConfig: nothing to write.");

        root.commit(m.file, m.startLine, m.endLine, [m.indent + line + (m.trailing ?? "")]);
    }

    function addMonitor(fileName: string, spec: var): void {
        const line = HyprlandLua.composeEntry(null, spec);
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

        const at = HyprlandLua.appendSplice(text, [line]);
        root.commit(fileName, at.startLine, at.endLine, at.replacement);
    }

    function updateBand(id: string, changed: var): void {
        const b = root.bands.find(x => x.id === id);
        if (!b)
            return console.warn(`HyprConfig: no band entry ${id}`);
        if (b.dynamic)
            return console.warn(`HyprConfig: the band for ${b.monitor} is generated by the source (line ${b.startLine} of ${b.file}); edit the source.`);
        const line = HyprlandLua.composeEntry(b, changed);
        if (!line)
            return console.warn("HyprConfig: nothing to write.");
        root.commit(b.file, b.startLine, b.endLine, [b.indent + line + (b.trailing ?? "")]);
    }

    function addBand(spec: var): void {
        const line = HyprlandLua.composeEntry(null, spec);
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
    property bool reverting: false

    function commit(file: string, startLine: int, endLine: int, replacement: var): void {
        if (root.applying)
            return console.warn("HyprConfig: a write is still in flight; try again in a moment.");

        const path = root.pathOf(file);
        root.applying = true;
        root.committing = {
            file,
            path,
            startLine,
            endLine,
            replacement,
            previous: ""
        };
        if (checker.path === path)
            checker.reload();
        else
            checker.path = path;
    }

    function abandon(why: string): void {
        console.warn(`HyprConfig: ${why}; nothing was written, rescanning.`);
        root.applying = false;
        root.committing = null;
        root.rescan();
    }

    function write(disk: var): void {
        const c = root.committing;
        if (!c)
            return;
        const cached = root.texts[c.path];
        if ((disk ?? "") !== (cached ?? ""))
            return root.abandon(`${c.file} changed on disk since the scan`);

        const next = HyprlandLua.spliceLines(disk ?? "", c.startLine, c.endLine, c.replacement);
        if (next === null)
            return root.abandon(`lines ${c.startLine}-${c.endLine} are outside ${c.file}`);

        c.previous = disk ?? "";
        root.reverting = false;
        writer.path = c.path;
        writer.setText(next);
    }

    FileView {
        id: checker

        watchChanges: false
        printErrors: false

        onLoaded: root.write(checker.text())
        onLoadFailed: root.write(null)
    }

    FileView {
        id: writer

        watchChanges: false
        printErrors: false

        onSaved: {
            if (!root.reverting)
                return root.verify();
            root.reverting = false;
            root.applying = false;
            root.rescan();
        }

        onSaveFailed: {
            console.warn(`HyprConfig: could not write ${root.committing?.path}; ${root.reverting ? "the failed edit is still on disk" : "the edit is not on disk"}.`);
            root.reverting = false;
            root.applying = false;
        }
    }

    function verify(): void {
        verifier.began = false;
        verifier.running = true;
    }

    function verified(ok: bool, said: string): void {
        if (ok) {
            reloader.running = true;
            return;
        }
        console.warn(`HyprConfig: the edit did not verify; putting the previous text back.\n${said}`);
        root.reverting = true;
        writer.setText(root.committing.previous);
    }

    Process {
        id: verifier

        property bool began: false

        command: ["Hyprland", "--verify-config", "-c", root.configPath]

        stdout: StdioCollector {
            id: verifyOut
        }

        stderr: StdioCollector {
            id: verifyErr
        }

        onStarted: verifier.began = true

        onExited: (code, status) => root.verified(code === 0 && status !== 1, `${verifyOut.text}${verifyErr.text}`)

        onRunningChanged: {
            if (!verifier.running && !verifier.began)
                root.verified(false, "Hyprland --verify-config did not start");
        }
    }

    Process {
        id: reloader

        command: ["hyprctl", "reload"]

        onRunningChanged: {
            if (reloader.running)
                return;
            root.applying = false;
            root.rescan();
        }
    }
}
