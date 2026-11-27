pragma Singleton

import QtQuick
import "glass-place.js" as Place

QtObject {
    id: root

    property var entries: []

    function offer(win: var, source: var): void {
        if (!win || !source || Place.sourceIn(root.entries, win) === source)
            return;
        root.entries = root.entries.filter(e => e.window !== win && e.source !== source).concat([
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

    function on(win: var): var {
        return win ? Place.sourceIn(root.entries, win) : null;
    }
}
