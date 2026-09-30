pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property var windows: []

    function register(win: var): void {
        if (!root.windows.includes(win))
            root.windows = [...root.windows, win];
    }

    function unregister(win: var): void {
        root.windows = root.windows.filter(w => w !== win);
    }

    function forScreen(name: string): var {
        if (name)
            return root.windows.find(w => w.screen?.name === name) ?? null;

        return root.windows.find(w => w.screen?.name === Hypr.focusedScreen) ?? root.windows[0] ?? null;
    }

    function showing(pick: var): var {
        const here = root.forScreen("");
        if (here && pick(here))
            return here;
        return root.windows.find(w => pick(w)) ?? here;
    }

    function screenNames(): var {
        return root.windows.map(w => w.screen?.name ?? "?");
    }
}
