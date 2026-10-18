import QtQuick
import Quickshell
import qs.config
import qs.services
import "../../../services/shell-actions.js" as Logic
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["action"]

    readonly property bool enabled: Config.values.launcher.shell.actions !== false
    readonly property var asked: root.enabled ? Logic.ask(root.search.text) : null

    readonly property bool intent: root.asked !== null

    readonly property bool wanted: root.enabled && root.search.text.length >= 3

    readonly property var listing: root.wanted || root.asked ? ShellActions.rows : []

    readonly property var items: {
        if (root.asked)
            return Logic.matching(root.listing, root.asked.words, Ranking.place, 12).map((entry, i) => root.row(entry, i === 0 ? Infinity : 100));
        if (root.wanted)
            return Logic.ambient(root.listing, root.search.text, Ranking.place, 3).map(hit => root.row(hit.row, hit.score));
        return [];
    }

    readonly property var caps: ({
            actions: 12
        })

    readonly property var groups: [
        {
            key: "actions",
            title: "Actions",
            items: root.items
        }
    ]

    readonly property var phrases: [
        {
            head: "action ",
            picks: [""]
        }
    ]

    function row(entry: var, score: real): var {
        const arming = root.search.armed === `action:${entry.id}`;
        return {
            key: `action:${entry.id}`,
            kind: "action",
            action: entry,
            armed: arming,
            label: arming ? `Press Enter again to ${entry.label.charAt(0).toLowerCase()}${entry.label.slice(1)}` : entry.label,
            detail: arming ? "" : entry.id,
            icon: "bolt",
            ask: entry.args?.required ? {
                prompt: entry.args.prompt,
                icon: "bolt",
                suggestion: "",
                take: text => root.run(entry, text)
            } : undefined,
            score: score
        };
    }

    function rowById(id: string): var {
        if (!root.enabled || id.indexOf("action:") !== 0)
            return null;
        const entry = ShellActions.rows.find(e => `action:${e.id}` === id);
        return entry && !entry.args?.required && !entry.destructive ? root.row(entry, 0) : null;
    }

    function run(entry: var, text: string): void {
        const argv = Logic.argv(entry, text);
        root.search.leave(() => Quickshell.execDetached([`${Quickshell.shellDir}/cli/banditshell`, ...argv]));
    }

    function activate(row: var): void {
        const entry = row.action;
        if (entry.args?.required)
            return;
        if (entry.destructive && root.search.armed !== row.key) {
            root.search.armed = row.key;
            return;
        }
        root.search.armed = "";
        root.run(entry, "");
    }

    function confirmActionsFor(row: var): var {
        return [
            {
                icon: "play_arrow",
                label: "Run",
                alarm: true,
                run: () => root.activate(row)
            }
        ];
    }

    function actionsFor(row: var): var {
        if (row.action.args?.required)
            return [];
        return [
            {
                icon: "play_arrow",
                label: "Run",
                run: () => root.activate(row)
            }
        ];
    }
}
