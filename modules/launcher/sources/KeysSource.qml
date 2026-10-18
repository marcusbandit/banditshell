import QtQuick
import qs.config
import qs.services
import "../../../services/keybind-search.js" as Logic
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["keybind"]

    readonly property bool enabled: Config.values.launcher.shell.keys !== false
    readonly property var asked: root.enabled ? Logic.ask(root.search.text) : null

    readonly property bool intent: root.asked !== null

    readonly property var entries: root.asked ? Logic.entries(HyprConfig.binds) : []
    readonly property var found: root.asked ? Logic.matching(root.entries, root.asked.words, Ranking.place, 12) : []

    readonly property var caps: ({
            keys: 12
        })

    readonly property var groups: [
        {
            key: "keys",
            title: "Keybinds",
            items: root.found.map((entry, i) => root.row(entry, i === 0))
        }
    ]

    readonly property var phrases: [
        {
            head: "keys ",
            picks: [""]
        }
    ]

    function row(entry: var, first: bool): var {
        return {
            key: `keybind:${entry.id}`,
            kind: "keybind",
            entry: entry,
            label: entry.action,
            detail: entry.submap ? `${entry.chord} · in ${entry.submap}` : entry.chord,
            icon: "keyboard",
            score: first ? Infinity : 100
        };
    }

    function activate(row: var): void {
        const chord = row.entry.chord;
        root.search.leave(() => Clipboard.copy({
                text: chord
            }));
    }

    function actionsFor(row: var): var {
        const screen = root.search.screenName;
        return [
            {
                icon: "content_copy",
                label: "Copy chord",
                short: "Copy",
                run: () => root.activate(row)
            },
            {
                icon: "keyboard",
                label: "Show the hotkey sheet",
                short: "Sheet",
                run: () => root.search.leave(() => Shell.forScreen(screen)?.hotkeys.show())
            }
        ];
    }
}
