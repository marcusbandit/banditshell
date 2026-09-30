pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.config

QtObject {
    id: root

    property string cwd: ""

    property var entries: []
    property bool loading: false

    property string error: ""

    property int cursor: -1

    property var picked: []

    property int anchor: -1

    property string search: ""
    property bool searching: false

    property string lister: ""

    signal wantsCd(string path)

    readonly property bool showHidden: Config.values.files.hidden
    readonly property string sort: Config.values.files.sort

    readonly property var visible: {
        const all = root.entries.filter(e => root.showHidden || !e.hidden);
        const query = root.search.toLowerCase();
        const matched = query === "" ? all : all.filter(e => e.name.toLowerCase().includes(query));

        const key = root.sort;
        return matched.slice().sort((a, b) => {
            if ((a.kind === "dir") !== (b.kind === "dir"))
                return a.kind === "dir" ? -1 : 1;
            if (key === "size" && a.size !== b.size)
                return b.size - a.size;
            if (key === "mtime" && a.mtime !== b.mtime)
                return b.mtime - a.mtime;
            if (key === "kind" && a.class !== b.class)
                return a.class < b.class ? -1 : 1;
            return a.name.localeCompare(b.name, undefined, {numeric: true, sensitivity: "base"});
        });
    }

    readonly property var current: root.cursor >= 0 && root.cursor < root.visible.length ? root.visible[root.cursor] : null
    readonly property string currentPath: root.current ? root.join(root.cwd, root.current.name) : ""

    readonly property var picks: {
        const names = root.picked;
        if (names.length === 0)
            return root.current ? [root.current] : [];
        return root.visible.filter(e => names.includes(e.name));
    }

    readonly property var pickedPaths: root.picks.map(e => root.join(root.cwd, e.name))

    readonly property var crumbs: {
        const parts = root.cwd.split("/").filter(p => p.length > 0);
        const out = [{name: "/", path: "/"}];
        let path = "";
        for (const part of parts) {
            path += `/${part}`;
            out.push({name: part, path: path});
        }
        return out;
    }

    function join(dir: string, name: string): string {
        return dir === "/" ? `/${name}` : `${dir}/${name}`;
    }

    function parentOf(path: string): string {
        if (path === "/")
            return "/";
        const cut = path.lastIndexOf("/");
        return cut <= 0 ? "/" : path.slice(0, cut);
    }

    function isPicked(name: string): bool {
        return root.picked.includes(name);
    }

    function setCursor(index: int): void {
        if (index < 0 || index >= root.visible.length)
            return;
        root.cursor = index;
        root.anchor = index;
        root.picked = [root.visible[index].name];
    }

    function togglePick(index: int): void {
        if (index < 0 || index >= root.visible.length)
            return;
        const name = root.visible[index].name;
        root.picked = root.isPicked(name) ? root.picked.filter(n => n !== name) : [...root.picked, name];
        root.cursor = index;
        root.anchor = index;
    }

    function extendTo(index: int): void {
        if (index < 0 || index >= root.visible.length)
            return;
        const from = root.anchor < 0 ? index : root.anchor;
        const lo = Math.min(from, index);
        const hi = Math.max(from, index);
        root.picked = root.visible.slice(lo, hi + 1).map(e => e.name);
        root.cursor = index;
    }

    function pickRange(indices: var, add: bool): void {
        const names = indices.filter(i => i >= 0 && i < root.visible.length).map(i => root.visible[i].name);
        root.picked = add ? [...new Set([...root.picked, ...names])] : names;
    }

    function pickAll(): void {
        root.picked = root.visible.map(e => e.name);
    }

    function clearPicked(): void {
        root.picked = [];
    }

    function refresh(): void {
        if (!root.lister || !root.cwd)
            return;
        list.running = false;
        list.command = [root.lister, root.cwd];
        list.running = true;
    }

    onCwdChanged: {
        root.cursor = -1;
        root.anchor = -1;
        root.picked = [];
        root.search = "";
        root.searching = false;
        root.refresh();
    }

    property Process listing: Process {
        id: list

        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const answer = JSON.parse(text);

                    if (answer.path !== root.cwd)
                        return;
                    root.error = answer.ok ? "" : answer.error;
                    root.entries = answer.ok ? answer.entries : [];

                    root.picked = root.picked.filter(n => root.visible.some(e => e.name === n));
                    if (root.cursor < 0 || root.cursor >= root.visible.length)
                        root.cursor = root.visible.length > 0 ? 0 : -1;
                } catch (e) {
                    root.error = "unreadable listing";
                    root.entries = [];
                }
            }
        }

        onRunningChanged: if (running)
            root.loading = true
    }

    property var back: []
    property var forward: []

    function go(path: string): void {
        if (path === root.cwd)
            return;
        root.back = [...root.back, root.cwd];
        root.forward = [];
        root.wantsCd(path);
    }

    function goBack(): void {
        if (root.back.length === 0)
            return;
        const to = root.back[root.back.length - 1];
        root.back = root.back.slice(0, -1);
        root.forward = [root.cwd, ...root.forward];
        root.wantsCd(to);
    }

    function goForward(): void {
        if (root.forward.length === 0)
            return;
        const to = root.forward[0];
        root.forward = root.forward.slice(1);
        root.back = [...root.back, root.cwd];
        root.wantsCd(to);
    }
}
