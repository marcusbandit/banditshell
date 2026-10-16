import QtQuick
import Quickshell
import qs.config
import "../search.js" as Search

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["fallback"]

    readonly property var groups: [
        {
            key: "fallbacks",
            title: "Elsewhere",
            items: Search.fallbackRows(Config.values.launcher.fallbacks, root.search.text, Config.values.launcher.webSearch).map(f => ({
                        key: `fallback:${f.id}`,
                        kind: "fallback",
                        fallback: f,
                        label: f.label,
                        detail: "",
                        icon: f.icon,
                        score: -Infinity
                    }))
        }
    ]

    function activate(row: var): void {
        if (row.fallback.url) {
            const url = row.fallback.url;
            root.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
            return;
        }
        const typed = root.search.text.replace(/'/g, "'\\''");
        root.search.launch(() => Quickshell.execDetached([`${Quickshell.shellDir}/scripts/in-terminal.sh`, `(eval '${typed}')\nexec "\${SHELL:-sh}"`]));
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
