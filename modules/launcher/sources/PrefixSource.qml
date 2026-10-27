import QtQuick
import "../prefixes.js" as Prefixes

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["prefix"]

    readonly property bool alone: Prefixes.asked(root.search.text)

    readonly property bool intent: root.alone

    readonly property var groups: !root.alone ? [] : Prefixes.sections(root.search.prefixes).map(section => ({
                key: `prefixes:${section.title}`,
                title: section.title,
                items: section.prefixes.map(p => ({
                        key: `prefix:${section.title}:${p.word}`,
                        kind: "prefix",
                        complete: Prefixes.completion(p),
                        label: p.word,
                        detail: Prefixes.detail(p),
                        icon: p.icon,
                        score: 1
                    }))
            }))

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
