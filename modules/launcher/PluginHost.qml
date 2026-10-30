pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import "../../services/plugin-protocol.js" as Protocol

Singleton {
    id: root

    readonly property string folder: `${Config.dir}/plugins`
    readonly property string logDir: `${Config.stateDir}/plugins`
    readonly property string listing: `${Config.stateDir}/plugins.json`
    readonly property string secretsPath: `${Config.stateDir}/plugin-secrets.json`
    readonly property var off: Config.values.launcher.plugins.off
    readonly property var values: Config.values.launcher.plugins.values

    property var found: []
    property var secrets: ({})
    property var answers: ({})
    property var states: ({})
    property var processes: ({})
    property var askers: ({})
    property var registered: ({})
    property real scannedAt: 0

    function logOf(id: string): string {
        return `${root.logDir}/${id}.log`;
    }

    function entryOf(id: string): var {
        return root.found.find(e => e.id === id) ?? null;
    }

    function pluginOf(id: string): var {
        return root.entryOf(id)?.plugin ?? null;
    }

    function valuesOf(id: string): var {
        return root.values[id] ?? {};
    }

    function secretsOf(id: string): var {
        return root.secrets[id] ?? {};
    }

    function missingOf(id: string): var {
        const plugin = root.pluginOf(id);
        return plugin ? Protocol.missing(plugin, root.valuesOf(id), root.secretsOf(id)) : [];
    }

    function stateOf(id: string): var {
        return root.states[id] ?? {
            crashes: [],
            off: false,
            until: 0
        };
    }

    function setState(id: string, state: var): void {
        root.states = Object.assign({}, root.states, {
            [id]: state
        });
        root.writeListing();
    }

    function setAnswer(id: string, answer: var): void {
        root.answers = Object.assign({}, root.answers, {
            [id]: answer
        });
    }

    function refresh(): void {
        if (scanner.running || Date.now() - root.scannedAt < 2000)
            return;
        secretsFile.reload();
        scanner.running = true;
    }

    function readScan(text: string): var {
        return text.split("\x1e").slice(1).map(chunk => {
            const cut = chunk.indexOf("\n");
            const folder = chunk.slice(0, cut);
            const read = Protocol.readManifest(chunk.slice(cut + 1), folder);
            return read.plugin ? {
                id: read.plugin.id,
                name: read.plugin.name,
                plugin: read.plugin
            } : {
                id: read.id,
                name: read.name ?? read.id,
                error: read.error
            };
        });
    }

    function sync(): void {
        const wanted = {};
        for (const entry of root.found)
            if (entry.plugin && !root.off.includes(entry.id))
                wanted[entry.id] = JSON.stringify([entry.plugin, root.valuesOf(entry.id), root.secretsOf(entry.id)]);
        const next = {};
        const answers = Object.assign({}, root.answers);
        for (const id of Object.keys(root.registered))
            if (wanted[id] !== root.registered[id]) {
                LauncherSources.remove(`plugin:${id}`);
                root.stop(id);
                delete answers[id];
            }
        root.answers = answers;
        for (const id of Object.keys(wanted)) {
            if (root.registered[id] === undefined && root.stateOf(id).off)
                root.revive(id);
            if (root.registered[id] !== wanted[id])
                LauncherSources.add(`plugin:${id}`, source, {
                    pluginId: id
                });
            next[id] = wanted[id];
        }
        root.registered = next;
        root.writeListing();
    }

    function writeListing(): void {
        if (!root.scannedAt)
            return;
        listingFile.setText(JSON.stringify(root.found.map(e => ({
                        id: e.id,
                        name: e.name,
                        about: e.plugin?.about ?? "",
                        icon: e.plugin?.icon ?? {},
                        prefix: e.plugin?.prefix ?? [],
                        global: !!e.plugin?.global,
                        preferences: e.plugin?.preferences ?? [],
                        error: e.error ?? "",
                        crashed: root.stateOf(e.id).off,
                        log: root.logOf(e.id)
                    })), null, 2) + "\n");
    }

    function ensure(id: string): var {
        const had = root.processes[id];
        if (had)
            return had;
        const plugin = root.pluginOf(id);
        const proc = runner.createObject(root, {
            pluginId: id,
            exec: plugin.exec,
            folder: plugin.folder,
            log: root.logOf(id),
            env: Protocol.environment(plugin, root.valuesOf(id), root.secretsOf(id))
        });
        proc.said.connect(line => root.heard(id, proc, line));
        proc.ended.connect(wanted => root.ended(id, proc, wanted));
        root.processes = Object.assign({}, root.processes, {
            [id]: proc
        });
        proc.running = true;
        return proc;
    }

    function stop(id: string): void {
        const proc = root.processes[id];
        if (proc)
            proc.stop();
    }

    function usable(id: string): bool {
        const state = root.stateOf(id);
        return !!root.pluginOf(id) && !state.off && Date.now() >= state.until && !root.missingOf(id).length;
    }

    function ask(id: string, text: string, prefixed: bool, asker: var): void {
        if (!root.usable(id))
            return;
        const had = root.answers[id];
        if (had && had.text === text && had.prefixed === prefixed && (had.waiting || had.answered))
            return;
        const proc = root.ensure(id);
        if (had?.waiting)
            proc.send(Protocol.cancelLine(had.seq));
        const seq = (had?.seq ?? 0) + 1;
        root.askers = Object.assign({}, root.askers, {
            [id]: asker
        });
        root.setAnswer(id, {
            seq: seq,
            text: text,
            prefixed: prefixed,
            items: had?.items ?? [],
            waiting: true,
            answered: false,
            at: Date.now()
        });
        proc.send(Protocol.queryLine(seq, text, prefixed));
        patience.restart();
    }

    function activate(id: string, item: string, action: string, asker: var): void {
        if (!root.usable(id))
            return;
        root.askers = Object.assign({}, root.askers, {
            [id]: asker
        });
        root.ensure(id).send(Protocol.activateLine(root.answers[id]?.seq ?? 0, item, action));
    }

    function complete(id: string, item: string, asker: var): void {
        if (!root.usable(id))
            return;
        root.askers = Object.assign({}, root.askers, {
            [id]: asker
        });
        root.ensure(id).send(Protocol.completeLine(item));
    }

    function heard(id: string, proc: var, line: string): void {
        if (root.processes[id] !== proc || !line.trim())
            return;
        const message = Protocol.readMessage(line);
        if (message.error) {
            root.note(id, `skipped ${message.error}`);
            return;
        }
        if (message.type === "results") {
            const had = root.answers[id];
            if (had && message.seq === had.seq)
                root.setAnswer(id, Object.assign({}, had, {
                    items: message.items,
                    waiting: false,
                    answered: true
                }));
            return;
        }
        root.askers[id]?.handle?.(message);
    }

    function ended(id: string, proc: var, wanted: bool): void {
        if (root.processes[id] === proc) {
            const next = Object.assign({}, root.processes);
            delete next[id];
            root.processes = next;
            const had = root.answers[id];
            if (had?.waiting)
                root.setAnswer(id, Object.assign({}, had, {
                    waiting: false,
                    answered: false
                }));
            if (!wanted) {
                const now = Date.now();
                const crashed = Protocol.crashes(root.stateOf(id).crashes.concat([now]), now);
                root.setState(id, {
                    crashes: crashed.recent,
                    off: crashed.off,
                    until: now + crashed.delay
                });
                root.note(id, crashed.off ? "stopped after three crashes in a minute" : `exited, starting again on the next query after ${crashed.delay / 1000} s`);
            }
        }
        proc.destroy();
    }

    function revive(id: string): void {
        root.setState(id, {
            crashes: [],
            off: false,
            until: 0
        });
    }

    function note(id: string, text: string): void {
        noter.createObject(root, {
            command: ["sh", "-c", 'mkdir -p "${1%/*}" && printf "banditshell: %s\\n" "$2" >>"$1"', "sh", root.logOf(id), text]
        });
    }

    onOffChanged: root.sync()
    onValuesChanged: root.sync()
    onSecretsChanged: root.sync()

    Component.onCompleted: root.refresh()

    property Component source: Component {
        PluginSource {}
    }

    property Component runner: Component {
        PluginProcess {}
    }

    property Component noter: Component {
        Process {
            running: true
            onExited: destroy()
        }
    }

    property Timer patience: Timer {
        interval: 250
        repeat: true
        running: Object.values(root.answers).some(a => a.waiting)
        onTriggered: {
            const now = Date.now();
            for (const id of Object.keys(root.answers)) {
                const had = root.answers[id];
                if (!had.waiting || now - had.at < 2000)
                    continue;
                root.processes[id]?.send(Protocol.cancelLine(had.seq));
                root.setAnswer(id, Object.assign({}, had, {
                    items: [],
                    waiting: false,
                    answered: true,
                    late: true
                }));
                root.note(id, `no answer to query ${had.seq} within 2 s`);
            }
        }
    }

    property Process scanner: Process {
        command: ["sh", "-c", 'for d in "$1"/*/; do f="${d}plugin.json"; [ -f "$f" ] || continue; printf "\\036%s\\n" "${d%/}"; head -c 65536 "$f"; done', "sh", root.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                root.found = root.readScan(text);
                root.scannedAt = Date.now();
                root.sync();
            }
        }
    }

    property FileView listingFile: FileView {
        path: root.listing
        printErrors: false
    }

    property FileView secretsFile: FileView {
        path: root.secretsPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.secrets = data && typeof data === "object" && !Array.isArray(data) ? data : {};
            } catch (e) {
                root.secrets = {};
            }
        }
    }
}
