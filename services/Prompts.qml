pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool active: root.claims.length > 0

    property var claims: []

    property var away: []

    function request(item: Item): void {
        if (!root.claims.includes(item))
            root.claims = [...root.claims, item];
    }

    function release(item: Item): void {
        root.claims = root.claims.filter(c => c !== item);
        root.back(item);
    }

    function leave(item: Item): void {
        if (!root.away.includes(item))
            root.away = [...root.away, item];
    }

    function back(item: Item): void {
        if (root.away.includes(item))
            root.away = root.away.filter(c => c !== item);
    }

    function activeIn(window: var): bool {

        const claims = root.claims;
        const away = root.away;
        return !!window && claims.some(c => !away.includes(c) && c?.QsWindow?.window === window);
    }

    function awayIn(window: var): bool {
        const away = root.away;
        return !!window && away.some(c => c?.QsWindow?.window === window);
    }
}
