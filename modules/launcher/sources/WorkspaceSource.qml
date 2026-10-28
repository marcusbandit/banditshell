import QtQuick
import qs.config
import qs.services
import "../../../services/special-workspaces.js" as Logic
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["special"]

    readonly property bool enabled: Config.values.launcher.shell.workspaces !== false
    readonly property var asked: root.enabled ? Logic.ask(root.search.text) : null

    readonly property bool intent: root.asked !== null

    readonly property var found: root.asked ? Logic.matching(Logic.listed(Hypr.specials), root.asked.words, Ranking.place, 12) : []

    readonly property var caps: ({
            special: 12
        })

    readonly property var prefixes: !root.enabled ? [] : [
            {
                section: "Desktop",
                word: "scratch",
                example: "scratch term",
                about: "Scratchpads",
                icon: "layers",
                also: ["scratchpad", "special"]
            }
        ]

    readonly property var groups: [
        {
            key: "special",
            title: "Special workspaces",
            items: root.found.map((entry, i) => root.row(entry, i === 0))
        }
    ]

    readonly property var phrases: [
        {
            head: "special ",
            picks: [""]
        }
    ]

    function row(entry: var, first: bool): var {
        const shown = Hypr.specialOn(root.search.screenName) === `special:${entry.name}`;
        return {
            key: `special:${entry.name}`,
            kind: "special",
            name: entry.name,
            label: Logic.labelOf(entry),
            detail: Logic.detailOf(entry, shown),
            icon: "layers",
            toggle: shown,
            score: first ? Infinity : 100
        };
    }

    function rowById(id: string): var {
        if (!root.enabled || id.indexOf("special:") !== 0)
            return null;
        const entry = Logic.listed(Hypr.specials).find(e => e.name === id.slice(8));
        return entry ? root.row(entry, false) : null;
    }

    function activate(row: var): void {
        const name = row.name;
        root.search.leave(() => Hypr.toggleSpecial(name));
    }

    function actionsFor(row: var): var {
        const name = row.name;
        const window = root.search.windowTarget();
        const acts = [
            {
                icon: "layers",
                label: row.toggle ? "Hide" : "Show",
                run: () => root.activate(row)
            }
        ];
        if (window)
            acts.push({
                icon: "move_item",
                label: "Send this window here",
                short: "Send",
                run: () => root.search.leave(() => Hypr.moveToWorkspace(window, `special:${name}`))
            });
        return acts;
    }
}
