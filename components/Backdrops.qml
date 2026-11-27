pragma Singleton

import QtQuick
import "glass-place.js" as Place

QtObject {
    id: root

    property var entries: []
    property var holders: []

    function offer(win: var, source: var): void {
        if (!win || !source || Place.sourceIn(root.entries, win) === source)
            return;
        root.entries = root.entries.filter(e => e.source !== source).concat([
            {
                window: win,
                source: source
            }
        ]);
    }

    function withdraw(source: var): void {
        if (root.entries.some(e => e.source === source))
            root.entries = root.entries.filter(e => e.source !== source);
    }

    function hold(panel: var, source: var): void {
        const held = root.holders.find(h => h.panel === panel)?.source ?? null;
        if (held === source)
            return;
        const kept = root.holders.filter(h => h.panel !== panel);
        root.holders = source ? kept.concat([
            {
                panel: panel,
                source: source
            }
        ]) : kept;
    }

    function holds(source: var): bool {
        return root.holders.some(h => h.source === source);
    }

    function on(win: var): var {
        return win ? Place.sourceIn(root.entries, win) : null;
    }
}
