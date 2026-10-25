import QtQuick
import "../prefixes.js" as Prefixes

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["prefix"]

    readonly property bool alone: Prefixes.asked(root.search.text)

    readonly property bool intent: root.alone

    readonly property var groups: [
        {
            key: "prefixes",
            title: "Prefixes",
            items: !root.alone ? [] : Prefixes.PREFIXES.map(p => ({
                        key: `prefix:${p.word}`,
                        kind: "prefix",
                        complete: Prefixes.completion(p),
                        label: p.word,
                        detail: `${p.about}, as in ${p.example}`,
                        icon: p.icon,
                        score: 1
                    }))
        }
    ]

    function activate(row: var): void {
        root.search.retype(row.complete);
    }

    function complete(row: var): bool {
        root.search.retype(row.complete);
        return true;
    }

    function actionsFor(row: var): var {
        return [
            {
                icon: "keyboard_tab",
                label: "Search",
                run: () => root.activate(row)
            }
        ];
    }
}
