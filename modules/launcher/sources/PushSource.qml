import QtQuick
import Quickshell
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/pushed-rows.js" as Pushed

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["pushed"]

    readonly property string text: root.search.text

    function rowOf(pushed: var, score: real): var {
        const icon = Pushed.iconOf(pushed);
        return {
            key: `pushed:${pushed.tool}:${pushed.id}`,
            kind: "pushed",
            pushed: pushed,
            label: pushed.title,
            detail: pushed.subtitle,
            icon: icon.name ?? "push_pin",
            glyph: icon.glyph ?? "",
            iconSource: icon.file ? Pushed.fileUrl(icon.file) : "",
            score: score
        };
    }

    readonly property var groups: {
        if (root.text.length < 2)
            return [];
        const byTool = Object.create(null);
        const now = Date.now();
        for (const pushed of PushedRows.rows) {
            if (pushed.expires && pushed.expires <= now)
                continue;
            const score = Pushed.scoreOf(pushed, root.text, Ranking.place);
            if (score <= 0)
                continue;
            (byTool[pushed.tool] = byTool[pushed.tool] ?? []).push(root.rowOf(pushed, score));
        }
        return Object.keys(byTool).sort().map(tool => ({
                    key: `pushed:${tool}`,
                    title: Pushed.titleOfTool(tool),
                    items: byTool[tool].sort((a, b) => b.score - a.score)
                }));
    }

    readonly property var caps: root.groups.reduce((out, g) => Object.assign(out, {
            [g.key]: 6
        }), ({}))

    function doing(pushed: var): var {
        if (pushed.open)
            return {
                icon: "open_in_new",
                label: "Open",
                run: () => root.search.launch(() => System.openWith(pushed.open))
            };
        if (pushed.copy)
            return {
                icon: "content_copy",
                label: "Copy",
                run: () => root.search.leave(() => System.copyText(pushed.copy))
            };
        if (pushed.run.length)
            return {
                icon: "play_arrow",
                label: "Run",
                run: () => root.search.launch(() => Quickshell.execDetached(pushed.run))
            };
        return null;
    }

    function activate(row: var): void {
        root.doing(row.pushed)?.run();
    }

    function actionsFor(row: var): var {
        const pushed = row.pushed;
        const first = root.doing(pushed);
        return (first ? [first] : []).concat([
            {
                icon: "remove_circle_outline",
                label: "Remove from launcher",
                short: "Remove",
                run: () => PushedRows.remove(pushed.tool, pushed.id)
            }
        ]);
    }

    function rowById(id: string): var {
        const parts = /^pushed:([^:]+):(.+)$/.exec(id);
        const pushed = parts ? PushedRows.rowFor(parts[1], parts[2]) : null;
        return pushed ? root.rowOf(pushed, 1) : null;
    }
}
