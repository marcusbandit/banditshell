pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "../modules/workshop/layout-model.js" as LayoutModel
import "../modules/workshop/layout-lua.js" as LayoutLua
import "../modules/launcher/search.js" as Search

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/layouts.json`
    readonly property string folder: `${Config.stateDir}/layouts`

    readonly property bool possible: Compositor.isHyprland && Hypr.parserKnown && Hypr.lua

    property var layouts: []
    property bool loaded: false
    property bool keep: true

    property var ready: ({})
    property string said: ""
    property bool failed: false
    readonly property bool working: worker.running || root.job !== null || root.queue.length > 0

    property var queue: []
    property var job: null
    property bool began: false
    property bool exited: false
    property bool read: false
    property string output: ""
    property int code: 0

    readonly property string fallbackLayout: WindowLayouts.configured[0] ?? "dwindle"

    readonly property var names: root.layouts.filter(model => root.isReady(model.name)).map(model => `lua:${model.name}`)

    readonly property var taken: Search.luaLayouts(Object.values(HyprConfig.texts)).map(name => name.replace(/^lua:/, "")).filter(name => !root.layouts.some(model => model.name === name))

    function isReady(name: string): bool {
        return root.ready[name] === true;
    }

    function find(name: string): var {
        return root.layouts.find(model => model.name === name) ?? null;
    }

    function fileOf(name: string): string {
        return `${root.folder}/${name}.lua`;
    }

    function problemWith(model: var, previous: string): string {
        const others = root.layouts.map(other => other.name).filter(name => name !== previous);
        if (others.indexOf(model.name) >= 0)
            return "you already have a layout with that name";
        return LayoutModel.nameProblem(model.name, root.taken);
    }

    function save(draft: var, previous: string, then: var): string {
        if (!root.loaded)
            return "still reading your saved layouts";
        if (!root.keep)
            return `${root.path} could not be read, so nothing is saved over it`;
        const model = LayoutModel.normalise(draft);
        const problem = root.problemWith(model, previous);
        if (problem)
            return problem;
        const next = root.layouts.filter(other => other.name !== previous && other.name !== model.name);
        const at = root.layouts.findIndex(other => other.name === (previous || model.name));
        next.splice(at < 0 ? next.length : Math.min(at, next.length), 0, model);
        root.layouts = next;
        root.persist();
        const renamedInUse = !!previous && previous !== model.name && WindowLayouts.current === `lua:${previous}`;
        if (previous && previous !== model.name)
            root.forget(previous);
        root.enqueue({
            writes: [model],
            names: [model.name],
            afterReload: false,
            then: () => {
                if (renamedInUse && root.isReady(model.name))
                    WindowLayouts.use(`lua:${model.name}`);
                if (then)
                    then();
            }
        });
        return "";
    }

    function use(draft: var, previous: string): string {
        const name = LayoutModel.normalise(draft).name;
        return root.save(draft, previous, () => {
            if (root.isReady(name))
                WindowLayouts.use(`lua:${name}`);
        });
    }

    function remove(name: string): void {
        if (!root.loaded || !root.keep)
            return;
        root.layouts = root.layouts.filter(model => model.name !== name);
        root.persist();
        root.forget(name);
        if (WindowLayouts.current === `lua:${name}`)
            WindowLayouts.use(root.fallbackLayout);
    }

    function forget(name: string): void {
        const next = Object.assign({}, root.ready);
        delete next[name];
        root.ready = next;
        root.enqueue({
            removes: [name]
        });
    }

    function loadAll(afterReload: bool): void {
        if (!root.loaded || !root.layouts.length)
            return;
        root.enqueue({
            writes: root.layouts.slice(),
            names: root.layouts.map(model => model.name),
            afterReload: afterReload,
            then: null
        });
    }

    function persist(): void {
        if (!root.keep || !root.loaded)
            return;
        store.setText(JSON.stringify({
            layouts: root.layouts
        }, null, 2) + "\n");
    }

    function enqueue(job: var): void {
        root.queue = root.queue.concat([job]);
        root.advance();
    }

    function advance(): void {
        if (worker.running || root.job || !root.queue.length)
            return;
        const job = root.queue[0];
        root.queue = root.queue.slice(1);
        root.job = job;
        root.began = false;
        root.exited = false;
        root.read = false;
        root.output = "";
        root.code = 0;
        if (job.removes) {
            worker.command = ["sh", "-c", 'cd -- "$1" 2>/dev/null || exit 0; shift; for name in "$@"; do rm -f -- "$name.lua"; done', "sh", root.folder].concat(job.removes);
        } else {
            const code = root.possible ? LayoutLua.loader(job.names.map(name => root.fileOf(name)), job.afterReload) : "";
            const pairs = [];
            for (const model of job.writes)
                pairs.push(model.name, LayoutLua.generate(model));
            worker.command = ["sh", "-c", 'exec 2>&1; dir=$1; code=$2; shift 2; mkdir -p -- "$dir" || exit 1; while [ $# -gt 1 ]; do printf %s "$2" > "$dir/$1.lua.part" && mv -f -- "$dir/$1.lua.part" "$dir/$1.lua" || exit 1; shift 2; done; [ -n "$code" ] || exit 0; command -v hyprctl > /dev/null || { echo "hyprctl is not installed"; exit 3; }; exec hyprctl eval "$code"', "sh", root.folder, code].concat(pairs);
        }
        worker.running = true;
    }

    function finish(): void {
        if (root.job && root.exited && root.read)
            root.settle(root.output, root.code);
    }

    function settle(output: string, code: int): void {
        const job = root.job;
        root.job = null;
        if (job && job.writes) {
            const text = output.trim();
            const evalError = text.startsWith("error:");
            const answered = root.possible && (text === "ok" || evalError);
            const named = evalError ? LayoutLua.failedNames(text, job.names, root.folder) : [];
            const broken = evalError && !named.length ? job.names : named;
            const next = Object.assign({}, root.ready);
            for (const name of job.names)
                next[name] = answered && broken.indexOf(name) < 0;
            root.ready = next;
            root.failed = root.possible ? text !== "ok" : code !== 0;
            const trouble = text.replace(/^error:\s*/, "") || `could not write ${root.folder}`;
            if (!root.possible)
                root.said = root.failed ? trouble : "saved · loading needs Hyprland with a Lua config";
            else
                root.said = root.failed ? trouble : job.names.length === 1 ? `lua:${job.names[0]} is loaded` : `${job.names.length} layouts loaded`;
            if (job.then)
                job.then();
        }
        Qt.callLater(root.advance);
    }

    onPossibleChanged: if (root.possible)
        root.loadAll(false)

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.loadAll(true);
        }
    }

    Process {
        id: worker

        stdout: StdioCollector {
            onStreamFinished: {
                root.output = text;
                root.read = true;
                root.finish();
            }
        }

        onStarted: root.began = true

        onExited: exitCode => {
            root.code = exitCode;
            root.exited = true;
            root.finish();
        }

        onRunningChanged: {
            if (worker.running || root.began || !root.job)
                return;
            root.code = -1;
            root.output = "";
            root.read = true;
            root.exited = true;
            root.finish();
        }
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.layouts = (Array.isArray(data.layouts) ? data.layouts : []).map(model => LayoutModel.normalise(model));
            } catch (e) {
                console.warn(`WorkshopLayouts: ${root.path} is not valid JSON; it is left alone and nothing saved now is kept.`);
                root.keep = false;
            }
            root.loaded = true;
            if (root.possible)
                root.loadAll(false);
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound) {
                console.warn(`WorkshopLayouts: could not read ${root.path} (${err}); layouts saved now will not be kept.`);
                root.keep = false;
            }
            root.loaded = true;
        }
    }
}
