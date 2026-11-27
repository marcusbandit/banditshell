pragma Singleton

import QtQuick

QtObject {
    id: root

    property var byScreen: ({})

    function offer(screen: string, source: var): void {
        if (!screen || !source || root.byScreen[screen] === source)
            return;
        const next = Object.assign({}, root.byScreen);
        next[screen] = source;
        root.byScreen = next;
    }

    function withdraw(screen: string, source: var): void {
        if (!screen || root.byScreen[screen] !== source)
            return;
        const next = Object.assign({}, root.byScreen);
        delete next[screen];
        root.byScreen = next;
    }

    function on(screen: string): var {
        return root.byScreen[screen] ?? null;
    }
}
