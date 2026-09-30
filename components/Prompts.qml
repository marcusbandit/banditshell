pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool active: root.claims.length > 0

    property var claims: []

    function request(item: Item): void {
        if (!root.claims.includes(item))
            root.claims = [...root.claims, item];
    }

    function release(item: Item): void {
        root.claims = root.claims.filter(c => c !== item);
    }

    function activeIn(window: var): bool {

        const claims = root.claims;
        return !!window && claims.some(c => c?.QsWindow?.window === window);
    }
}
