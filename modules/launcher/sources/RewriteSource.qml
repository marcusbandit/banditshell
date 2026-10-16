import QtQuick
import Quickshell
import qs.services
import "../../../services/assistant.js" as Logic
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["rewrite"]

    property Connections opening: Connections {
        target: root.search

        function onStartedChanged(): void {
            if (root.search.started && Assistant.enabled)
                Assistant.readSelection();
        }
    }

    readonly property string selected: Assistant.selection.trim() && Assistant.selection !== root.search.query ? Assistant.selection : ""

    readonly property bool usable: Assistant.ready && !!root.selected && root.search.text.length >= 3

    readonly property string quoted: root.selected ? `“${Logic.snippet(root.selected, 48)}”` : ""

    function score(action: var): real {
        return Math.max(Ranking.place(action.label, root.search.text), Ranking.place(`${action.words} selection selected rewrite`, root.search.text) - 0.5);
    }

    function rowFor(action: var, detail: string, direct: bool): var {
        return {
            key: `rewrite:${action.id}`,
            kind: "rewrite",
            actionId: action.id,
            label: action.label,
            detail: detail,
            icon: action.icon,
            direct: direct,
            score: direct ? 0 : root.score(action)
        };
    }

    readonly property var groups: [
        {
            key: "selection",
            title: "Selected text",
            items: !root.usable ? [] : Logic.ACTIONS.filter(a => !root.showing(a)).map(a => root.rowFor(a, "", false)).filter(r => r.score > 0).sort((a, b) => b.score - a.score).map((r, i) => i ? r : Object.assign(r, {
                        detail: root.quoted
                    }))
        }
    ]

    function showing(action: var): bool {
        return Assistant.kind === "rewrite" && Assistant.actionId === action.id && !Assistant.error && Assistant.shownFor(root.search.text);
    }

    function rowById(id: string): var {
        if (id.indexOf("rewrite:") !== 0)
            return null;
        const action = Logic.actionOf(id.slice(8));
        return action ? root.rowFor(action, "", true) : null;
    }

    function activate(row: var): void {
        if (row.direct) {
            Assistant.rewriteSelection(row.actionId);
            return;
        }
        if (Assistant.streaming && Assistant.topic === root.search.text && Assistant.actionId === row.actionId)
            return;
        Assistant.rewrite(row.actionId, root.selected, root.search.text, false);
    }

    function actionsFor(row: var): var {
        return [
            {
                icon: row.icon,
                label: row.label,
                run: () => root.activate(row)
            }
        ];
    }
}
