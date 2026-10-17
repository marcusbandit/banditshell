pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "hyprland-lua.js" as HyprlandLua
import "startup-apps.js" as StartupLog

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
                bind.action = bind.description || HyprlandLua.describeExpr(bind.expr, root.actionRows) || bind.expr;
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
                id: `${name}:${m.startLine}:${m.startOffset}`,
                file: name
            }, m)));
        root.outputTables = root.outputTables.concat(r.outputTables.map(t => Object.assign({
                file: name
            }, t)));
        root.bands = root.bands.concat(r.bands.map(b => Object.assign({
                id: `${name}:${b.startLine}:${b.startOffset}`,
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
        Qt.callLater(root.drainRetries);
    }

    property var actionRows: []

    FileView {
        id: actionsReader

        path: Quickshell.shellPath("api/actions.tsv")
        blockLoading: true
        watchChanges: false
        printErrors: false

        onLoaded: root.actionRows = HyprlandLua.actionTable(text())
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

    property var retries: []

    function deferred(retry: var): bool {
        if (!root.applying && root.scanned)
            return false;
        root.retries = root.retries.concat([retry]);
        return true;
    }

    function deferredEntry(source: var, id: string, again: var): bool {
        if (!root.applying && root.scanned)
            return false;
        const snapshot = source().find(x => x.id === id) ?? null;
        root.retries = root.retries.concat([() => {
                const here = snapshot ? HyprlandLua.relocateEntry(source(), snapshot) : null;
                if (snapshot && !here)
                    return console.warn("HyprConfig: the entry changed before the edit could run; nothing was written.");
                again(here?.id ?? id);
            }]);
        return true;
    }

    function drainRetries(): void {
        while (root.retries.length && !root.applying && root.scanned) {
            const next = root.retries[0];
            root.retries = root.retries.slice(1);
            next();
        }
    }

    function updateBind(id: string, fields: var): void {
        if (root.deferredEntry(() => root.binds, id, resolved => root.updateBind(resolved, fields)))
            return;
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
        if (root.deferredEntry(() => root.binds, id, resolved => root.removeBind(resolved)))
            return;
        const b = root.binds.find(x => x.id === id);
        if (!b)
            return console.warn(`HyprConfig: no bind ${id}`);
        if (b.dynamic)
            return console.warn(`HyprConfig: ${b.chord} is generated by the source (line ${b.startLine} of ${b.file}); edit the source.`);
        root.commit(b.file, b.startLine, b.endLine, []);
    }

    function addBind(fileName: string, fields: var): void {
        if (root.deferred(() => root.addBind(fileName, fields)))
            return;
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

    function toggleStartup(id: string, on: bool): void {
        if (root.deferred(() => root.toggleStartup(id, on)))
            return;
        const row = StartupLog.hyprlandApps(root.files.map(f => ({
                    name: f.name,
                    text: root.texts[f.path] ?? ""
                }))).find(r => r.id === id);
        if (!row)
            return console.warn(`HyprConfig: no startup line for ${id}`);
        root.commit(row.file, row.startLine, row.endLine, StartupLog.toggleReplacement(row, on));
    }

    function monitorEntry(output: string): var {
        return HyprlandLua.entriesForHost(root.monitors.filter(m => !m.dynamic && m.output === output), root.hostName)[0] ?? null;
    }

    function outputTable(): var {
        return HyprlandLua.entriesForHost(root.outputTables, root.hostName)[0] ?? null;
    }

    readonly property var hostBands: HyprlandLua.entriesForHost(root.bands.filter(b => !b.dynamic), root.hostName)

    function bandEntry(monitor: string): var {
        return root.hostBands.find(b => b.monitor === monitor) ?? null;
    }

    function bandTable(): var {
        return HyprlandLua.entriesForHost(root.bandTables, root.hostName)[0] ?? null;
    }

    function unwritten(output: string, why: string): void {
        console.warn(`HyprConfig: ${why}`);
        if (output)
            root.monitorSettled(output, false, why);
    }

    function updateMonitor(id: string, changed: var): void {
        if (root.deferredEntry(() => root.monitors, id, resolved => root.updateMonitor(resolved, changed)))
            return;
        const m = root.monitors.find(x => x.id === id);
        if (!m)
            return console.warn(`HyprConfig: no monitor entry ${id}`);
        if (m.dynamic)
            return root.unwritten(m.output, `${m.output} is generated by the source (line ${m.startLine} of ${m.file}); edit the source.`);
        const line = HyprlandLua.composeEntry(m, changed);
        if (!line)
            return root.unwritten(m.output, "nothing to write.");

        root.settlingOutput = m.output;
        root.commit(m.file, m.startLine, m.endLine, HyprlandLua.entryReplacement(root.texts[root.pathOf(m.file)] ?? "", m, line));
    }

    function addMonitor(fileName: string, spec: var): void {
        if (root.deferred(() => root.addMonitor(fileName, spec)))
            return;
        const line = HyprlandLua.composeEntry(null, spec);
        if (!line)
            return root.unwritten(spec?.output ?? "", "a monitor entry needs an output and a spec.");

        root.settlingOutput = spec.output ?? "";

        const table = root.outputTable();

        if (table) {
            const text = root.texts[root.pathOf(table.file)] ?? "";
            const closer = text.split("\n")[table.endLine - 1] ?? "";

            const inside = root.monitors.filter(m => m.file === table.file && m.startLine > table.startLine && m.endLine < table.endLine);
            const indent = inside.length ? inside[inside.length - 1].indent : /^[ \t]*/.exec(closer)[0] + "    ";

            root.commit(table.file, table.endLine, table.endLine, [`${indent}${line},`, closer]);
            return;
        }

        const text = root.texts[root.pathOf(fileName)] ?? "";
        const at = HyprlandLua.appendSplice(text, [line]);
        root.commit(fileName, at.startLine, at.endLine, at.replacement);
    }

    function updateBand(id: string, changed: var): void {
        if (root.deferredEntry(() => root.bands, id, resolved => root.updateBand(resolved, changed)))
            return;
        const b = root.bands.find(x => x.id === id);
        if (!b)
            return console.warn(`HyprConfig: no band entry ${id}`);
        if (b.dynamic)
            return console.warn(`HyprConfig: the band for ${b.monitor} is generated by the source (line ${b.startLine} of ${b.file}); edit the source.`);
        const line = HyprlandLua.composeEntry(b, changed);
        if (!line)
            return console.warn("HyprConfig: nothing to write.");
        root.commit(b.file, b.startLine, b.endLine, HyprlandLua.entryReplacement(root.texts[root.pathOf(b.file)] ?? "", b, line));
    }

    function addBand(spec: var): void {
        if (root.deferred(() => root.addBand(spec)))
            return;
        const line = HyprlandLua.composeEntry(null, spec);
        if (!line)
            return console.warn("HyprConfig: a band entry needs a monitor and a range.");

        const table = root.bandTable();
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
    property string stage: ""
    property string trialDirectory: ""
    property string settlingOutput: ""

    signal optionSettled(string path, string device, bool ok, string said)
    signal monitorSettled(string output, bool ok, string said)
    signal writeFailed(string said)

    property var settling: null

    readonly property string configName: root.configPath.slice(root.hyprDir.length + 1)
    readonly property string trialScript: "dir=$(mktemp -d \"${TMPDIR:-/tmp}/banditshell-verify.XXXXXX\") || exit 1; (cd \"$1\" && find -L . -type f \\( -name '*.lua' -o -name '*.conf' \\) -exec cp --no-preserve=mode --parents -t \"$dir\" {} +) && chmod -R u+w \"$dir\" && printf '%s' \"$3\" > \"$dir/$2\" && printf '%s' \"$dir\" || { chmod -R u+w \"$dir\"; rm -rf \"$dir\"; exit 1; }"
    readonly property string discardScript: "case \"$1\" in */banditshell-verify.*) chmod -R u+w \"$1\"; rm -rf \"$1\";; esac"

    function optionFiles(): var {
        return root.files.map(f => ({
                    name: f.name,
                    text: root.texts[f.path] ?? ""
                }));
    }

    function optionRefusal(path: string, device: string): string {
        if (!root.scanned)
            return "the Hyprland config is still being read";
        if (root.configPath.endsWith(".conf"))
            return "this machine uses hyprland.conf, and options are only written to Lua";
        return HyprlandLua.optionBlocked(root.optionFiles(), path, device);
    }

    function optionValue(path: string, device: string): var {
        return HyprlandLua.optionValue(root.optionFiles(), path, device);
    }

    function holderOf(chord: string): var {
        return HyprlandLua.chordHolder(root.binds, chord);
    }

    function settleOption(ok: bool, said: string): void {
        const s = root.settling;
        if (!s)
            return;
        root.settling = null;
        root.optionSettled(s.path, s.device, ok, said);
    }

    function setOption(path: string, value: var, device: string): bool {
        if (root.deferred(() => root.setOption(path, value, device)))
            return true;
        const why = root.optionRefusal(path, device);
        if (why) {
            console.warn(`HyprConfig: ${path}: ${why}.`);
            root.optionSettled(path, device, false, why);
            return false;
        }
        const plan = HyprlandLua.planOption(root.optionFiles(), {
            path,
            value,
            device,
            appendTo: root.shortName(root.configPath)
        });
        if (!plan.ok) {
            console.warn(`HyprConfig: ${plan.reason}`);
            root.optionSettled(path, device, false, plan.reason);
            return false;
        }
        if (plan.unchanged) {
            root.optionSettled(path, device, true, "");
            return true;
        }
        root.settling = {
            path,
            device
        };
        root.commit(plan.file, plan.startLine, plan.endLine, plan.replacement);
        return true;
    }

    function settleWrite(ok: bool, said: string): void {
        const output = root.settlingOutput;
        root.settlingOutput = "";
        const wasOption = !!root.settling;
        root.settleOption(ok, said);
        if (output)
            root.monitorSettled(output, ok, said);
        else if (!wasOption && !ok)
            root.writeFailed(said);
    }

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
            previous: "",
            next: "",
            complaint: ""
        };
        root.begin("reading");
        if (checker.path === path)
            checker.reload();
        else
            checker.path = path;
    }

    function begin(stage: string): void {
        root.stage = stage;
        limit.restart();
    }

    function finishWrite(ok: bool, said: string): void {
        limit.stop();
        root.stage = "";
        root.reverting = false;
        root.discardTrial();
        root.applying = false;
        root.committing = null;
        root.rescan();
        root.settleWrite(ok, said);
    }

    function abandon(why: string): void {
        console.warn(`HyprConfig: ${why}; nothing was written, rescanning.`);
        root.finishWrite(false, why);
    }

    function discardTrial(): void {
        if (!root.trialDirectory)
            return;
        Quickshell.execDetached(["sh", "-c", root.discardScript, "sh", root.trialDirectory]);
        root.trialDirectory = "";
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
        c.next = next;
        root.runVerify("baseline", root.configPath);
    }

    FileView {
        id: checker

        watchChanges: false
        printErrors: false

        onLoaded: root.write(checker.text())
        onLoadFailed: root.write(null)
    }

    Timer {
        id: limit

        interval: 15000
        onTriggered: root.stalled()
    }

    function stalled(): void {
        const stage = root.stage;
        console.warn(`HyprConfig: the ${stage} step did not finish in time.`);
        if (stage === "baseline" || stage === "trial" || stage === "verifying") {
            verifier.running = false;
            root.verifyEnded(-1, false, "", "Hyprland --verify-config did not finish in time");
        } else if (stage === "preparing") {
            trialMaker.running = false;
            root.trialMade("");
        } else if (stage === "reloading") {
            reloader.running = false;
            root.reloaded();
        } else if (stage === "reading") {
            root.abandon("the file did not read in time");
        } else {
            root.finishWrite(false, `the ${stage} step did not finish in time, so ${root.committing?.file ?? "the config"} may need a look`);
        }
    }

    function runVerify(purpose: string, config: string): void {
        verifier.purpose = purpose;
        verifier.began = false;
        verifier.live = true;
        verifier.command = ["Hyprland", "--verify-config", "-c", config];
        root.begin(purpose);
        verifier.running = true;
    }

    function verifyEnded(code: int, crashed: bool, output: string, trouble: string): void {
        if (!verifier.live)
            return;
        verifier.live = false;
        const ok = !trouble && code === 0 && !crashed;
        const report = trouble || (ok ? "" : HyprlandLua.verifyReport(output, code, crashed, root.trialDirectory ? [`${root.trialDirectory}/`, `${root.hyprDir}/`] : [`${root.hyprDir}/`]));
        root.verified(verifier.purpose, ok, report, !!trouble);
    }

    function verified(purpose: string, ok: bool, report: string, broken: bool): void {
        if (purpose === "baseline") {
            if (ok)
                return root.prepareTrial();
            return root.abandon(broken ? report : HyprlandLua.baselineRefusal(report));
        }
        if (purpose === "trial") {
            if (ok)
                return root.writeReal();
            return root.abandon(report);
        }
        if (ok)
            return root.reload();
        console.warn(`HyprConfig: the edit did not verify; putting the previous text back.\n${report}`);
        root.committing.complaint = report || "Hyprland did not accept it";
        root.begin("checking");
        if (rechecker.path === root.committing.path)
            rechecker.reload();
        else
            rechecker.path = root.committing.path;
    }

    function prepareTrial(): void {
        const c = root.committing;
        if (!c.path.startsWith(`${root.hyprDir}/`))
            return root.writeReal();
        trialMaker.began = false;
        trialMaker.live = true;
        trialMaker.command = ["sh", "-c", root.trialScript, "sh", root.hyprDir, c.file, c.next];
        root.begin("preparing");
        trialMaker.running = true;
    }

    function trialMade(directory: string): void {
        if (!trialMaker.live)
            return;
        trialMaker.live = false;
        if (!directory) {
            console.warn("HyprConfig: no trial copy to check first; writing the config directly.");
            return root.writeReal();
        }
        root.trialDirectory = directory;
        root.runVerify("trial", `${directory}/${root.configName}`);
    }

    function writeReal(): void {
        const c = root.committing;
        root.reverting = false;
        root.begin("writing");
        writer.path = c.path;
        writer.setText(c.next);
    }

    function rechecked(disk: var): void {
        const c = root.committing;
        if (!c)
            return;
        if ((disk ?? "") !== c.next)
            return root.finishWrite(false, `${c.complaint} · ${c.file} was changed meanwhile, so it was left as it is`);
        root.reverting = true;
        root.begin("reverting");
        writer.setText(c.previous);
    }

    FileView {
        id: rechecker

        watchChanges: false
        printErrors: false

        onLoaded: root.rechecked(rechecker.text())
        onLoadFailed: root.rechecked(null)
    }

    FileView {
        id: writer

        watchChanges: false
        printErrors: false

        onSaved: {
            if (!root.reverting)
                return root.runVerify("verifying", root.configPath);
            root.finishWrite(false, root.committing?.complaint ?? "Hyprland did not accept it");
        }

        onSaveFailed: {
            console.warn(`HyprConfig: could not write ${root.committing?.path}; ${root.reverting ? "the failed edit is still on disk" : "the edit is not on disk"}.`);
            root.finishWrite(false, root.reverting ? `${root.committing?.complaint ?? ""} · and the file could not be written back` : "the file could not be written");
        }
    }

    Process {
        id: trialMaker

        property bool began: false
        property bool live: false

        stdout: StdioCollector {
            onStreamFinished: root.trialMade(text.trim())
        }

        onStarted: trialMaker.began = true

        onRunningChanged: {
            if (!trialMaker.running && !trialMaker.began)
                root.trialMade("");
        }
    }

    Process {
        id: verifier

        property string purpose: ""
        property bool began: false
        property bool live: false

        stdout: StdioCollector {
            id: verifyOut
        }

        stderr: StdioCollector {
            id: verifyErr
        }

        onStarted: verifier.began = true

        onExited: (code, status) => root.verifyEnded(code, status === 1, `${verifyOut.text}${verifyErr.text}`, "")

        onRunningChanged: {
            if (!verifier.running && !verifier.began)
                root.verifyEnded(-1, false, "", "Hyprland --verify-config did not start");
        }
    }

    function reload(): void {
        reloader.began = false;
        reloader.live = true;
        root.begin("reloading");
        reloader.running = true;
    }

    function reloaded(): void {
        if (!reloader.live)
            return;
        reloader.live = false;
        root.finishWrite(true, "");
    }

    Process {
        id: reloader

        property bool began: false
        property bool live: false

        command: ["hyprctl", "reload"]

        onStarted: reloader.began = true

        onRunningChanged: {
            if (!reloader.running)
                root.reloaded();
        }
    }
}
